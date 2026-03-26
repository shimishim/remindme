import { db, firebaseApp } from '../config/firebase.js';

const RETRYABLE_FCM_ERRORS = new Set([
  'messaging/internal-error',
  'messaging/server-unavailable',
  'messaging/unknown-error',
  'app/network-error'
]);

/**
 * Notification Service: Send real push notifications via Firebase Cloud Messaging (FCM)
 *
 * Mobile app must register its FCM token via PUT /api/v1/users/fcm-token.
 * Tokens are stored in Firestore under users/{userId}.fcmToken.
 */

export class NotificationService {
  /**
   * Retrieve the FCM token for a user.
   * Returns null if the user has no token registered.
   */
  async #getFcmToken(userId) {
    const userDoc = await db.collection('users').doc(userId).get();
    return userDoc.exists ? (userDoc.data().fcmToken ?? null) : null;
  }

  /**
   * Low-level FCM send helper.
    * Can send either system-visible notification payloads or data-rich payloads
    * depending on the reminder/escalation type.
   */
  #buildFcmMessage(fcmToken, notification, data = {}, options = {}) {
    const {
      channelId = 'reminders_v3',
      systemVisible = false,
      collapseKey,
      tag,
      ttlSeconds = 3600,
      urgent = false
    } = options;

    const message = {
      token: fcmToken,
      data: Object.fromEntries(
        Object.entries({
          title: notification.title,
          body: notification.body,
          ...data
        }).map(([key, value]) => [key, String(value)])
      ),
      android: {
        priority: 'high',
        ttl: `${ttlSeconds}s`,
        collapseKey: collapseKey ?? data.reminderId ?? undefined,
        notification: systemVisible
            ? {
                channelId,
                tag: tag ?? data.reminderId ?? undefined,
                priority: urgent ? 'max' : 'high',
                sound: 'default',
                defaultVibrateTimings: true,
                visibility: 'public'
              }
            : undefined
      },
      apns: {
        headers: {
          'apns-priority': '10',
          'apns-expiration': `${Math.floor(Date.now() / 1000) + ttlSeconds}`
        },
        payload: systemVisible
            ? {
                aps: {
                  alert: {
                    title: notification.title,
                    body: notification.body
                  },
                  sound: 'default'
                }
              }
            : undefined
      }
    };

    if (systemVisible) {
      message.notification = {
        title: notification.title,
        body: notification.body
      };
    }

    return message;
  }

  async #logDeliveryAttempt({
    userId,
    notification,
    data,
    options,
    attempt,
    status,
    response = null,
    error = null
  }) {
    try {
      await db.collection('notification_deliveries').add({
        userId,
        reminderId: data.reminderId ?? null,
        level: data.level ?? null,
        type: data.type ?? 'PUSH_NOTIFICATION',
        title: notification.title,
        body: notification.body,
        systemVisible: Boolean(options.systemVisible),
        channelId: options.channelId ?? 'reminders_v3',
        attempt,
        status,
        providerMessageId: response,
        errorCode: error?.code ?? null,
        errorMessage: error?.message ?? null,
        createdAt: new Date().toISOString()
      });
    } catch (logError) {
      console.warn('⚠️ Failed to log notification delivery:', logError.message);
    }
  }

  async #sendFcm(userId, notification, data = {}, options = {}) {
    const fcmToken = await this.#getFcmToken(userId);
    if (!fcmToken) {
      console.warn(`⚠️ No FCM token for user ${userId} — skipping push`);
      return null;
    }

    const maxAttempts = options.maxAttempts ?? 3;
    let lastError = null;

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      const message = this.#buildFcmMessage(fcmToken, notification, data, options);

      try {
        const response = await firebaseApp.messaging().send(message);
        await this.#logDeliveryAttempt({
          userId,
          notification,
          data,
          options,
          attempt,
          status: 'sent',
          response
        });
        console.log(`📲 FCM sent to ${userId}: ${response}`);
        return { response, attempt, systemVisible: Boolean(options.systemVisible) };
      } catch (err) {
        lastError = err;
        await this.#logDeliveryAttempt({
          userId,
          notification,
          data,
          options,
          attempt,
          status: 'failed',
          error: err
        });

        if (err.code === 'messaging/registration-token-not-registered') {
          await db.collection('users').doc(userId).set(
            { fcmToken: null, fcmUpdatedAt: new Date().toISOString() },
            { merge: true }
          );
          console.warn(`⚠️ FCM token for ${userId} is no longer valid — cleared`);
          return null;
        }

        const shouldRetry = attempt < maxAttempts && RETRYABLE_FCM_ERRORS.has(err.code);
        if (!shouldRetry) {
          console.error('❌ FCM error:', err.message);
          break;
        }

        const backoffMs = 500 * Math.pow(2, attempt - 1);
        await new Promise(resolve => setTimeout(resolve, backoffMs));
      }
    }

    if (lastError) throw lastError;
    return null;
  }

  /**
   * Send standard push notification
   */
  async sendNotification(userId, title, message, metadata = {}) {
    try {
      const notificationDoc = {
        userId,
        title,
        message,
        type: 'PUSH_NOTIFICATION',
        metadata,
        createdAt: new Date().toISOString(),
        read: false
      };

      // Persist in Firestore and send FCM in parallel
      const [notificationRef, delivery] = await Promise.all([
        db.collection('notifications').add(notificationDoc),
        this.#sendFcm(
          userId,
          { title, body: message },
          {
            type: 'PUSH_NOTIFICATION',
            ...metadata
          },
          {
            systemVisible: true,
            channelId: 'reminders_v3',
            collapseKey: metadata.reminderId,
            tag: metadata.reminderId
          }
        )
      ]);

      console.log(`📱 Notification sent to user ${userId}: "${title}"`);
      return {
        notificationId: notificationRef.id,
        persisted: true,
        delivery
      };
    } catch (error) {
      console.error('❌ Error sending notification:', error);
      throw error;
    }
  }

  /**
   * Send full-screen alert
   * FCM data payload carries type=FULL_SCREEN_ALERT so the mobile app
   * can render a full-screen overlay instead of a banner.
   */
  async sendFullScreenAlert(userId, title, message, metadata = {}) {
    try {
      const alertDoc = {
        userId,
        title,
        message,
        type: 'FULL_SCREEN_ALERT',
        metadata,
        createdAt: new Date().toISOString(),
        requiresAction: true,
        mustRead: true
      };

      const [alertRef, delivery] = await Promise.all([
        db.collection('full_screen_alerts').add(alertDoc),
        this.#sendFcm(
          userId,
          { title, body: message },
          { type: 'FULL_SCREEN_ALERT', requiresAction: 'true', ...metadata },
          {
            systemVisible: true,
            channelId: 'escalation_alerts_v3',
            collapseKey: metadata.reminderId,
            tag: `${metadata.reminderId ?? 'alert'}-full-screen`,
            urgent: true
          }
        )
      ]);

      console.log(`🔥 Full-screen alert sent to user ${userId}: "${title}"`);
      return {
        alertId: alertRef.id,
        persisted: true,
        delivery
      };
    } catch (error) {
      console.error('❌ Error sending full-screen alert:', error);
      throw error;
    }
  }

  /**
   * Mark notification as read
   */
  async markAsRead(notificationId) {
    try {
      await db.collection('notifications').doc(notificationId).update({
        read: true,
        readAt: new Date().toISOString()
      });
    } catch (error) {
      console.error('❌ Error marking notification as read:', error);
      throw error;
    }
  }

  /**
   * Get user's unread notifications
   */
  async getUnreadNotifications(userId) {
    try {
      const snapshot = await db
        .collection('notifications')
        .where('userId', '==', userId)
        .where('read', '==', false)
        .orderBy('createdAt', 'desc')
        .limit(50)
        .get();

      return snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
    } catch (error) {
      console.error('❌ Error fetching notifications:', error);
      throw error;
    }
  }

  /**
   * Delete old notifications
   */
  async cleanup(daysOld = 7) {
    try {
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - daysOld);

      const snapshot = await db
        .collection('notifications')
        .where('createdAt', '<', cutoffDate.toISOString())
        .get();

      const batch = db.batch();
      snapshot.docs.forEach(doc => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      console.log(`🗑️ Cleaned up ${snapshot.size} old notifications`);
    } catch (error) {
      console.error('❌ Error cleaning up notifications:', error);
    }
  }
}

export default NotificationService;
