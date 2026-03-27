import express from 'express';
import { db } from '../../config/firebase.js';
import { requireAuth } from '../middleware/auth.js';

/**
 * Users Routes: profile and device management
 */
const router = express.Router();

function normalizePhoneNumber(phoneNumber) {
  return String(phoneNumber ?? '').replace(/[\s()-]/g, '');
}

function isValidE164PhoneNumber(phoneNumber) {
  return /^\+[1-9]\d{7,14}$/.test(phoneNumber);
}

async function findFallbackPhoneNumber({ currentUid, fcmToken }) {
  const snapshot = await db.collection('users').get();

  const candidates = snapshot.docs
    .map(doc => ({ id: doc.id, ...doc.data() }))
    .filter(user => user.id !== currentUid && user.phoneNumber);

  const sameTokenCandidate = candidates
    .filter(user => fcmToken && user.fcmToken === fcmToken)
    .sort((a, b) => {
      const aTime = new Date(a.phoneNumberUpdatedAt || a.fcmUpdatedAt || 0).getTime();
      const bTime = new Date(b.phoneNumberUpdatedAt || b.fcmUpdatedAt || 0).getTime();
      return bTime - aTime;
    })[0];

  if (sameTokenCandidate?.phoneNumber) {
    return sameTokenCandidate.phoneNumber;
  }

  const latestCandidate = candidates.sort((a, b) => {
    const aTime = new Date(a.phoneNumberUpdatedAt || a.fcmUpdatedAt || 0).getTime();
    const bTime = new Date(b.phoneNumberUpdatedAt || b.fcmUpdatedAt || 0).getTime();
    return bTime - aTime;
  })[0];

  return latestCandidate?.phoneNumber ?? null;
}

// All routes require authentication
router.use(requireAuth);

/**
 * GET /api/v1/users/me
 * Get the authenticated user's stored profile fields.
 */
router.get('/me', async (req, res) => {
  try {
    const userRef = db.collection('users').doc(req.user.uid);
    const userDoc = await userRef.get();
    const data = userDoc.exists ? userDoc.data() : {};

    let phoneNumber = data.phoneNumber ?? null;
    if (!phoneNumber) {
      phoneNumber = await findFallbackPhoneNumber({
        currentUid: req.user.uid,
        fcmToken: data.fcmToken ?? null
      });

      if (phoneNumber) {
        await userRef.set(
          {
            uid: req.user.uid,
            email: req.user.email ?? data.email ?? null,
            phoneNumber,
            phoneNumberUpdatedAt: new Date().toISOString()
          },
          { merge: true }
        );
      }
    }

    res.json({
      success: true,
      user: {
        uid: req.user.uid,
        email: req.user.email ?? data.email ?? null,
        phoneNumber,
        fcmToken: data.fcmToken ?? null
      }
    });
  } catch (error) {
    console.error('❌ Error fetching user profile:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * PUT /api/v1/users/fcm-token
 * Register or update the FCM device token for the authenticated user.
 * The mobile app must call this after login and whenever the token refreshes.
 *
 * Body: { fcmToken: string }
 */
router.put('/fcm-token', async (req, res) => {
  const { fcmToken } = req.body;

  if (!fcmToken || typeof fcmToken !== 'string') {
    return res.status(400).json({ error: 'fcmToken is required' });
  }

  try {
    const userRef = db.collection('users').doc(req.user.uid);
    const existingDoc = await userRef.get();
    const existingData = existingDoc.exists ? existingDoc.data() : {};

    let phoneNumber = existingData.phoneNumber ?? null;
    if (!phoneNumber) {
      phoneNumber = await findFallbackPhoneNumber({
        currentUid: req.user.uid,
        fcmToken
      });
    }

    await userRef.set(
      {
        fcmToken,
        fcmUpdatedAt: new Date().toISOString(),
        uid: req.user.uid,
        email: req.user.email ?? null,
        ...(phoneNumber
            ? {
                phoneNumber,
                phoneNumberUpdatedAt:
                    existingData.phoneNumberUpdatedAt ?? new Date().toISOString()
              }
            : {})
      },
      { merge: true } // create the user doc if it doesn't exist yet
    );

    console.log(`📲 FCM token registered for user ${req.user.uid}`);
    res.json({ success: true, message: 'FCM token registered' });
  } catch (error) {
    console.error('❌ Error registering FCM token:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * DELETE /api/v1/users/fcm-token
 * Unregister the FCM token (call on logout so notifications stop).
 */
router.delete('/fcm-token', async (req, res) => {
  try {
    await db.collection('users').doc(req.user.uid).set(
      { fcmToken: null, fcmUpdatedAt: new Date().toISOString() },
      { merge: true }
    );

    console.log(`🚫 FCM token removed for user ${req.user.uid}`);
    res.json({ success: true, message: 'FCM token removed' });
  } catch (error) {
    console.error('❌ Error removing FCM token:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * PUT /api/v1/users/phone-number
 * Save the phone number used for voice-call reminders.
 * Body: { phoneNumber: string } in E.164 format, for example +972501234567
 */
router.put('/phone-number', async (req, res) => {
  const normalizedPhoneNumber = normalizePhoneNumber(req.body.phoneNumber);

  if (!isValidE164PhoneNumber(normalizedPhoneNumber)) {
    return res.status(400).json({
      error: 'phoneNumber must be in E.164 format, for example +972501234567'
    });
  }

  try {
    await db.collection('users').doc(req.user.uid).set(
      {
        uid: req.user.uid,
        email: req.user.email ?? null,
        phoneNumber: normalizedPhoneNumber,
        phoneNumberUpdatedAt: new Date().toISOString()
      },
      { merge: true }
    );

    console.log(`📞 Phone number updated for user ${req.user.uid}`);
    res.json({
      success: true,
      phoneNumber: normalizedPhoneNumber,
      message: 'Phone number updated'
    });
  } catch (error) {
    console.error('❌ Error updating phone number:', error);
    res.status(500).json({ error: error.message });
  }
});

export default router;
