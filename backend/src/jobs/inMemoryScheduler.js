import { db } from '../config/firebase.js';

/**
 * In-Memory Scheduler: Lightweight alternative to BullMQ/Redis
 *
 * Schedules escalation timers using setTimeout.
 * Suitable for development and MVP — not for production with multiple instances.
 */
export class InMemoryScheduler {
  constructor(escalationEngine) {
    this.escalationEngine = escalationEngine;
    /** @type {Map<string, NodeJS.Timeout[]>} reminderId → array of pending timers */
    this.timers = new Map();
    this.checkInterval = null;
  }

  /**
   * Schedule all escalation levels for a reminder.
   * Called immediately when a reminder is created.
   */
  scheduleReminder(reminder) {
    const plan = this.escalationEngine.getEscalationPlan(reminder);
    const now = Date.now();
    const scheduledTime = new Date(reminder.scheduledTime).getTime();

    // Cancel any existing timers for this reminder
    this.cancelReminder(reminder.id);

    const timers = [];

    for (const step of plan) {
      const fireAt = scheduledTime + step.delay_minutes * 60_000;
      const delay = fireAt - now;

      if (delay < 0) {
        // For L1 (first notification), fire immediately even if time has passed
        if (step.level === 1) {
          const timer = setTimeout(
            () => this.#fireEscalation(reminder.id, reminder.userId, step.level),
            500  // fire in 0.5s
          );
          timers.push(timer);
          console.log(`⏱️  Scheduled L1 for ${reminder.id} immediately (overdue)`);
        }
        continue; // skip other past levels
      }

      const timer = setTimeout(
        () => this.#fireEscalation(reminder.id, reminder.userId, step.level),
        delay
      );

      timers.push(timer);

      console.log(
        `⏱️  Scheduled L${step.level} for ${reminder.id} in ${Math.round(delay / 1000)}s`
      );
    }

    if (timers.length > 0) {
      this.timers.set(reminder.id, timers);
    }
  }

  /**
   * Cancel all pending escalations for a reminder (on complete / snooze / delete).
   */
  cancelReminder(reminderId) {
    const existing = this.timers.get(reminderId);
    if (existing) {
      existing.forEach(t => clearTimeout(t));
      this.timers.delete(reminderId);
      console.log(`🛑 Cancelled timers for ${reminderId}`);
    }
  }

  /**
   * Re-schedule a snoozed reminder: offset all remaining levels from now.
   */
  rescheduleAfterSnooze(reminder, snoozeMinutes = 10) {
    this.cancelReminder(reminder.id);

    const now = Date.now();
    const newBase = now + snoozeMinutes * 60_000;

    // Start from level 1 again
    const plan = this.escalationEngine.getEscalationPlan(reminder);
    const timers = [];

    for (const step of plan) {
      const fireAt = newBase + step.delay_minutes * 60_000;
      const delay = fireAt - now;

      const timer = setTimeout(
        () => this.#fireEscalation(reminder.id, reminder.userId, step.level),
        delay
      );
      timers.push(timer);

      console.log(
        `⏱️  Re-scheduled L${step.level} for ${reminder.id} in ${Math.round(delay / 1000)}s (post-snooze)`
      );
    }

    if (timers.length > 0) {
      this.timers.set(reminder.id, timers);
    }
  }

  /**
   * Start a periodic check that picks up reminders from Firestore
   * that were created before the server started (crash recovery).
   */
  startPeriodicCheck(intervalMinutes = 5) {
    console.log(`🔄 In-memory scheduler: periodic check every ${intervalMinutes}min`);

    // Run once immediately on startup
    this.#loadPendingReminders();

    this.checkInterval = setInterval(
      () => this.#loadPendingReminders(),
      intervalMinutes * 60_000
    );
  }

  /** Fire a single escalation level */
  async #fireEscalation(reminderId, userId, level) {
    try {
      const doc = await db.collection('reminders').doc(reminderId).get();
      if (!doc.exists) return;

      const reminder = doc.data();

      // Skip if completed or snoozed
      if (reminder.status === 'completed') {
        console.log(`⏭️ Skipping L${level} — reminder ${reminderId} completed`);
        this.cancelReminder(reminderId);
        return;
      }

      if (reminder.status === 'snoozed') {
        const snoozedUntil = new Date(reminder.snoozedUntil);
        if (Date.now() < snoozedUntil.getTime()) {
          console.log(`⏭️ Skipping L${level} — reminder ${reminderId} snoozed`);
          return;
        }
      }

      console.log(`🔔 Firing escalation L${level} for ${reminderId}`);

      await this.escalationEngine.escalateReminder(reminder, level, db);

      await db.collection('reminders').doc(reminderId).update({
        escalationLevel: level,
        lastEscalatedAt: new Date().toISOString()
      });
    } catch (err) {
      console.error(`❌ Escalation L${level} error for ${reminderId}:`, err.message);
    }
  }

  /** Load pending reminders from Firestore and schedule any that are missing */
  async #loadPendingReminders() {
    try {
      const now = new Date();

      // 1. Pick up ALL pending reminders not yet scheduled.
      // No upper time bound — a reminder due in 3 hours or 3 days must still
      // be loaded so scheduleReminder() can set the correct setTimeout delay.
      // Previously this only looked 15 minutes ahead, which caused all
      // long-duration reminders to be silently missed after a server restart.
      const pendingSnapshot = await db
        .collection('reminders')
        .where('status', '==', 'pending')
        .get();

      let scheduled = 0;

      for (const doc of pendingSnapshot.docs) {
        if (this.timers.has(doc.id)) continue;
        const reminder = { id: doc.id, ...doc.data() };
        this.scheduleReminder(reminder);
        scheduled++;
      }

      // 2. Pick up snoozed reminders whose snooze time has expired
      const snoozedSnapshot = await db
        .collection('reminders')
        .where('status', '==', 'snoozed')
        .get();

      for (const doc of snoozedSnapshot.docs) {
        if (this.timers.has(doc.id)) continue;
        const data = doc.data();
        const snoozedUntil = new Date(data.snoozedUntil);
        if (now >= snoozedUntil) {
          // Snooze expired — reactivate and schedule
          await db.collection('reminders').doc(doc.id).update({ status: 'pending' });
          const reminder = { id: doc.id, ...data, status: 'pending' };
          this.scheduleReminder(reminder);
          scheduled++;
          console.log(`⏰ Reactivated snoozed reminder ${doc.id}`);
        }
      }

      if (scheduled > 0) {
        console.log(`📅 Periodic check: scheduled ${scheduled} reminders`);
      }
    } catch (err) {
      console.error('❌ Periodic check error:', err.message);
    }
  }

  /** Cleanup all timers */
  cleanup() {
    if (this.checkInterval) clearInterval(this.checkInterval);
    for (const [id, timers] of this.timers) {
      timers.forEach(t => clearTimeout(t));
    }
    this.timers.clear();
    console.log('🧹 In-memory scheduler cleaned up');
  }
}

export default InMemoryScheduler;
