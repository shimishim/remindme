import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification Channel IDs
class NotificationChannels {
  static const String reminders = 'reminders_v2';
  static const String escalation = 'escalation_alerts_v2';
  static const String urgent = 'urgent_reminders_v2';
}

/// Notification Service for handling local notifications
class NotificationService {
  late final FlutterLocalNotificationsPlugin _notificationsPlugin;

  Future<void> initialize() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    // Android initialization
    const androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const iosInitSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    await _createNotificationChannels();
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    // Regular reminders channel
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            NotificationChannels.reminders,
            'Reminders',
            description: 'Notification for regular reminders',
            importance: Importance.defaultImportance,
            enableVibration: true,
            playSound: true,
          ),
        );

    // Escalation alerts channel (high priority)
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            NotificationChannels.escalation,
            'Escalation Alerts',
            description: 'Escalated reminders requiring attention',
            importance: Importance.max,
            enableVibration: true,
            enableLights: true,
            playSound: true,
          ),
        );

    // Urgent channel (max priority)
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            NotificationChannels.urgent,
            'Urgent Reminders',
            description: 'Critical reminders that demand immediate action',
            importance: Importance.max,
            enableVibration: true,
            enableLights: true,
            playSound: true,
          ),
        );
  }

  /// Show standard notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool urgent = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      urgent ? NotificationChannels.urgent : NotificationChannels.reminders,
      urgent ? 'Urgent Reminders' : 'Reminders',
      channelDescription:
          urgent ? 'Urgent notification' : 'Regular reminder notification',
      importance: urgent ? Importance.max : Importance.defaultImportance,
      priority: urgent ? Priority.max : Priority.defaultPriority,
      enableVibration: true,
      playSound: true,
      fullScreenIntent: urgent,
      tag: 'reminder_$id',
      groupKey: 'reminders',
      category: urgent ? AndroidNotificationCategory.alarm : null,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: 'reminders',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Show full-screen alert (high priority with custom sound)
  Future<void> showFullScreenAlert({
    required int id,
    required String title,
    required String message,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      NotificationChannels.escalation,
      'Escalation Alerts',
      channelDescription: 'Escalated reminders',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      fullScreenIntent: true,
      tag: 'escalation_$id',
      styleInformation: BigTextStyleInformation(message),
      autoCancel: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: 'escalations',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      message,
      details,
      payload: payload,
    );
  }

  /// Show voice call notification
  Future<void> showVoiceCallNotification({
    required int id,
    required String callerName,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      NotificationChannels.urgent,
      'Urgent Reminders',
      channelDescription: 'Voice call reminder',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      fullScreenIntent: true,
      tag: 'voice_call_$id',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      '📞 זימון מטלפון',
      'חזק לחיי אתה הוזמן לטלפון: $callerName',
      details,
      payload: payload,
    );
  }

  /// Cancel notification
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Callback when notification is tapped
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - navigation, etc.
  }
}

// Helper to generate unique notification IDs
class NotificationIdGenerator {
  static int generateId() => DateTime.now().millisecondsSinceEpoch.hashCode.abs();

  static int idFromReminderId(String reminderId) =>
      reminderId.hashCode.abs();
}
