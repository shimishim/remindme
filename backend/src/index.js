import express from 'express';
import cors from 'cors';
import { config } from './config/env.js';
import { db } from './config/firebase.js';
import NLPParser from './services/nlpParser.js';
import EscalationEngine from './services/escalationEngine.js';
import NotificationService from './services/notificationService.js';
import VoiceService from './services/voiceService.js';
import EscalationWorker from './jobs/escalationWorker.js';
import InMemoryScheduler from './jobs/inMemoryScheduler.js';
import createReminderRoutes from './api/routes/reminders.js';
import userRoutes from './api/routes/users.js';
import { requireAuth } from './api/middleware/auth.js';

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Services
const nlpParser = new NLPParser();
const notificationService = new NotificationService();
const voiceService = new VoiceService();
const escalationEngine = new EscalationEngine(notificationService, voiceService);
let escalationWorker;
let inMemoryScheduler;

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// API Routes
const reminderRoutes = createReminderRoutes(nlpParser, escalationEngine, escalationWorker, () => inMemoryScheduler);
app.use(`${config.API_PREFIX}/reminders`, reminderRoutes);
app.use(`${config.API_PREFIX}/users`, userRoutes);

// Voice callback (Twilio webhook)
app.post(`${config.API_PREFIX}/voice/callback`, async (req, res) => {
  try {
    const { reminderId, digits } = req.body;

    if (digits) {
      await voiceService.handleVoiceCallback(reminderId, digits);
    }

    res.set('Content-Type', 'text/xml');
    res.send(
      '<?xml version="1.0" encoding="UTF-8"?><Response><Say>תודה על הקלט שלך!</Say></Response>'
    );
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Escalation status (protected)
app.get(`${config.API_PREFIX}/status`, requireAuth, async (req, res) => {
  try {
    const queueInfo = escalationWorker
      ? {
          escalationQueue: await escalationWorker.escalationQueue.count(),
          scheduleQueue: await escalationWorker.scheduleQueue.count()
        }
      : null;

    res.json({
      status: 'running',
      config: {
        environment: config.NODE_ENV,
        redis: `${config.REDIS_HOST}:${config.REDIS_PORT}`
      },
      queues: queueInfo,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Error handling
app.use((err, req, res, next) => {
  console.error('❌ Unhandled error:', err);
  res.status(500).json({
    error: err.message,
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Route not found',
    path: req.path
  });
});

// Global handler: prevent unhandled BullMQ/Redis rejections from crashing the process
process.on('unhandledRejection', (reason) => {
  console.warn('⚠️ Unhandled promise rejection (non-fatal):', reason?.message ?? reason);
});

// Initialize and start server
async function startServer() {
  try {
    console.log('🚀 Starting RemindMe Backend Server...');

    // Initialize escalation worker — non-fatal if Redis is unavailable
    try {
      escalationWorker = new EscalationWorker(escalationEngine);
      await escalationWorker.initialize();
      escalationWorker.startScheduleCheck(5);
    } catch (workerError) {
      console.warn('⚠️ Escalation worker failed to start (non-fatal):', workerError.message);
      escalationWorker = null;
    }

    // Always start in-memory scheduler as fallback (or primary if no Redis)
    inMemoryScheduler = new InMemoryScheduler(escalationEngine);
    inMemoryScheduler.startPeriodicCheck(5);
    console.log('✅ In-memory escalation scheduler started');

    // Always start in-memory scheduler as fallback (or primary if no Redis)
    inMemoryScheduler = new InMemoryScheduler(escalationEngine);
    inMemoryScheduler.startPeriodicCheck(5);
    console.log('✅ In-memory escalation scheduler started');

    // Start Express server
    const server = app.listen(config.PORT, () => {
      console.log(`
╔══════════════════════════════════════════╗
║     RemindMe Backend Server Started      ║
╚══════════════════════════════════════════╝
  
  🌐 Server: http://localhost:${config.PORT}
  🏢 Environment: ${config.NODE_ENV}
  💾 Firebase Project: ${config.FIREBASE_PROJECT_ID}
  🎯 API Prefix: ${config.API_PREFIX}
  📋 Health Check: GET /health
      `);
    });

    // Graceful shutdown
    process.on('SIGTERM', async () => {
      console.log('\n⚠️ SIGTERM received. Shutting down gracefully...');
      server.close(async () => {
        if (escalationWorker) await escalationWorker.cleanup();
        if (inMemoryScheduler) inMemoryScheduler.cleanup();
        process.exit(0);
      });
    });

    process.on('SIGINT', async () => {
      console.log('\n⚠️ SIGINT received. Shutting down gracefully...');
      server.close(async () => {
        if (escalationWorker) await escalationWorker.cleanup();
        if (inMemoryScheduler) inMemoryScheduler.cleanup();
        process.exit(0);
      });
    });
  } catch (error) {
    console.error('❌ Failed to start server:', error);
    process.exit(1);
  }
}

startServer();

export default app;
