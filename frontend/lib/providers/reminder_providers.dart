import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reminder_app/models/app_database.dart';
import 'package:reminder_app/models/reminder.dart';
import 'package:reminder_app/services/api_service.dart';
import 'package:reminder_app/services/notification_service.dart';

// ========== DATABASE PROVIDER ==========
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

// ========== SERVICES PROVIDERS ==========

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(
    baseUrl: 'http://10.0.0.2:3000', // Real device / WiFi IP of dev machine
  );
});

/// After successful login, register the FCM token with the backend.
/// Call this once from HomePage's initState / first build.
Future<void> registerFcmTokenIfNeeded(ApiService api) async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await api.registerFcmToken(token);
  } catch (_) {} // non-critical
}

// ========== REMINDER  PROVIDERS ==========

/// Watch all reminders for current user
final userRemindersProvider = StreamProvider.family<List<Reminder>, String>((ref, userId) async* {
  final db = ref.watch(databaseProvider);
  final api = ref.watch(apiServiceProvider);
  
  // First, try to sync with backend
  try {
    final backendReminders = await api.getReminders();
    
    // Update local database with backend data
    for (final reminder in backendReminders) {
      final existing = await db.getReminderById(reminder.id);
      if (existing == null) {
        // New reminder from backend
        await db.createReminder(
          reminder.toDatabase(),
        );
      }
    }
  } catch (e) {
    // sync failed; continue with local data
  }

  // Watch local database
  yield* db.watchUserReminders(userId)
      .map((entities) => entities.map((e) => e.toDomain()).toList())
      .asBroadcastStream();
});

/// Get pending reminders
final pendingRemindersProvider = StreamProvider<List<Reminder>>((ref) async* {
  final db = ref.watch(databaseProvider);
  
  yield* db.watchPendingReminders()
      .map((entities) => entities.map((e) => e.toDomain()).toList())
      .asBroadcastStream();
});

/// Create a new reminder
final createReminderProvider = FutureProvider.family<Reminder, CreateReminderParams>((ref, params) async {
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

/// Complete reminder
final completeReminderProvider = FutureProvider.family<void, String>((ref, reminderId) async {
  final api = ref.watch(apiServiceProvider);
  final db = ref.watch(databaseProvider);
  
  await api.completeReminder(reminderId);
  await db.completeReminder(reminderId);
});

/// Snooze reminder
final snoozeReminderProvider = FutureProvider.family<void, (String, int)>((ref, params) async {
  final (reminderId, minutes) = params;
  final api = ref.watch(apiServiceProvider);
  final db = ref.watch(databaseProvider);
  
  await api.snoozeReminder(reminderId, minutes: minutes);
  await db.snoozeReminder(reminderId, Duration(minutes: minutes));
});

/// Delete reminder
final deleteReminderProvider = FutureProvider.family<void, String>((ref, reminderId) async {
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
