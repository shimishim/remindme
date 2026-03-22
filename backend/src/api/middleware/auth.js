import { firebaseApp } from '../../config/firebase.js';

/**
 * Firebase Auth middleware
 * Verifies the Firebase ID token from the Authorization header.
 * Attaches the decoded token to req.user.
 * Usage: router.use(requireAuth)  OR  router.get('/route', requireAuth, handler)
 */
export async function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid Authorization header' });
  }

  const token = authHeader.slice(7); // Strip "Bearer "

  try {
    const decoded = await firebaseApp.auth().verifyIdToken(token);
    req.user = decoded; // { uid, email, ... }
    next();
  } catch (err) {
    console.warn('⚠️ Auth failed:', err.code || err.message);
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}
