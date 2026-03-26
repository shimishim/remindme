import { EscalationHistory } from '../models/Reminder.js';

/**
 * Escalation Engine: Core logic that defines how reminders escalate
 * 
 * Strategy:
 * Level 1 (immediate): Notification + message
 * Level 2 (3 min later): Full-screen alert + sarcastic message
 * Level 3 (7 min later): Voice call (if enabled)
 * Level 4 (12 min later): Humorous/annoying push
 */

export class EscalationEngine {
  constructor(notificationService, voiceService) {
    this.notificationService = notificationService;
    this.voiceService = voiceService;
    this.escalationRules = this.buildEscalationRules();
  }

  /**
   * Build escalation rules based on level and personality
   */
  buildEscalationRules() {
    return {
      1: {
        delay_minutes: 0,
        action: 'PUSH_NOTIFICATION',
        defaultMessage: {
          sarcastic: 'עכשיו הזמן בן אדם, אל תשכח!',
          coach: 'זה הזמן! בואו נגיד שאתה מטפל בזה עכשיו!',
          friend: 'היי, זה הרגע — תעשה את זה!'
        }
      },
      2: {
        delay_minutes: 3,
        action: 'FULL_SCREEN_ALERT',
        defaultMessage: {
          sarcastic: 'אחי… זה משהו רציני. עיניים למעלה.',
          coach: 'הממ... עוד לא? כמו שיגיד אימך.',
          friend: 'בואו, הלחץ פה. תעשה את זה עכשיו!'
        }
      },
      3: {
        delay_minutes: 7,
        action: 'VOICE_CALL',
        defaultMessage: {
          sarcastic: 'קול שחקן אומר: אתה כמעט שוגח אותה.',
          coach: 'זה קול מאמן שלך: תרים עצמך!',
          friend: 'זו הזמנה אפילו בקול חי!'
        },
        requiresUserConsent: true
      },
      4: {
        delay_minutes: 12,
        action: 'HUMOROUS_PUSH',
        defaultMessage: {
          sarcastic: 'גם ההשעיות שלך נתנו על זה 😏',
          coach: 'הפסק לוויתור! אתה יודע שאתה יכול לעשות את זה.',
          friend: 'בתור ידיד אמיתי: עוד נסיון?'
        }
      }
    };
  }

  /**
   * Get escalation plan for a reminder
   */
  getEscalationPlan(reminder) {
    const plan = [];

    Object.entries(this.escalationRules).forEach(([level, rule]) => {
      const requiresConsent = rule.requiresUserConsent && reminder.allowVoice;

      plan.push({
        level: parseInt(level),
        delay_minutes: rule.delay_minutes,
        action: rule.action,
        message: rule.defaultMessage[reminder.personality],
        requires_consent: requiresConsent,
        enabled: !rule.requiresUserConsent || reminder.allowVoice
      });
    });

    return plan.filter(p => p.enabled);
  }

  /**
   * Handle reminder escalation at specific level
   */
  async escalateReminder(reminder, escalationLevel, db) {
    const rule = this.escalationRules[escalationLevel];

    if (!rule) {
      throw new Error(`Invalid escalation level: ${escalationLevel}`);
    }

    const message = rule.defaultMessage[reminder.personality];

    const escalationRecordId = `${reminder.id}_L${escalationLevel}`;
    const existingRecord = await db
      .collection('escalation_history')
      .doc(escalationRecordId)
      .get();

    if (existingRecord.exists && existingRecord.data()?.status === 'sent') {
      console.log(
        `⏭️ Escalation L${escalationLevel} for reminder ${reminder.id} already sent`
      );
      return existingRecord.data();
    }

    const escalationRecord = new EscalationHistory({
      id: escalationRecordId,
      reminderId: reminder.id,
      userId: reminder.userId,
      level: escalationLevel,
      action: rule.action,
      message: message,
      status: 'sent'
    });

    try {
      let deliveryResult = null;

      // Route to appropriate service based on action
      switch (rule.action) {
        case 'PUSH_NOTIFICATION':
          deliveryResult = await this.notificationService.sendNotification(
            reminder.userId,
            reminder.title,
            message,
            { reminderId: reminder.id, level: escalationLevel }
          );
          break;

        case 'FULL_SCREEN_ALERT':
          // Send signal to mobile app to show full-screen alert
          deliveryResult = await this.notificationService.sendFullScreenAlert(
            reminder.userId,
            reminder.title,
            message,
            { reminderId: reminder.id, level: escalationLevel }
          );
          break;

        case 'VOICE_CALL':
          if (reminder.allowVoice) {
            await this.voiceService.makeReminderCall(
              reminder.userId,
              reminder,
              message
            );
          }
          break;

        case 'HUMOROUS_PUSH':
          deliveryResult = await this.notificationService.sendNotification(
            reminder.userId,
            `⏰ ${reminder.title}`,
            message,
            { reminderId: reminder.id, level: escalationLevel, humorous: true }
          );
          break;

        default:
          console.warn(`Unknown action: ${rule.action}`);
      }

      // Log escalation event
      escalationRecord.metadata = {
        ...escalationRecord.metadata,
        delivery: deliveryResult
      };

      await db.collection('escalation_history').doc(escalationRecord.id).set(
        escalationRecord.toJSON()
      );

      console.log(
        `✅ Escalation L${escalationLevel} for reminder ${reminder.id}: ${rule.action}`
      );

      return escalationRecord;
    } catch (error) {
      console.error(
        `❌ Escalation L${escalationLevel} failed for reminder ${reminder.id}:`,
        error
      );

      escalationRecord.status = 'failed';
      escalationRecord.metadata = {
        ...escalationRecord.metadata,
        error: error.message,
        errorCode: error.code ?? null
      };

      await db.collection('escalation_history').doc(escalationRecord.id).set(
        escalationRecord.toJSON()
      );

      throw error;
    }
  }

  /**
   * Calculate next escalation time
   */
  getNextEscalationTime(reminder, currentLevel, escalationRules = this.escalationRules) {
    const nextLevel = currentLevel + 1;
    const nextRule = escalationRules[nextLevel];

    if (!nextRule) return null; // No more escalations

    const scheduledTime = new Date(reminder.scheduledTime);
    const nextTime = new Date(
      scheduledTime.getTime() + nextRule.delay_minutes * 60000
    );

    return nextTime.toISOString();
  }
}

export default EscalationEngine;
