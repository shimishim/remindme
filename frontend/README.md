## Debugging API Endpoints

To test the reminder creation endpoint manually, use curl or Postman:

### curl example

```
curl -X POST "https://remindme-ewvv.onrender.com/api/v1/reminders" \
  -H "Authorization: Bearer <FIREBASE_ID_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"text": "Buy milk", "personality": "sarcastic", "allowVoice": false}'
```

Replace `<FIREBASE_ID_TOKEN>` with a valid Firebase user token.

### Postman

1. Set method to POST and URL to `https://remindme-ewvv.onrender.com/api/v1/reminders`
2. Add header: `Authorization: Bearer <FIREBASE_ID_TOKEN>`
3. Add header: `Content-Type: application/json`
4. Set body (raw, JSON):
   ```json
   {
     "text": "Buy milk",
     "personality": "sarcastic",
     "allowVoice": false
   }
   ```
# RemindMe Flutter Mobile App

Aggressive escalating reminder app for Android. Ensures users never miss important tasks with progressive notifications, full-screen alerts, and optional voice calls.


# RemindMe Flutter Mobile App

אפליקציית תזכורות מתקדמת לאנדרואיד.

## מבנה ספריות

```
frontend/
├── analysis_options.yaml
├── pubspec.yaml
├── README.md
├── android/
├── assets/
├── build/
├── lib/
│   ├── main.dart
│   ├── models/
│   ├── pages/
│   ├── providers/
│   ├── services/
│   └── widgets/
├── test/
└── ...
```

## התקנה והרצה

1. התקנת תלויות:
  ```bash
  cd frontend
  flutter pub get
  ```
2. הרצת build לקוד גנרטיבי:
  ```bash
  flutter pub run build_runner build
  ```
3. הרצת האפליקציה:
  ```bash
  flutter run
  ```

## פקודות נפוצות

- בדיקות: `flutter test`
- בניית APK: `flutter build apk`
- בניית App Bundle: `flutter build appbundle`

## הערות

- ודא שה-backend רץ בנפרד (ראה README בתיקיית backend).
- לעדכון קבצים/מבנה – עדכן גם כאן.
### State Management: Riverpod
- `userRemindersProvider` - Watch user's reminders (streams from local DB)
- `createReminderProvider` - Create new reminder (sync with backend)
- `completeReminderProvider` - Mark reminder complete
- `snoozeReminderProvider` - Snooze for X minutes
- `deleteReminderProvider` - Delete reminder

### Local Storage: Drift SQLite
Tables:
- `Reminders` - User reminders
- `EscalationHistories` - Escalation event logs
- `Notifications` - Notification history

### API Integration: Dio
Communicates with backend via:
```
POST   /api/v1/reminders           # Create
GET    /api/v1/reminders/:userId   # List
PUT    /api/v1/reminders/:id/complete
PUT    /api/v1/reminders/:id/snooze
DELETE /api/v1/reminders/:id
```

### Notifications: Flutter Local Notifications
Three channels:
- **Reminders** (default importance)
- **Escalation Alerts** (high importance)
- **Urgent** (max importance, sounds/vibration)

## Key Components

### Reminder Model
```dart
Reminder {
  id: String
  userId: String
  title: String
  scheduledTime: DateTime
  personality: String ('sarcastic', 'coach', 'friend')
  allowVoice: bool
  escalationLevel: int
  status: String ('pending', 'completed', 'snoozed')
}
```

### Escalation Levels
1. **L1** (0 min delay): Regular push notification
2. **L2** (3 min): Full-screen alert with aggressive message
3. **L3** (7 min): Voice call (if enabled)
4. **L4** (12 min): Humorous/sarcastic push

### Personalities
- **Sarcastic** 😏: "Seriously, did you forget again?"
- **Coach** 💪: "You got this! Let's go!"
- **Friend** 😊: "Hey buddy, just checking in"

## Development

### Add New Screen
1. Create file in `lib/pages/`
2. Export from `pages.dart`
3. Add route in `main.dart`

### Modify Reminder Model
1. Edit `lib/models/reminder.dart`
2. Update `lib/models/database.dart` if schema changes
3. Run: `flutter pub run build_runner build`

### Add New Provider
1. Create in `lib/providers/reminder_providers.dart`
2. Use `ConsumerWidget` or `ConsumerStatefulWidget` to consume

### Test API Locally
1. Start backend: `cd ../reminder-backend && npm run dev`
2. Update `apiServiceProvider` baseUrl in `reminder_providers.dart`
3. Run app: `flutter run`

## Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### Manual Testing
1. Create reminder with text: "Test in 1 minute"
2. Wait 1 minute - should see notification
3. Test escalation via backend: `POST /api/v1/reminders/:id/test-escalation`
4. Try different personalities and voice options

## Common Issues

**"Build failed" after pubspec changes**
```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

**Notifications not working**
- Check Android permissions in AndroidManifest.xml
- Ensure NotificationService is initialized in main()
- Test on real device (emulator may have issues)

**Database errors**
```bash
# Reset database
flutter clean
flutter pub get
flutter pub run build_runner build
flutter run
```

**API connection issues**
- Verify backend is running on correct port
- Check backend URL in `reminder_providers.dart`
- Ensure phone can reach backend (check firewall)

## Performance Optimization

- **Database**: Indexed queries on userId and status
- **State**: Riverpod caches providers, use `.future` for one-off operations
- **Notifications**: Grouped by type, not creating excessive channels
- **Memory**: Drift handles connection pooling automatically

## Future Enhancements

- [ ] Firebase Cloud Messaging integration
- [ ] Multi-device sync
- [ ] Recurring reminders UI
- [ ] Reminder templates
- [ ] Analytics dashboard
- [ ] User authentication (Firebase Auth)
- [ ] Dark mode
- [ ] Offline queue for failed API calls
- [ ] Background location tracking
- [ ] Advanced time parsing with ML

## Security

- All API calls use HTTPS in production
- Local database unencrypted (consider adding encryption for production)
- No sensitive data stored in SharedPreferences
- Firebase rules should be configured for production

## Building for Release

### Generate App Bundle
```bash
flutter build appbundle
```

### Generate APK
```bash
flutter build apk
```

### Sign App
```bash
jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 \
  -keystore my-release-key.keystore app-unsigned.apk alias_name
```

## Resources

- [Flutter Docs](https://flutter.dev)
- [Riverpod Docs](https://riverpod.dev)
- [Drift SQL Mapper](https://drift.simonbinder.eu/)
- [Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications)
- [Material 3 Design](https://m3.material.io/)

## License

MIT

## Support

For issues or questions:
1. Check GitHub issues
2. Review backend logs
3. Test with emulator and real device
4. Check Flutter/Dart versions are up to date
