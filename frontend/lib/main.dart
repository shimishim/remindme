import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reminder_app/pages/home_page.dart';
import 'package:reminder_app/services/auth_service.dart';
import 'package:reminder_app/services/notification_service.dart';

/// Background FCM handler — must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
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
  debugPrint('main(): Starting app initialization');
  try {
    debugPrint('main(): Initializing Firebase...');
    await Firebase.initializeApp();
    debugPrint('main(): Firebase initialized');
  } catch (e, st) {
    debugPrint('main(): Firebase initialization failed: $e\n$st');
  }

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
  FirebaseMessaging.onMessage.listen((message) {
    debugPrint('main(): Foreground FCM message received');
    _handleFcmMessage(message, notificationService);
  });

  debugPrint('main(): Running app...');
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
  debugPrint('main(): runApp() called');
}

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    debugPrint('authState: [36m$authState[0m');

    return MaterialApp(
      title: 'תזכיר לי',
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
          seedColor: const Color(0xFF2563EB),
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
          seedColor: const Color(0xFF2563EB),
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
