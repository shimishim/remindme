import express from 'express';
import { db } from '../../config/firebase.js';
import { Reminder } from '../../models/Reminder.js';
import { requireAuth } from '../middleware/auth.js';

/**
 * Reminder Routes: CRUD operations and escalation management
 */

export function createReminderRoutes(
  nlpParser,
  escalationEngine,
  getEscalationWorker,
  getScheduler
) {
  const router = express.Router();

  // All reminder routes require authentication
  router.use(requireAuth);

  /**
   * POST /api/v1/reminders
   * Create a new reminder from natural language
   */
  router.post('/', async (req, res) => {
    try {
      const { text, personality = 'sarcastic', allowVoice = false } = req.body;
      // Always use the authenticated user's uid — ignore any userId from the body
      const userId = req.user.uid;

      if (!text) {
        return res.status(400).json({
          error: 'Missing required field: text'
        });
      }

      // Parse natural language
      const parsed = nlpParser.parse(text);

      // Create reminder object
      const reminder = new Reminder({
        userId: userId,
        title: parsed.title,
        description: text,
        scheduledTime: parsed.scheduledTime,
        personality: personality,
        allowVoice: allowVoice
      });

      // Save to Firestore
      await db.collection('reminders').doc(reminder.id).set(reminder.toJSON());

      const reminderPayload = { id: reminder.id, ...reminder.toJSON() };

      // Prefer durable queue scheduling when Redis/BullMQ is available.
      const escalationWorker = getEscalationWorker?.();
      if (escalationWorker) {
        await escalationWorker.scheduleReminder(reminderPayload);
      } else {
        const scheduler = getScheduler?.();
        if (scheduler) {
          scheduler.scheduleReminder(reminderPayload);
        }
      }

      // Get escalation plan
      const escalationPlan = escalationEngine.getEscalationPlan(reminder);

      console.log(`✅ Reminder created: ${reminder.id}`);

      res.status(201).json({
        success: true,
        reminder: reminder.toJSON(),
        escalationPlan: escalationPlan,
        message: 'Reminder created successfully'
      });
    } catch (error) {
      console.error('❌ Error creating reminder:', error);
      res.status(500).json({
        error: error.message
      });
    }
  });

  /**
   * GET /api/v1/reminders
   * Get all reminders for the authenticated user
   */
  router.get('/', async (req, res) => {
    try {
      const userId = req.user.uid;
      const { status = 'all' } = req.query;

      let query = db.collection('reminders').where('userId', '==', userId);

      if (status !== 'all') {
        query = query.where('status', '==', status);
      }

      const snapshot = await query.orderBy('scheduledTime', 'desc').limit(100).get();

      const reminders = [];
      snapshot.forEach(doc => {
        reminders.push({
          id: doc.id,
          ...doc.data()
        });
      });

      res.json({
        success: true,
        count: reminders.length,
        reminders: reminders
      });
    } catch (error) {
      console.error('❌ Error fetching reminders:', error);
      res.status(500).json({
        error: error.message
      });
    }
  });

  /**
   * GET /api/v1/reminders/detail/:reminderId
   * Get single reminder
   */
  router.get('/detail/:reminderId', async (req, res) => {
    try {
      const { reminderId } = req.params;

      const doc = await db.collection('reminders').doc(reminderId).get();

      if (!doc.exists) {
        return res.status(404).json({
          error: 'Reminder not found'
        });
      }

      const reminder = doc.data();
      if (reminder.userId !== req.user.uid) return res.status(403).json({ error: 'Forbidden' });

      const escalationHistory = await db
        .collection('escalation_history')
        .where('reminderId', '==', reminderId)
        .orderBy('triggeredAt', 'desc')
        .get();

      const history = escalationHistory.docs.map(d => ({
        id: d.id,
        ...d.data()
      }));

      res.json({
        success: true,
        reminder: reminder,
        escalationHistory: history
      });
    } catch (error) {
      console.error('❌ Error fetching reminder:', error);
      res.status(500).json({
        error: error.message
      });
    }
  });

  /**
   * PUT /api/v1/reminders/:reminderId/complete
   * Mark reminder as completed
   */
  router.put('/:reminderId/complete', async (req, res) => {
    try {
      const { reminderId } = req.params;

      const doc = await db.collection('reminders').doc(reminderId).get();
      if (!doc.exists) return res.status(404).json({ error: 'Reminder not found' });
      if (doc.data().userId !== req.user.uid) return res.status(403).json({ error: 'Forbidden' });

      await db.collection('reminders').doc(reminderId).update({
        status: 'completed',
        completedAt: new Date().toISOString()
      });

      // Cancel pending escalations
      const escalationWorker = getEscalationWorker?.();
      if (escalationWorker) {
        await escalationWorker.cancelReminder(reminderId);
      } else {
        const scheduler = getScheduler?.();
        if (scheduler) scheduler.cancelReminder(reminderId);
      }

      console.log(`✅ Reminder ${reminderId} marked as completed`);

      res.json({
        success: true,
        message: 'Reminder marked as completed'
      });
    } catch (error) {
      console.error('❌ Error completing reminder:', error);
      res.status(500).json({
        error: error.message
      });
    }
  });

  /**
   * PUT /api/v1/reminders/:reminderId/snooze
   * Snooze reminder for X minutes
   */
  router.put('/:reminderId/snooze', async (req, res) => {
    try {
      const { reminderId } = req.params;
      const { minutes = 10 } = req.body;

      const reminderDoc = await db.collection('reminders').doc(reminderId).get();
      if (!reminderDoc.exists) {
        return res.status(404).json({ error: 'Reminder not found' });
      }
      if (reminderDoc.data().userId !== req.user.uid) return res.status(403).json({ error: 'Forbidden' });

      const reminder = reminderDoc.data();
      const snoozedUntil = new Date(
        new Date(reminder.scheduledTime).getTime() + minutes * 60000
      );

      await db.collection('reminders').doc(reminderId).update({
        status: 'snoozed',
        snoozedUntil: snoozedUntil.toISOString(),
        escalationLevel: 0 // Reset escalation
      });

      // Reschedule escalations after snooze
      const escalationWorker = getEscalationWorker?.();
      if (escalationWorker) {
        await escalationWorker.rescheduleAfterSnooze(
          { id: reminderId, ...reminder },
          minutes
        );
      } else {
        const scheduler = getScheduler?.();
        if (scheduler) {
          scheduler.rescheduleAfterSnooze({ id: reminderId, ...reminder }, minutes);
        }
      }

      console.log(`⏰ Reminder ${reminderId} snoozed for ${minutes} minutes`);

      res.json({
        success: true,
        message: `Reminder snoozed until ${snoozedUntil.toISOString()}`
      });
    } catch (error) {
      console.error('❌ Error snoozing reminder:', error);
      res.status(500).json({
        error: error.message
      });
    }
  });

  /**
   * DELETE /api/v1/reminders/:reminderId
   * Delete reminder
   */
  router.delete('/:reminderId', async (req, res) => {
    try {
      const { reminderId } = req.params;

      const doc = await db.collection('reminders').doc(reminderId).get();
      if (!doc.exists) return res.status(404).json({ error: 'Reminder not found' });
      if (doc.data().userId !== req.user.uid) return res.status(403).json({ error: 'Forbidden' });

      await db.collection('reminders').doc(reminderId).delete();

      // Cancel pending escalations
      const escalationWorker = getEscalationWorker?.();
      if (escalationWorker) {
        await escalationWorker.cancelReminder(reminderId);
      } else {
        const scheduler = getScheduler?.();
        if (scheduler) scheduler.cancelReminder(reminderId);
      }

      console.log(`🗑️ Reminder ${reminderId} deleted`);

      res.json({
        success: true,
        message: 'Reminder deleted'
      });
    } catch (error) {
      console.error('❌ Error deleting reminder:', error);
      res.status(500).json({
        error: error.message
      });
    }
  });

  /**
   * POST /api/v1/reminders/:reminderId/test-escalation
   * Test escalation (for debugging)
   */
  router.post('/:reminderId/test-escalation', async (req, res) => {
    try {
      const { reminderId } = req.params;
      const { level = 1 } = req.body;

      const reminderDoc = await db.collection('reminders').doc(reminderId).get();
      if (!reminderDoc.exists) {
        return res.status(404).json({ error: 'Reminder not found' });
      }
      if (reminderDoc.data().userId !== req.user.uid) return res.status(403).json({ error: 'Forbidden' });

      const reminder = reminderDoc.data();
      const escalationRecord = await escalationEngine.escalateReminder(
        reminder,
        level,
        db
      );

      res.json({
        success: true,
        message: `Escalation L${level} triggered`,
        escalationRecord: escalationRecord.toJSON()
      });
    } catch (error) {
      console.error('❌ Error testing escalation:', error);
      res.status(500).json({
        error: error.message
      });
    }
  });

  return router;
}

export default createReminderRoutes;
