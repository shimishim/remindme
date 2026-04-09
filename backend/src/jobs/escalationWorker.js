import { Queue, Worker } from 'bullmq';
import { config } from '../config/env.js';
import { db } from '../config/firebase.js';

/**
 * Escalation Worker: Long-running process that handles reminder escalations
 * 
 * Uses BullMQ for reliable job scheduling and processing
 */

const redisConfig = {
  host: config.REDIS_HOST,
  port: config.REDIS_PORT
};

export class EscalationWorker {
  constructor(escalationEngine) {
    this.escalationEngine = escalationEngine;
    this.escalationQueue = null;
    this.scheduleQueue = null;
    this.worker = null;
    this.scheduleWorker = null;
  }

  /**
   * Initialize workers
   */
  async initialize() {
    console.log('🚀 Initializing Escalation Worker...');

    try {
      // Create queues
      this.escalationQueue = new Queue('reminderEscalations', { connection: redisConfig });
      this.scheduleQueue = new Queue('reminderScheduling', { connection: redisConfig });

      // Worker for handling escalations
      this.worker = new Worker('reminderEscalations', this.processEscalation.bind(this), {
        connection: redisConfig,
        concurrency: 5
      });

      // Worker for scheduling new escalations
      this.scheduleWorker = new Worker('reminderScheduling', this.processScheduling.bind(this), {
        connection: redisConfig,
        concurrency: 10
      });

      // Attach error handlers to prevent unhandled rejections from crashing the process
      this.worker.on('error', err => {
        console.warn('⚠️ Escalation worker error (non-fatal):', err.message);
      });
      this.scheduleWorker.on('error', err => {
        console.warn('⚠️ Schedule worker error (non-fatal):', err.message);
      });
      this.escalationQueue.on('error', err => {
        console.warn('⚠️ Escalation queue error (non-fatal):', err.message);
      });
      this.scheduleQueue.on('error', err => {
        console.warn('⚠️ Schedule queue error (non-fatal):', err.message);
      });

      this.worker.on('completed', job => {
        console.log(`✅ Escalation job ${job.id} completed`);
      });

      this.worker.on('failed', (job, err) => {
        console.error(`❌ Escalation job ${job?.id} failed:`, err.message);
      });

      console.log('✅ Escalation Worker started');
    } catch (err) {
      console.warn('⚠️ BullMQ workers could not be initialized (Redis may be too old):', err.message);
      console.warn('⚠️ Escalation via queue is disabled. Reminder CRUD will still work.');
      this.worker = null;
      this.scheduleWorker = null;
    }
  }

  /**
   * Queue a reminder for escalation
   */
  async queueEscalation(reminderId, userId, level, delay = 0) {
    if (!this.escalationQueue) {
      console.warn(`⚠️ Queue not available, skipping escalation L${level} for ${reminderId}`);
      return;
    }
    try {
      await this.escalationQueue.add(
        'escalate',
        { reminderId, userId, level },
        {
          delay: delay * 1000 * 60, // Convert minutes to milliseconds
          removeOnComplete: true,
          removeOnFail: false,
          jobId: `${reminderId}-L${level}`
        }
      );

      console.log(
        `📋 Queued escalation L${level} for reminder ${reminderId} (delay: ${delay}min)`
      );
    } catch (error) {
      console.error('❌ Error queueing escalation:', error.message);
    }
  }

  async scheduleReminder(reminder) {
    const scheduledTime = new Date(reminder.scheduledTime);
    const delayMs = Math.max(0, scheduledTime.getTime() - Date.now());
    const delayMinutes = Math.ceil(delayMs / 1000 / 60);
    await this.queueEscalation(reminder.id, reminder.userId, 1, delayMinutes);
  }

  async cancelReminder(reminderId) {
    if (!this.escalationQueue) return;

    for (let level = 1; level <= 4; level++) {
      try {
        const job = await this.escalationQueue.getJob(`${reminderId}-L${level}`);
        if (job) await job.remove();
      } catch (error) {
        console.warn(
          `⚠️ Failed removing queued escalation L${level} for ${reminderId}: ${error.message}`
        );
      }
    }
  }

  async rescheduleAfterSnooze(reminder, snoozeMinutes = 10) {
    await this.cancelReminder(reminder.id);
    await this.queueEscalation(reminder.id, reminder.userId, 1, snoozeMinutes);
  }

