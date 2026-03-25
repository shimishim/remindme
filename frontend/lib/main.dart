import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reminder_app/models/app_database.dart';
import 'package:reminder_app/pages/home_page.dart';
import 'package:reminder_app/providers/reminder_providers.dart';
import 'package:reminder_app/services/auth_service.dart';
import 'package:reminder_app/services/notification_service.dart';
import 'package:reminder_app/services/remote_config_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Returns true if the reminder is still pending or snoozed in the local DB.
/// When the reminder was deleted/completed locally but the backend still fires
/// an FCM push (e.g. because the Render free-tier server was asleep and
/// missed the cancel call), this guard prevents showing a ghost notification.
/// Falls back to true (show notification) on any DB error so we never
/// silently drop a reminder the user hasn't acted on yet.
Future<bool> _isReminderActive(String reminderId) async {
  if (reminderId.isEmpty) return true;
  final db = AppDatabase();
  try {
    final reminder = await db.getReminderById(reminderId);
    if (reminder == null) return false; // deleted from local DB
    return reminder.status == 'pending' || reminder.status == 'snoozed';
  } catch (_) {
    return true; // DB unavailable — show the notification to be safe
  } finally {
    await db.close();
  }
}

/// Background FCM handler — must be a top-level function.
/// Runs in a separate isolate when the app is terminated or in background.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final reminderId = message.data['reminderId'] ?? '';
  if (!await _isReminderActive(reminderId)) {
    debugPrint('FCM background: skipping ghost notification for $reminderId');
    return;
  }
  final ns = NotificationService();
  await ns.initialize();
  _handleFcmMessage(message, ns);
}

/// Route an incoming FCM message to the right local notification style
void _handleFcmMessage(RemoteMessage message, NotificationService ns) {
  final data = message.data;
  final notification = message.notification;
  final type = data['type'] ?? '';
  final title = notification?.title ?? data['title'] ?? 'תזכורת';
  final body = notification?.body ?? data['body'] ?? '';
  final reminderId = data['reminderId'] ?? '';
  final id = NotificationIdGenerator.idFromReminderId(reminderId);

  if (type == 'FULL_SCREEN_ALERT') {
    ns.showFullScreenAlert(
        id: id, title: title, message: body, payload: reminderId);
  } else {
    // All reminder notifications are urgent (heads-up with sound)
    ns.showNotification(
        id: id, title: title, body: body, payload: reminderId, urgent: true);
  }
}

void main() async {
  // Print network debug info for real device troubleshooting
  // (NetworkInterface debug removed for compatibility)
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezones — must be done before any notification scheduling
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Jerusalem'));

  debugPrint('main(): Starting app initialization');
  try {
    debugPrint('main(): Initializing Firebase...');
    await Firebase.initializeApp();
    debugPrint('main(): Firebase initialized');
  } catch (e, st) {
    debugPrint('main(): Firebase initialization failed: $e\n$st');
  }

  // Initialize Remote Config (never throws — falls back to defaults)
  final remoteConfig = await RemoteConfigService.initialize();
  debugPrint(
      'main(): RemoteConfig initialized, apiBaseUrl=${remoteConfig.apiBaseUrl}');

  // Auto sign-in anonymously if not already logged in
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    try {
      debugPrint('main(): Signing in anonymously...');
      await auth.signInAnonymously();
      debugPrint('main(): Anonymous sign-in success');
    } catch (e, st) {
      debugPrint('main(): Anonymous sign-in failed: $e\n$st');
    }
  } else {
    debugPrint('main(): Already signed in: ${auth.currentUser?.uid}');
  }

  // Initialize notification service
  final notificationService = NotificationService();
  try {
    debugPrint('main(): Initializing notification service...');
    await notificationService.initialize();
    debugPrint('main(): Notification service initialized');
  } catch (e, st) {
    debugPrint('main(): Notification service init failed: $e\n$st');
  }

  // Request notification permissions
  final messaging = FirebaseMessaging.instance;
  try {
    debugPrint('main(): Requesting notification permissions...');
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    debugPrint('main(): Notification permissions requested');
  } catch (e, st) {
    debugPrint('main(): Notification permission request failed: $e\n$st');
  }

  // Background handler (app terminated / in background)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Foreground handler (app is open)
  FirebaseMessaging.onMessage.listen((message) async {
    debugPrint('main(): Foreground FCM message received');
    final reminderId = message.data['reminderId'] ?? '';
    if (!await _isReminderActive(reminderId)) {
      debugPrint(
          'main(): Skipping ghost FCM notification for reminder $reminderId');
      return;
    }
    _handleFcmMessage(message, notificationService);
  });

  debugPrint('main(): Running app...');
  runApp(
    ProviderScope(
      overrides: [
        // Provide the already-initialized NotificationService so all providers
        // share the same instance (avoids uninitialized plugin errors).
        notificationServiceProvider.overrideWithValue(notificationService),
        // Provide the already-initialized RemoteConfigService.
        remoteConfigServiceProvider.overrideWithValue(remoteConfig),
      ],
      child: const MyApp(),
    ),
  );
  debugPrint('main(): runApp() called');
}

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final remoteConfig = ref.watch(remoteConfigServiceProvider);
    debugPrint('authState: [36m$authState[0m');

    return MaterialApp(
      title: remoteConfig.appTitle,
      debugShowCheckedModeBanner: false,
      locale: const Locale('he', 'IL'),
      supportedLocales: const [
        Locale('he', 'IL'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: remoteConfig.primaryColor,
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          displayMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: remoteConfig.primaryColor,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.light,
      home: authState.when(
        data: (user) {
          debugPrint('authStateProvider DATA: user=${user?.uid}');
          return const HomePage();
        },
        loading: () {
          Future.delayed(const Duration(seconds: 5), () {
            debugPrint('WARNING: authState stuck in loading');
          });
          debugPrint('authStateProvider STILL LOADING...');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
        error: (err, stack) {
          debugPrint('authStateProvider ERROR: $err');
          return Scaffold(
            body: Center(child: Text('Error: $err')),
          );
        },
      ),
    );
  }
}
