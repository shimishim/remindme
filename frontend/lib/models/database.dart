import 'package:drift/drift.dart';

/// Reminder table for local Drift SQLite storage
@DataClassName('ReminderEntity')
class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  DateTimeColumn get scheduledTime => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get snoozedUntil => dateTime().nullable()();
  
  TextColumn get personality => text().withDefault(const Constant('sarcastic'))(); // sarcastic, coach, friend
  BoolColumn get allowVoice => boolean().withDefault(const Constant(false))();
  IntColumn get escalationLevel => integer().withDefault(const Constant(0))();
  
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, completed, snoozed
  DateTimeColumn get lastEscalatedAt => dateTime().nullable()();
  
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))(); // pending, synced, failed
  
  @override
  Set<Column> get primaryKey => {id};
}

/// Escalation history table
@DataClassName('EscalationHistoryEntity')
class EscalationHistories extends Table {
  TextColumn get id => text()();
  TextColumn get reminderId => text()();
  TextColumn get userId => text()();
  IntColumn get level => integer()();
  TextColumn get action => text()(); // PUSH_NOTIFICATION, FULL_SCREEN_ALERT, VOICE_CALL, HUMOROUS_PUSH
  DateTimeColumn get triggeredAt => dateTime()();
  TextColumn get message => text()();
  TextColumn get status => text().withDefault(const Constant('sent'))(); // sent, acknowledged, failed
  
  @override
  Set<Column> get primaryKey => {id};
}

/// Notifications table (for displaying notification history)
@DataClassName('NotificationEntity')
class Notifications extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get message => text()();
  TextColumn get type => text()(); // PUSH_NOTIFICATION, FULL_SCREEN_ALERT
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get read => boolean().withDefault(const Constant(false))();
  DateTimeColumn get readAt => dateTime().nullable()();
  TextColumn get metadata => text()(); // JSON string
  
  @override
  Set<Column> get primaryKey => {id};
}
