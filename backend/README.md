# RemindMe Backend

Aggressive escalating reminder app backend. Ensures users never miss important tasks.

## Features

- 🧠 **NLP Parser**: Understands natural language reminders ("call Hezi tonight")
- 🔥 **Escalation Engine**: Progressive reminders (notification → full-screen → voice call)
- 📱 **Multi-Platform**: Supports Android and iOS (different delivery mechanisms)
- 📞 **Voice Calls**: Twilio integration for phone call reminders
- 🔄 **Job Scheduling**: BullMQ-based reliable job processing
- 🔐 **Firebase**: Real-time database and Firestore integration

## Project Structure

```
src/
├── config/              # Configuration files
│   ├── env.js          # Environment variables
│   └── firebase.js     # Firebase setup
├── models/              # Data models
│   └── Reminder.js     # Reminder & escalation history
├── services/            # Business logic
│   ├── escalationEngine.js      # Core escalation logic
│   ├── nlpParser.js            # Natural language parsing
│   ├── notificationService.js  # Notification handling
│   └── voiceService.js         # Twilio integration
├── api/                 # API layer
│   ├── routes/
│   │   └── reminders.js        # Reminder endpoints
│   └── middleware/
│       └── auth.js             # Authentication (future)
├── jobs/                # Background jobs
│   └── escalationWorker.js     # Job processor
└── index.js             # Server entry point
```

## Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment

Copy `.env.example` to `.env` and fill in your credentials:

```bash
cp .env.example .env
```

Required:
- **Firebase**: Project ID, private key, client email
- **Twilio**: Account SID, auth token, phone number
- **Redis**: Host and port (for job queuing)

### 3. Start Redis (Required for Job Queue)

**Option A: Docker**
```bash
docker run -d -p 6379:6379 redis:latest
```

**Option B: Local Redis**
```bash
redis-server
```

### 4. Run Server

Development:
```bash
npm run dev
```

Production:
```bash
npm start
```

## API Endpoints

### Create Reminder
```bash
POST /api/v1/reminders
{
  "userId": "user123",
  "text": "Call Hezi tonight",
  "personality": "sarcastic",
  "allowVoice": true
}
```

**Response:**
```json
{
  "success": true,
  "reminder": {
    "id": "rem_xxx",
    "title": "Call Hezi",
    "scheduledTime": "2026-03-21T20:00:00Z",
    "status": "pending"
  },
  "escalationPlan": [
    { "level": 1, "action": "PUSH_NOTIFICATION", "delay_minutes": 0 },
    { "level": 2, "action": "FULL_SCREEN_ALERT", "delay_minutes": 3 },
    { "level": 3, "action": "VOICE_CALL", "delay_minutes": 7 }
  ]
}
```

### Get Reminders
```bash
GET /api/v1/reminders/:userId?status=pending
```

### Complete Reminder
```bash
PUT /api/v1/reminders/:reminderId/complete
```

### Snooze Reminder
```bash
PUT /api/v1/reminders/:reminderId/snooze
{
  "minutes": 10
}
```

### Test Escalation (Debug)
```bash
POST /api/v1/reminders/:reminderId/test-escalation
{
  "level": 2
}
```

### Health Check
```bash
GET /health
```

### Server Status
```bash
GET /api/v1/status
```

## Escalation Flow

```
20:00 → PUSH_NOTIFICATION
         "עכשיו הזמן בן אדם, אל תשכח!"

20:03 → FULL_SCREEN_ALERT (conditional on Android/iOS)
         "אחי… זה משהו רציני. עיניים למעלה."

20:07 → VOICE_CALL (if allowVoice: true)
         Phone rings with escalation message

20:12 → HUMOROUS_PUSH
         "גם ההשעיות שלך נתנו על זה 😏"
```

## NLP Parser Examples

The parser understands:

- ✅ "Call Hezi tonight"
- ✅ "Meeting tomorrow at 2pm"
- ✅ "Buy groceries in 1 hour"
- ✅ "Dentist appointment next Friday"
- ✅ "Follow up with boss at 10am"

## Personalities

- **sarcastic**: Cheeky, witty messages
- **coach**: Motivational, encouraging
- **friend**: Casual, friendly tone

## Database Schema

### Reminders Collection
```json
{
  "id": "rem_xxx",
  "userId": "user123",
  "title": "Call Hezi",
  "description": "Original user input",
  "scheduledTime": "2026-03-21T20:00:00Z",
  "createdAt": "2026-03-21T10:00:00Z",
  "completedAt": null,
  "personality": "sarcastic",
  "allowVoice": true,
  "escalationLevel": 0,
  "status": "pending"
}
```

### Escalation History Collection
```json
{
  "id": "esc_xxx",
  "reminderId": "rem_xxx",
  "userId": "user123",
  "level": 1,
  "action": "PUSH_NOTIFICATION",
  "triggeredAt": "2026-03-21T20:00:00Z",
  "message": "עכשיו הזמן בן אדם, אל תשכח!",
  "status": "sent"
}
```

## Testing

### Manual Test
```bash
# Create a reminder
curl -X POST http://localhost:3000/api/v1/reminders \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test_user",
    "text": "Call Hezi tonight",
    "personality": "sarcastic",
    "allowVoice": true
  }'

# List reminders
curl http://localhost:3000/api/v1/reminders/test_user

# Test escalation
curl -X POST http://localhost:3000/api/v1/reminders/rem_xxx/test-escalation \
  -H "Content-Type: application/json" \
  -d '{ "level": 2 }'
```

## Architecture Overview

```
Mobile App (Android/iOS)
    ↓
    ↓ (API calls)
    ↓
Express Backend
    ├── NLP Parser (understands natural language)
    ├── Firestore (stores reminders)
    ├── BullMQ Queue (schedules escalations)
    ├── Escalation Engine (decides what to do)
    ├── Notification Service (sends push alerts)
    ├── Voice Service (Twilio calls)
    └── Escalation Worker (processes jobs)
```

## Troubleshooting

**Redis connection failed**
- Ensure Redis is running on the configured host/port
- Check `REDIS_HOST` and `REDIS_PORT` in `.env`

**Firebase initialization error**
- Verify Firebase credentials in `.env`
- Ensure JSON is valid (especially private key with newlines)

**Twilio calls not working**
- Confirm Twilio credentials
- Verify phone number format (E.164: +1234567890)
- Check call logs in `/api/v1/status`

**NLP Parser not recognizing time**
- Parser is regex-based (v1)
- Supports: "tonight", "tomorrow", "in X hours", specific times ("2pm")
- Future: Add ML-based parser for complex expressions

## Future Enhancements

- [ ] Advanced NLP with machine learning
- [ ] Cloud sync + multi-device support
- [ ] Reminder templates
- [ ] Analytics dashboard
- [ ] User authentication
- [ ] Rate limiting
- [ ] Advanced logging and monitoring
- [ ] iOS CallKit integration

## License

MIT
