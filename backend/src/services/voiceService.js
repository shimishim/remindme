import twilio from 'twilio';
import { config } from '../config/env.js';
import { db } from '../config/firebase.js';

/**
 * Voice Service: Handle voice calls via Twilio
 */

export class VoiceService {
  constructor() {
    if (config.TWILIO_ACCOUNT_SID?.startsWith('AC') && config.TWILIO_AUTH_TOKEN) {
      this.client = twilio(config.TWILIO_ACCOUNT_SID, config.TWILIO_AUTH_TOKEN);
    } else {
      console.warn('⚠️ Twilio credentials not configured. Voice calls disabled.');
    }
  }

  /**
   * Make a reminder call
   * Calls user with escalation message
   */
  async makeReminderCall(userId, reminder, message) {
    if (!this.client) {
      throw new Error('Twilio not configured');
    }

    try {
      // Get user's phone number from database
      const userDoc = await db.collection('users').doc(userId).get();
      if (!userDoc.exists || !userDoc.data().phoneNumber) {
        throw new Error(`User ${userId} has no phone number on file`);
      }

      const phoneNumber = userDoc.data().phoneNumber;

      // Generate TwiML (Twilio Markup Language) for the call
      const twiml = this.generateTwiML(message, reminder.id);

      // Make the call
      const call = await this.client.calls.create({
        to: phoneNumber,
        from: config.TWILIO_PHONE_NUMBER,
        twiml: twiml
      });

      // Log call event
      await db.collection('call_logs').add({
        userId: userId,
        reminderId: reminder.id,
        callSid: call.sid,
        phoneNumber: phoneNumber,
        status: call.status,
        message: message,
        createdAt: new Date().toISOString()
      });

      console.log(`📞 Voice call initiated to ${phoneNumber}. Call SID: ${call.sid}`);
      return call;
    } catch (error) {
      console.error('❌ Error making voice call:', error);
      throw error;
    }
  }

  /**
   * Generate TwiML for the voice call
   * This is what Twilio will "say" to the user
   */
  generateTwiML(message, reminderId) {
    const twiml = `<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say voice="alice" language="he-IL">
    ${this.escapeTwiML(message)}
  </Say>
  
  <Gather numDigits="1" action="/api/v1/voice/callback" timeout="10">
    <Say voice="alice" language="he-IL">
      לחץ אחד כדי לסמן כבוצע. לחץ שניים כדי לדחות.
    </Say>
  </Gather>
  
  <Say voice="alice" language="he-IL">
    לא שמעתי קלט. ניסיון שוב.
  </Say>
  <Redirect>/api/v1/voice/callback?reminderId=${reminderId}&action=timeout</Redirect>
</Response>`;

    return twiml;
  }

  /**
   * Escape special characters for TwiML
   */
  escapeTwiML(text) {
    return text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  /**
   * Handle voice call callback (when user presses button)
   * This would be called via webhook from Twilio
   */
  async handleVoiceCallback(reminderId, digits) {
    try {
      if (digits === '1') {
        // Mark reminder as completed
        await db.collection('reminders').doc(reminderId).update({
          status: 'completed',
          completedAt: new Date().toISOString()
        });
        console.log(`✅ Reminder ${reminderId} marked complete via voice`);
      } else if (digits === '2') {
        // Snooze for 10 minutes
        const reminder = await db.collection('reminders').doc(reminderId).get();
        const snoozedUntil = new Date(
          new Date(reminder.data().scheduledTime).getTime() + 10 * 60000
        );

        await db.collection('reminders').doc(reminderId).update({
          status: 'snoozed',
          snoozedUntil: snoozedUntil.toISOString()
        });
        console.log(`⏰ Reminder ${reminderId} snoozed via voice`);
      }
    } catch (error) {
      console.error('❌ Error handling voice callback:', error);
      throw error;
    }
  }

  /**
   * Get call status
   */
  async getCallStatus(callSid) {
    if (!this.client) {
      throw new Error('Twilio not configured');
    }

    try {
      const call = await this.client.calls(callSid).fetch();
      return {
        sid: call.sid,
        status: call.status,
        duration: call.duration,
        startTime: call.dateCreated,
        endTime: call.dateUpdated
      };
    } catch (error) {
      console.error('❌ Error fetching call status:', error);
      throw error;
    }
  }
}

export default VoiceService;
