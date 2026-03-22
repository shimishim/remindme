# RemindMe Backend - Development Guide

## Project Overview
Aggressive escalating reminder app backend. Core features:
- NLP-based natural language reminder parsing
- Progressive escalation engine (notification → full-screen → voice call)
- Firebase Firestore + Realtime database
- BullMQ job scheduling for reliable reminders
- Twilio integration for voice calls

## Quick Start

### Prerequisites
- Node.js 18+
- Redis (for job queuing)
- Firebase project with credentials
- Twilio account (for voice calls)

### Setup
```bash
# 1. Install dependencies
npm install

# 2. Copy and fill environment variables
cp .env.example .env
# Edit .env with your Firebase and Twilio credentials

# 3. Start Redis (in another terminal)
docker run -d -p 6379:6379 redis:latest
# OR locally: redis-server

# 4. Start development server
npm run dev
```

Server runs on `http://localhost:3000`

## Key Files

**src/index.js** - Main Express server entry point
**src/services/escalationEngine.js** - Core escalation logic (most important)
**src/services/nlpParser.js** - Natural language parsing
**src/services/notificationService.js** - Notification delivery
**src/services/voiceService.js** - Twilio voice call integration
**src/jobs/escalationWorker.js** - Background job processor (BullMQ)
**src/api/routes/reminders.js** - REST API endpoints
**src/models/Reminder.js** - Data models

## Architecture

```
Mobile App
    ↓
Express Backend (REST API)
    ├─ NLP Parser (understand "call Hezi tonight")
    ├─ Escalation Engine (decide what action to take)
    ├─ Firebase (store reminders & history)
    ├─ BullMQ (queue & schedule escalations)
    ├─ Notification Service (push alerts)
    └─ Voice Service (Twilio phone calls)
```

## Development Workflow

### Add a New API Endpoint
1. Add route to `src/api/routes/reminders.js`
2. Import and use services as needed
3. Test with curl or Postman

### Modify Escalation Logic
1. Edit escalation rules in `src/services/escalationEngine.js`
2. Change delay times, messages, or actions
3. Run `/api/v1/reminders/:id/test-escalation` to test

### Add Custom Messages
Edit personality definitions in `escalationEngine.js`:
```javascript
defaultMessage: {
  sarcastic: "Your message here",
  coach: "Your message here",
  friend: "Your message here"
}
```

### Test Locally
```bash
# Create a reminder
curl -X POST http://localhost:3000/api/v1/reminders \
  -H "Content-Type: application/json" \
  -d '{"userId": "test", "text": "Call Hezi tonight", "personality": "sarcastic"}'

# Get reminder ID from response, then test escalation
curl -X POST http://localhost:3000/api/v1/reminders/rem_xxx/test-escalation \
  -H "Content-Type: application/json" \
  -d '{"level": 2}'
```

## Database Collections

**reminders** - User reminders
**escalation_history** - Log of all escalation events
**notifications** - Delivered notifications
**call_logs** - Voice call records
**full_screen_alerts** - Full-screen alert history

## Common Tasks

### Enable/Disable Voice Calls
- Each reminder has `allowVoice` flag
- Only escalates to voice if flag is true AND user consent given

### Change Escalation Timing
In `escalationEngine.js`, edit escalationRules:
```javascript
{
  delay_minutes: 3,  // Change this
  action: 'FULL_SCREEN_ALERT',
  ...
}
```

### Add New Personality Type
1. Add to `buildEscalationRules()` in escalationEngine.js
2. Add messages for all escalation levels
3. Accept new personality in POST /reminders

### Test NLP Parser
```bash
node -e "
import NLPParser from './src/services/nlpParser.js';
const parser = new NLPParser();
console.log(parser.parse('Call Hezi tomorrow at 3pm'));
"
```

## Troubleshooting

**"ECONNREFUSED: Connection refused Redis"**
- Redis not running. Start it: `docker run -d -p 6379:6379 redis:latest`

**"Firebase initialization error"**
- Check .env file: FIREBASE_PRIVATE_KEY must have literal `\n` not escaped
- Verify all Firebase credentials are correct

**"Twilio calls not working"**
- Check Twilio credentials in .env
- Ensure TWILIO_PHONE_NUMBER is in E.164 format: +1234567890
- Test with: `npm run test:voice` (not yet implemented)

**Jobs not executing**
- Check Redis connection
- Verify BullMQ in escalationWorker.js is initialized
- Check server logs for worker startup message

## Performance Notes

- NLP parser is regex-based (V1) - sufficient for MVP
- BullMQ handles job persistence + retries automatically
- Firebase queries limited to 100 results for performance
- Consider caching user preference personalization

## Next Steps

When moving to production:
1. [ ] Add API authentication/authorization
2. [ ] Implement rate limiting
3. [ ] Add comprehensive logging (winston/pino)
4. [ ] Add error tracking (Sentry)
5. [ ] Set up CI/CD with GitHub Actions
6. [ ] Add automated tests (Jest)
7. [ ] Deploy to Cloud Run or AWS Lambda
8. [ ] Enable Firebase security rules
9. [ ] Add SMS fallback for unreliable voice calls
10. [ ] Implement advanced NLP with ML models

## Useful Resources

- Firebase Admin SDK: https://firebase.google.com/docs/database
- BullMQ: https://docs.bullmq.io/
- Twilio Voice: https://www.twilio.com/docs/voice
- Express: https://expressjs.com/

## Team Communication

When making changes, document:
- What you changed (file + method)
- Why you changed it
- How to test it

Example commit message:
```
feat: Add recurring reminder support to NLP parser

- Modified nlpParser.parse() to detect "every day/week" patterns
- Tested with: "Call Hezi every Friday at 2pm"
- Escalation behavior unchanged
```