  /**
   * Process escalation job
   */
  async processEscalation(job) {
    const { reminderId, userId, level } = job.data;

    try {
      console.log(`⚙️ Processing escalation L${level} for reminder ${reminderId}`);

      // Fetch reminder from database
      const reminderDoc = await db.collection('reminders').doc(reminderId).get();

      if (!reminderDoc.exists) {
        throw new Error(`Reminder ${reminderId} not found`);
      }

      const reminder = reminderDoc.data();

      // Skip if already completed
      if (reminder.status === 'completed') {
        console.log(`⏭️ Skipping escalation - reminder already completed`);
        return { skipped: true };
      }

      // Skip if snoozed
      if (reminder.status === 'snoozed') {
        const snoozedUntil = new Date(reminder.snoozedUntil);
        if (new Date() < snoozedUntil) {
          console.log(`⏭️ Skipping escalation - reminder snoozed until ${snoozedUntil}`);
          const delayMinutes = Math.max(
            1,
            Math.ceil((snoozedUntil.getTime() - Date.now()) / 1000 / 60)
          );
          await this.queueEscalation(reminderId, userId, level, delayMinutes);
          return { skipped: true };
        }
        // Snooze period ended, re-activate reminder
        await db.collection('reminders').doc(reminderId).update({
          status: 'pending',
          snoozedUntil: null,
          escalationLevel: 1
        });
      }

      // Perform escalation
      await this.escalationEngine.escalateReminder(
        reminder,
        level,
        db
      );

      // Update reminder with current escalation level
      await db.collection('reminders').doc(reminderId).update({
        escalationLevel: level,
        lastEscalatedAt: new Date().toISOString()
      });

      // Schedule next escalation if available
      const nextTime = this.escalationEngine.getNextEscalationTime(reminder, level);
      if (nextTime) {
        const delayMs = new Date(nextTime) - new Date();
        const delayMinutes = Math.ceil(delayMs / 1000 / 60);

        await this.queueEscalation(reminderId, userId, level + 1, delayMinutes);
      }

      return { success: true, level };
    } catch (error) {
      console.error(`❌ Error processing escalation:`, error);
      throw error;
    }
  }

  /**
   * Process scheduling job (find reminders that need to start escalating)
   */
  async processScheduling(job) {
    try {
      console.log('⚙️ Processing reminder scheduling...');

      const now = new Date();

      // Find ALL pending reminders regardless of how far in the future they are.
      // Previously this only looked 10 minutes ahead, so any reminder scheduled
      // more than 10 minutes out would never be queued after a server restart.
      // BullMQ handles arbitrary future delays via its sorted-set storage in Redis.
      const snapshot = await db
        .collection('reminders')
        .where('status', '==', 'pending')
        .where('scheduledTime', '>', now.toISOString())
        .get();

      let processed = 0;

      for (const doc of snapshot.docs) {
        const reminder = doc.data();
        const scheduledTime = new Date(reminder.scheduledTime);
        const delayMs = scheduledTime - now;
        const delayMinutes = Math.ceil(delayMs / 1000 / 60);

        // Queue first escalation
        await this.queueEscalation(doc.id, reminder.userId, 1, delayMinutes);
        processed++;
      }

      console.log(`📅 Scheduled ${processed} reminders for escalation`);
      return { scheduled: processed };
    } catch (error) {
      console.error('❌ Error processing scheduling:', error);
      throw error;
    }
  }

  /**
   * Start periodic scheduling (runs every 5 minutes)
   */
  async startScheduleCheck(intervalMinutes = 5) {
    console.log(`🔄 Starting schedule check every ${intervalMinutes} minutes`);

    if (!this.scheduleQueue) {
      try {
        await this.processScheduling({ data: {} });
      } catch (err) {
        console.error('❌ Initial inline schedule check error:', err.message);
      }
    } else {
      try {
        await this.scheduleQueue.add(
          'schedule-check-initial',
          {},
          {
            removeOnComplete: true,
            removeOnFail: false
          }
        );
      } catch (error) {
        console.error('❌ Error adding initial schedule check job:', error.message);
      }
    }

    setInterval(async () => {
      if (!this.scheduleQueue) {
        // Fallback: run scheduling directly without BullMQ
        try {
          await this.processScheduling({ data: {} });
        } catch (err) {
          console.error('❌ Inline schedule check error:', err.message);
        }
        return;
      }
      try {
        await this.scheduleQueue.add(
          'schedule-check',
          {},
          {
            removeOnComplete: true,
            removeOnFail: false
          }
        );
      } catch (error) {
        console.error('❌ Error adding schedule check job:', error);
      }
    }, intervalMinutes * 60 * 1000);
  }

  /**
   * Cleanup
   */
  async cleanup() {
    try {
      if (this.worker) await this.worker.close();
      if (this.scheduleWorker) await this.scheduleWorker.close();
      if (this.escalationQueue) await this.escalationQueue.close();
      if (this.scheduleQueue) await this.scheduleQueue.close();
    } catch (err) {
      console.warn('⚠️ Cleanup error (non-fatal):', err.message);
    }
  }
}

export default EscalationWorker;
