import { db, firebaseApp } from '../config/firebase.js';

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
   * Sends data-only messages so the Flutter app controls notification display
   * (channel, importance, heads-up, full-screen intent, etc.).
   */
  async #sendFcm(userId, notification, data = {}) {
    const fcmToken = await this.#getFcmToken(userId);
    if (!fcmToken) {
      console.warn(`⚠️ No FCM token for user ${userId} — skipping push`);
      return null;
    }

    const message = {
      token: fcmToken,
      // Data-only: no "notification" key — Flutter app handles display
      data: Object.fromEntries(
        Object.entries({
          title: notification.title,
          body: notification.body,
          ...data,
        }).map(([k, v]) => [k, String(v)])
      ),
      android: {
        priority: 'high',
      },
      apns: { headers: { 'apns-priority': '10' } }
    };

    try {
      const response = await firebaseApp.messaging().send(message);
      console.log(`📲 FCM sent to ${userId}: ${response}`);
      return response;
    } catch (err) {
      // Token expired / unregistered — clear it so we don't keep trying
      if (err.code === 'messaging/registration-token-not-registered') {
        await db.collection('users').doc(userId).update({ fcmToken: null });
        console.warn(`⚠️ FCM token for ${userId} is no longer valid — cleared`);
      } else {
        console.error('❌ FCM error:', err.message);
      }
      return null;
    }
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
      await Promise.all([
        db.collection('notifications').add(notificationDoc),
        this.#sendFcm(userId, { title, body: message }, {
          type: 'PUSH_NOTIFICATION',
          ...metadata
        })
      ]);

      console.log(`📱 Notification sent to user ${userId}: "${title}"`);
      return notificationDoc;
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

      await Promise.all([
        db.collection('full_screen_alerts').add(alertDoc),
        this.#sendFcm(
          userId,
          { title, body: message },
          { type: 'FULL_SCREEN_ALERT', requiresAction: 'true', ...metadata }
        )
      ]);

      console.log(`🔥 Full-screen alert sent to user ${userId}: "${title}"`);
      return alertDoc;
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
