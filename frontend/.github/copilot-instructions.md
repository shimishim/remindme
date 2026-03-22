# RemindMe Flutter App - Development Guide

## Project Overview
Aggressive escalating reminder app frontend for Android. Key technologies:
- **State Management**: Riverpod (lightweight, powerful)
- **Local Storage**: Drift (type-safe SQLite)
- **Notifications**: Flutter Local Notifications (full-screen alerts)
- **UI**: Material 3 (modern, clean)
- **Backend**: Node.js REST API via Dio

## Quick Start

### Prerequisites
- Flutter 3.0+
- Dart 3.0+
- Android SDK 21+
- Backend running: `cd ../reminder-backend && npm run dev`

### Setup
```bash
# 1. Install dependencies
flutter pub get

# 2. Generate code (Drift DB + Riverpod)
flutter pub run build_runner build

# 3. Update backend URL (optional)
# Edit lib/providers/reminder_providers.dart -> apiServiceProvider

# 4. Run app
flutter run
```

## Key Files

**lib/main.dart** - App initialization, theme setup
**lib/pages/home_page.dart** - Main reminder list screen
**lib/pages/create_reminder_page.dart** - Create new reminder
**lib/models/reminder.dart** - Domain model
**lib/models/app_database.dart** - Drift database
**lib/services/api_service.dart** - Backend communication
**lib/services/notification_service.dart** - Local notifications
**lib/providers/reminder_providers.dart** - State management

## Development Workflow

### Add a New Reminder Feature
1. Add field to `Reminder` model (lib/models/reminder.dart)
2. Update database schema if needed (lib/models/database.dart)
3. Regenerate: `flutter pub run build_runner build`
4. Create UI in pages/ or widgets/
5. Add provider in lib/providers/reminder_providers.dart

### Modify Notification Behavior
- Edit lib/services/notification_service.dart
- Update notification channels or escalation levels
- Test on real Android device (emulator may have issues)

### Update State Management
- Add new provider in lib/providers/reminder_providers.dart
- Use `ConsumerWidget` or `ConsumerStatefulWidget` to consume
- Access via `ref.watch()` or `ref.read()`

### Sync with Backend
- All changes via API service (lib/services/api_service.dart)
- Local DB syncs automatically via callbacks
- Conflicts resolved with timestamps

## Architecture Diagram

```
UI Layer
├── HomePage (list reminders)
├── CreateReminderPage (create new)
└── ReminderCard (individual reminder)

State Management (Riverpod Providers)
├── userRemindersProvider (watch DB)
├── createReminderProvider (POST API)
├── completeReminderProvider (PUT API)
└── deleteReminderProvider (DELETE API)

Services
├── ApiService (Dio HTTP client)
├── NotificationService (local notifications)
└── Database (Drift SQLite)

Backend
└── REST API (Node.js + Firebase)
```

## Common Tasks

### Test Escalation
1. Create reminder with "Test in 1 minute"
2. Wait ~1 minute → should see notification
3. Test full-screen: `curl -X POST http://localhost:3000/api/v1/reminders/rem_xxx/test-escalation -d '{"level": 2}'`

### Add New Personality
1. Update personality options in `create_reminder_page.dart`
2. Add personalities to `_PersonalityChip` widget
3. Backend handles message generation

### Debug Database
```bash
# Connect to device database
adb shell
cd /data/data/com.example.remindme/
sqlite3 reminder_app.db
# Then SQL queries...
```

### Debug API Calls
- Enable logging in ApiService (already enabled for dev)
- Check backend logs for more details
- Use postman/curl to test endpoints directly

## Code Generation

After modifying:
- **Reminder/Database models** → `flutter pub run build_runner build`
- **Riverpod providers** → `flutter pub run build_runner build`

Full rebuild with delete:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Testing Checklist

Before shipping:
- [ ] Create reminder - saves locally & syncs to backend
- [ ] Edit reminder - updates in real-time
- [ ] Delete reminder - removes from UI and backend
- [ ] Snooze - re-schedules and resets escalation
- [ ] Mark complete - hides from active list
- [ ] Notifications - fires at correct time
- [ ] Full-screen alert - appears above all apps (test escalation)
- [ ] Different personalities - choose sarcastic/coach/friend
- [ ] Voice option - toggles but doesn't crash
- [ ] No internet - app still works, syncs when connected

## Performance Tips

- **Database queries**: Always use `.watch()` for reactive updates
- **State management**: Use `.future` for one-off API calls, `.notifier` for mutations
- **Notifications**: Group by type, avoid creating duplicate channels
- **Memory**: Riverpod auto-manages provider lifecycles

## Debugging

### Red Screen?
```bash
flutter run -v  # verbose logs
```

### Hot Reload Issues?
```bash
flutter clean
flutter pub get
flutter pub run build_runner build
flutter run
```

### Database Locked?
- Only one Drift connection at a time
- Restart app if locked
- Check for background operations

### API Timeouts?
- Verify backend is running
- Check network: `adb shell ping google.com`
- Increase timeout in ApiService if needed

## Next Phase: Production Ready

- [ ] Add error boundaries and retry logic
- [ ] Implement offline queue for failed API calls
- [ ] Add Firebase Analytics
- [ ] Add Sentry error tracking
- [ ] Secure API key management
- [ ] Database encryption for sensitive data
- [ ] Widget tests and integration tests
- [ ] App signing for Play Store

## Useful Commands

```bash
flutter doctor              # Check setup
flutter pub get            # Install deps
flutter pub run build_runner build  # Generate code
flutter run -d <device-id> # Run on specific device
flutter run --release      # Release build
flutter build apk          # Build APK
flutter analyze            # Lint check
flutter test               # Unit tests
flutter test integration_test/ # Integration tests
flutter pub upgrade        # Update dependencies
```

## Resource Links

- Flutter: https://flutter.dev/docs
- Riverpod: https://riverpod.dev/docs/getting_started
- Drift: https://drift.simonbinder.eu/docs/
- Material 3: https://m3.material.io/
- Android Notifications: https://developer.android.com/develop/ui/views/notifications

## Team Guidelines

When making changes:
1. Follow existing code style
2. Use meaningful variable names
3. Add comments for complex logic
4. Test on real device
5. Update this guide if adding major features
6. Commit message format: `feature: description` or `fix: description`

Example workflow:
```
git checkout -b feature/add-recurring-reminders
# Make changes
flutter test
flutter run --release
git add .
git commit -m "feature: add recurring reminder support"
git push origin feature/add-recurring-reminders
```
