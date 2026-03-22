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
    ns.showFullScreenAlert(id: id, title: title, message: body, payload: reminderId);
  } else {
    // All reminder notifications are urgent (heads-up with sound)
    ns.showNotification(id: id, title: title, body: body, payload: reminderId, urgent: true);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Auto sign-in anonymously if not already logged in
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    try {
      await auth.signInAnonymously();
    } catch (e) {
      // Anonymous auth failed - continue anyway, app will work offline
      debugPrint('Anonymous sign-in failed: $e');
    }
  }

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Request notification permissions
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // Background handler (app terminated / in background)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Foreground handler (app is open)
  FirebaseMessaging.onMessage.listen((message) {
    _handleFcmMessage(message, notificationService);
  });

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

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
          seedColor: const Color(0xFFFF6B6B), // Aggressive red
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
          seedColor: const Color(0xFFFF6B6B),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.light,
      home: authState.when(
        data: (user) => const HomePage(),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const HomePage(),
      ),
    );
  }
}
