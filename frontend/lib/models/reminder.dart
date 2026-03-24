import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

/// Domain model for Reminder
class Reminder {
  final String id;
  final String userId;
  final String title;
  final String description;
  final DateTime scheduledTime;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? snoozedUntil;

  final String personality; // sarcastic, coach, friend
  final bool allowVoice;
  final int escalationLevel;

  final String status; // pending, completed, snoozed
  final DateTime? lastEscalatedAt;

  Reminder({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.scheduledTime,
    required this.createdAt,
    this.completedAt,
    this.snoozedUntil,
    this.personality = 'sarcastic',
    this.allowVoice = false,
    this.escalationLevel = 0,
    this.status = 'pending',
    this.lastEscalatedAt,
  });

  /// Check if reminder is active (not completed and not snoozed in future)
  bool get isActive => status == 'pending' && !isOverdue;

  /// Check if reminder time has passed
  bool get isOverdue => DateTime.now().isAfter(scheduledTime);

  /// Time until scheduled reminder
  Duration get timeUntilReminder => scheduledTime.difference(DateTime.now());

  /// Snooze until later
  Reminder snooze(Duration duration) {
    final snoozedUntil = DateTime.now().add(duration);
    return copyWith(
      status: 'snoozed',
      snoozedUntil: snoozedUntil,
      escalationLevel: 0,
    );
  }

  /// Mark as completed
  Reminder complete() {
    return copyWith(
      status: 'completed',
      completedAt: DateTime.now(),
    );
  }

  /// Update escalation level
  Reminder updateEscalation(int level) {
    return copyWith(
      escalationLevel: level,
      lastEscalatedAt: DateTime.now(),
    );
  }

  /// Format scheduled time to human-readable string (always in Israel timezone)
  String formatScheduledTime() {
    final israelTz = tz.getLocation('Asia/Jerusalem');
    final local = tz.TZDateTime.from(scheduledTime.toUtc(), israelTz);
    final now = tz.TZDateTime.now(israelTz);
    final today = tz.TZDateTime(israelTz, now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final reminderDate = tz.TZDateTime(israelTz, local.year, local.month, local.day);

    final timeFormatter = DateFormat('HH:mm');

    if (reminderDate == today) {
      return 'היום, ${timeFormatter.format(local)}';
    } else if (reminderDate == tomorrow) {
      return 'מחר, ${timeFormatter.format(local)}';
    } else {
      final dateFormatter = DateFormat('dd/MM/yyyy, HH:mm');
      return dateFormatter.format(local);
    }
  }

  Reminder copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? scheduledTime,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? snoozedUntil,
    String? personality,
    bool? allowVoice,
    int? escalationLevel,
    String? status,
    DateTime? lastEscalatedAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      personality: personality ?? this.personality,
      allowVoice: allowVoice ?? this.allowVoice,
      escalationLevel: escalationLevel ?? this.escalationLevel,
      status: status ?? this.status,
      lastEscalatedAt: lastEscalatedAt ?? this.lastEscalatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'scheduledTime': scheduledTime.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'snoozedUntil': snoozedUntil?.toIso8601String(),
      'personality': personality,
      'allowVoice': allowVoice,
      'escalationLevel': escalationLevel,
      'status': status,
      'lastEscalatedAt': lastEscalatedAt?.toIso8601String(),
    };
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      scheduledTime: DateTime.parse(json['scheduledTime'] as String).toLocal(),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String).toLocal()
          : null,
      snoozedUntil: json['snoozedUntil'] != null
          ? DateTime.parse(json['snoozedUntil'] as String).toLocal()
          : null,
      personality: json['personality'] as String? ?? 'sarcastic',
      allowVoice: json['allowVoice'] as bool? ?? false,
      escalationLevel: json['escalationLevel'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
      lastEscalatedAt: json['lastEscalatedAt'] != null
          ? DateTime.parse(json['lastEscalatedAt'] as String).toLocal()
          : null,
    );
  }

  @override
  String toString() => 'Reminder(id: $id, title: $title, status: $status)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Reminder &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId;

  @override
  int get hashCode => id.hashCode ^ userId.hashCode;
}

/// Domain model for Escalation History
class EscalationLog {
  final String id;
  final String reminderId;
  final String userId;
  final int level;
  final String action; // PUSH_NOTIFICATION, FULL_SCREEN_ALERT, VOICE_CALL, etc
  final DateTime triggeredAt;
  final String message;
  final String status; // sent, acknowledged, failed

  EscalationLog({
    required this.id,
    required this.reminderId,
    required this.userId,
    required this.level,
    required this.action,
    required this.triggeredAt,
    required this.message,
    this.status = 'sent',
  });

  // Local notifications and other platform-specific features would leverage
  // this domain model to have a clean separation from platform code
}
