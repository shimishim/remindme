import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'database.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Reminders, EscalationHistories, Notifications])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ========== REMINDER OPERATIONS ==========

  Future<void> createReminder(ReminderEntity reminder) {
    return into(reminders).insert(reminder);
  }

  Future<List<ReminderEntity>> getRemindersByUserId(String userId) {
    return (select(reminders)..where((r) => r.userId.equals(userId)))
        .get();
  }

  Future<List<ReminderEntity>> getPendingReminders() {
    return (select(reminders)..where((r) => r.status.equals('pending')))
        .get();
  }

  Stream<List<ReminderEntity>> watchPendingReminders() {
    return (select(reminders)..where((r) => r.status.equals('pending')))
        .watch();
  }

  Future<List<ReminderEntity>> getSnoozedReminders() {
    return (select(reminders)..where((r) => r.status.equals('snoozed')))
        .get();
  }

  Future<ReminderEntity?> getReminderById(String reminderId) {
    return (select(reminders)..where((r) => r.id.equals(reminderId)))
        .getSingleOrNull();
  }

  Future<void> updateReminder(ReminderEntity reminder) {
    return update(reminders).replace(reminder);
  }

  Future<void> completeReminder(String reminderId) {
    return (update(reminders)..where((r) => r.id.equals(reminderId)))
        .write(RemindersCompanion(
          status: const Value('completed'),
          completedAt: Value(DateTime.now()),
        ));
  }

  Future<void> snoozeReminder(String reminderId, Duration duration) {
    final snoozedUntil = DateTime.now().add(duration);
    return (update(reminders)..where((r) => r.id.equals(reminderId)))
        .write(RemindersCompanion(
          status: const Value('snoozed'),
          snoozedUntil: Value(snoozedUntil),
          escalationLevel: const Value(0),
        ));
  }

  Future<void> deleteReminder(String reminderId) {
    return (delete(reminders)..where((r) => r.id.equals(reminderId)))
        .go();
  }

  Stream<List<ReminderEntity>> watchUserReminders(String userId) {
    return (select(reminders)..where((r) => r.userId.equals(userId)))
        .watch();
  }

  // ========== ESCALATION HISTORY OPERATIONS ==========

  Future<void> logEscalation(EscalationHistoryEntity escalation) {
    return into(escalationHistories).insert(escalation);
  }

  Future<List<EscalationHistoryEntity>> getEscalationHistory(String reminderId) {
    return (select(escalationHistories)
          ..where((e) => e.reminderId.equals(reminderId))
          ..orderBy([(e) => OrderingTerm(expression: e.triggeredAt)]))
        .get();
  }

  // ========== NOTIFICATION OPERATIONS ==========

  Future<void> logNotification(NotificationEntity notification) {
    return into(notifications).insert(notification);
  }

  Future<List<NotificationEntity>> getUnreadNotifications(String userId) {
    return (select(notifications)
          ..where((n) => n.userId.equals(userId) & n.read.equals(false))
          ..orderBy([(n) => OrderingTerm(expression: n.createdAt)]))
        .get();
  }

  Future<void> markNotificationAsRead(String notificationId) {
    return (update(notifications)..where((n) => n.id.equals(notificationId)))
        .write(NotificationsCompanion(
          read: const Value(true),
          readAt: Value(DateTime.now()),
        ));
  }

  // ========== CLEANUP ==========

  Future<void> deleteOldNotifications(Duration olderThan) {
    final cutoff = DateTime.now().subtract(olderThan);
    return (delete(notifications)
          ..where((n) => n.createdAt.isSmallerThanValue(cutoff)))
        .go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'reminder_app.db'));
    
    return NativeDatabase(file);
  });
}
