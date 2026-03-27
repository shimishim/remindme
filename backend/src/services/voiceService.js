import twilio from 'twilio';
import { config } from '../config/env.js';
import { db } from '../config/firebase.js';

/**
 * Voice Service: Handle voice calls via Twilio
 */

export class VoiceService {
  constructor() {
    this.callbackBaseUrl = config.PUBLIC_BASE_URL?.replace(/\/$/, '');

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

    if (!this.callbackBaseUrl) {
      throw new Error('PUBLIC_BASE_URL is not configured');
    }

    try {
      // Get user's phone number from database
      const userDoc = await db.collection('users').doc(userId).get();
      let phoneNumber = userDoc.exists ? userDoc.data().phoneNumber : null;

      if (!phoneNumber) {
        const fallbackSnapshot = await db.collection('users').get();
        const fallbackUser = fallbackSnapshot.docs
          .map(doc => doc.data())
          .filter(user => user.phoneNumber)
          .sort((a, b) => {
            const aTime = new Date(a.phoneNumberUpdatedAt || a.fcmUpdatedAt || 0).getTime();
            const bTime = new Date(b.phoneNumberUpdatedAt || b.fcmUpdatedAt || 0).getTime();
            return bTime - aTime;
          })[0];

        phoneNumber = fallbackUser?.phoneNumber ?? null;
      }

      if (!phoneNumber) {
        throw new Error(`User ${userId} has no phone number on file`);
      }

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
    const callbackUrl = this.buildVoiceCallbackUrl(reminderId);
    const twiml = `<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say voice="alice" language="he-IL">
    ${this.escapeTwiML(message)}
  </Say>
  
  <Gather numDigits="1" action="${callbackUrl}" method="POST" timeout="10">
    <Say voice="alice" language="he-IL">
      לחץ אחד כדי לסמן כבוצע. לחץ שניים כדי לדחות.
    </Say>
  </Gather>
  
  <Say voice="alice" language="he-IL">
    לא שמעתי קלט. ניסיון שוב.
  </Say>
  <Redirect method="POST">${callbackUrl}</Redirect>
</Response>`;

    return twiml;
  }

  buildVoiceCallbackUrl(reminderId) {
    return `${this.callbackBaseUrl}${config.API_PREFIX}/voice/callback?reminderId=${encodeURIComponent(reminderId)}`;
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
