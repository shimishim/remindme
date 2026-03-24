import admin from 'firebase-admin';
import { config } from './env.js';
import { readFileSync } from 'fs';

let serviceAccount;

// Priority 1: Full JSON string via env var (recommended for Render/cloud deployments)
if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
  try {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
    console.log('✅ Loaded Firebase credentials from FIREBASE_SERVICE_ACCOUNT_JSON env var');
  } catch (e) {
    console.error('❌ Failed to parse FIREBASE_SERVICE_ACCOUNT_JSON:', e.message);
    process.exit(1);
  }
} else {
  // Priority 2: Local JSON file (for local development)
  const JSON_KEY_PATH = 'C:/Users/user/remind/reminder-1b6a3-firebase-adminsdk-fbsvc-7ba557fa47.json';
  try {
    serviceAccount = JSON.parse(readFileSync(JSON_KEY_PATH, 'utf8'));
    console.log('✅ Loaded Firebase credentials from JSON file');
  } catch {
    // Priority 3: Individual env vars fallback
    if (!config.FIREBASE_PROJECT_ID || !config.FIREBASE_PRIVATE_KEY || !config.FIREBASE_CLIENT_EMAIL) {
      console.error('❌ No Firebase credentials found. Set FIREBASE_SERVICE_ACCOUNT_JSON env var on Render.');
      process.exit(1);
    }
    serviceAccount = {
      type: 'service_account',
      project_id: config.FIREBASE_PROJECT_ID,
      private_key: config.FIREBASE_PRIVATE_KEY,
      client_email: config.FIREBASE_CLIENT_EMAIL,
    };
    console.log('✅ Loaded Firebase credentials from individual env vars');
  }
}

const databaseURL = config.FIREBASE_DATABASE_URL ||
  `https://${serviceAccount.project_id}-default-rtdb.firebaseio.com`;

try {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL
  });
  console.log('✅ Firebase initialized successfully');
} catch (error) {
  console.error('❌ Firebase initialization error:', error.message);
  process.exit(1);
}

export const db = admin.firestore();
export const realtimeDb = admin.database();
export const firebaseApp = admin;
