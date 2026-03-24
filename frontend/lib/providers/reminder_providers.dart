import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reminder_app/models/app_database.dart';
import 'package:reminder_app/models/reminder.dart';
import 'package:reminder_app/services/api_service.dart';
import 'package:reminder_app/services/notification_service.dart';

// ========== DATABASE PROVIDER ==========
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

// ========== SERVICES PROVIDERS ==========

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

final apiServiceProvider = Provider<ApiService>((ref) {
  final String baseUrl = 'https://remindme-ewvv.onrender.com';
  return ApiService(baseUrl: baseUrl);
});

/// After successful login, register the FCM token with the backend.
/// Call this once from HomePage's initState / first build.
Future<void> registerFcmTokenIfNeeded(ApiService api) async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await api.registerFcmToken(token);
  } catch (_) {} // non-critical
}

/// Call this ONCE after login, e.g., in HomePage's initState
Future<void> syncRemindersWithBackend(WidgetRef ref, String userId) async {
  final db = ref.read(databaseProvider);
  final api = ref.read(apiServiceProvider);
  try {
    final backendReminders = await api.getReminders();
    for (final reminder in backendReminders) {
      final existing = await db.getReminderById(reminder.id);
      if (existing == null) {
        await db.createReminder(reminder.toDatabase());
      }
    }
  } catch (_) {
    // handle error/log if needed
  }
}

// ========== REMINDER  PROVIDERS ==========

/// Watch all reminders for current user
final userRemindersProvider =
    StreamProvider.family<List<Reminder>, String>((ref, userId) {
  final db = ref.watch(databaseProvider);
  return db
      .watchUserReminders(userId)
      .map((entities) => entities.map((e) => e.toDomain()).toList());
});

/// Get pending reminders
final pendingRemindersProvider = StreamProvider<List<Reminder>>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .watchPendingReminders()
      .map((entities) => entities.map((e) => e.toDomain()).toList());
});

/// Create a new reminder
final createReminderProvider =
    FutureProvider.family<Reminder, CreateReminderParams>((ref, params) async {
  final api = ref.watch(apiServiceProvider);
  final db = ref.watch(databaseProvider);

  // Create via API
  final reminder = await api.createReminder(
    text: params.text,
    personality: params.personality,
    allowVoice: params.allowVoice,
  );

  // Save to local database
  await db.createReminder(reminder.toDatabase());

  return reminder;
});

class CreateReminderParams {
  final String text;
  final String personality;
  final bool allowVoice;

  CreateReminderParams({
    required this.text,
    this.personality = 'sarcastic',
    this.allowVoice = false,
  });
}

class SnoozeReminderParams {
  final String reminderId;
  final int minutes;
  SnoozeReminderParams({required this.reminderId, required this.minutes});
}

// Example curl/Postman usage for /api/v1/reminders endpoint:
// curl -X POST "https://remindme-ewvv.onrender.com/api/v1/reminders" \
//   -H "Authorization: Bearer <FIREBASE_ID_TOKEN>" \
//   -H "Content-Type: application/json" \
//   -d '{"text": "Buy milk", "personality": "sarcastic", "allowVoice": false}'

/// Complete reminder
final completeReminderProvider =
    FutureProvider.family<void, String>((ref, reminderId) async {
  final api = ref.watch(apiServiceProvider);
  final db = ref.watch(databaseProvider);

  await api.completeReminder(reminderId);
  await db.completeReminder(reminderId);
});

/// Snooze reminder
final snoozeReminderProvider =
    FutureProvider.family<void, SnoozeReminderParams>((ref, params) async {
  final api = ref.watch(apiServiceProvider);
  final db = ref.watch(databaseProvider);

  await api.snoozeReminder(params.reminderId, minutes: params.minutes);
  await db.snoozeReminder(params.reminderId, Duration(minutes: params.minutes));
});

/// Delete reminder
final deleteReminderProvider =
    FutureProvider.family<void, String>((ref, reminderId) async {
  final api = ref.watch(apiServiceProvider);
  final db = ref.watch(databaseProvider);

  await api.deleteReminder(reminderId);
  await db.deleteReminder(reminderId);
});

// Extension methods to convert between models and database entities
extension ReminderDatabase on Reminder {
  ReminderEntity toDatabase() {
    return ReminderEntity(
      id: id,
      userId: userId,
      title: title,
      description: description,
      scheduledTime: scheduledTime,
      createdAt: createdAt,
      completedAt: completedAt,
      snoozedUntil: snoozedUntil,
      personality: personality,
      allowVoice: allowVoice,
      escalationLevel: escalationLevel,
      status: status,
      lastEscalatedAt: lastEscalatedAt,
      syncStatus: 'synced',
    );
  }
}

extension ReminderEntityDomain on ReminderEntity {
  Reminder toDomain() {
    return Reminder(
      id: id,
      userId: userId,
      title: title,
      description: description,
      scheduledTime: scheduledTime,
      createdAt: createdAt,
      completedAt: completedAt,
      snoozedUntil: snoozedUntil,
      personality: personality,
      allowVoice: allowVoice,
      escalationLevel: escalationLevel,
      status: status,
      lastEscalatedAt: lastEscalatedAt,
    );
  }
}
