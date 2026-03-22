import admin from 'firebase-admin';
import { config } from './env.js';
import { readFileSync } from 'fs';

let serviceAccount;

// Load credentials from service account JSON file (preferred) or fall back to env vars
const JSON_KEY_PATH = 'C:/Users/user/remind/reminder-1b6a3-firebase-adminsdk-fbsvc-7ba557fa47.json';
try {
  serviceAccount = JSON.parse(readFileSync(JSON_KEY_PATH, 'utf8'));
  console.log('✅ Loaded Firebase credentials from JSON file');
} catch {
  // Fallback to environment variables
  serviceAccount = {
    type: 'service_account',
    project_id: config.FIREBASE_PROJECT_ID,
    private_key_id: 'key-id',
    private_key: config.FIREBASE_PRIVATE_KEY,
    client_email: config.FIREBASE_CLIENT_EMAIL,
    client_id: 'client-id',
    auth_uri: 'https://accounts.google.com/o/oauth2/auth',
    token_uri: 'https://oauth2.googleapis.com/token',
    auth_provider_x509_cert_url: 'https://www.googleapis.com/oauth2/v1/certs',
    client_x509_cert_url: ''
  };
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
