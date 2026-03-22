import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reminder_app/models/reminder.dart';

/// API client for communicating with RemindMe backend.
/// Automatically attaches the Firebase Auth ID token to every request.
class ApiService {
  final String baseUrl;
  late final Dio _dio;

  ApiService({required this.baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      contentType: 'application/json',
    ));

    // Inject Bearer token on every request
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final token = await user.getIdToken();
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestHeader: false,
      requestBody: true,
      responseBody: true,
    ));
  }

  /// Register / update FCM device token
  Future<void> registerFcmToken(String fcmToken) async {
    try {
      await _dio.put('/api/v1/users/fcm-token', data: {'fcmToken': fcmToken});
    } on DioException catch (e) {
      throw Exception('Failed to register FCM token: ${e.message}');
    }
  }

  /// Unregister FCM token on logout
  Future<void> unregisterFcmToken() async {
    try {
      await _dio.delete('/api/v1/users/fcm-token');
    } catch (_) {} // Best-effort on logout
  }

  /// Create a new reminder
  Future<Reminder> createReminder({
    required String text,
    required String personality,
    required bool allowVoice,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/reminders',
        data: {
          'text': text,
          'personality': personality,
          'allowVoice': allowVoice,
        },
      );

      if (response.statusCode == 201) {
        return Reminder.fromJson(response.data['reminder']);
      } else {
        throw Exception('Failed to create reminder: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Failed to create reminder: ${e.message}');
    }
  }

  /// Get all reminders for the authenticated user
  Future<List<Reminder>> getReminders({String status = 'all'}) async {
    try {
      final response = await _dio.get(
        '/api/v1/reminders',
        queryParameters: {'status': status},
      );

      if (response.statusCode == 200) {
        final List<dynamic> remindersJson = response.data['reminders'];
        return remindersJson
            .map((json) => Reminder.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to fetch reminders: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Failed to fetch reminders: ${e.message}');
    }
  }
  Future<Reminder> getReminder(String reminderId) async {
    try {
      final response = await _dio.get(
        '/api/v1/reminders/detail/$reminderId',
      );

      if (response.statusCode == 200) {
        return Reminder.fromJson(response.data['reminder']);
      } else {
        throw Exception('Failed to fetch reminder: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Failed to fetch reminder: ${e.message}');
    }
  }

  /// Mark reminder as completed
  Future<void> completeReminder(String reminderId) async {
    try {
      final response = await _dio.put(
        '/api/v1/reminders/$reminderId/complete',
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to complete reminder: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Failed to complete reminder: ${e.message}');
    }
  }

  /// Snooze reminder
  Future<void> snoozeReminder(String reminderId, {int minutes = 10}) async {
    try {
      final response = await _dio.put(
        '/api/v1/reminders/$reminderId/snooze',
        data: {'minutes': minutes},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to snooze reminder: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Failed to snooze reminder: ${e.message}');
    }
  }

  /// Delete reminder
  Future<void> deleteReminder(String reminderId) async {
    try {
      final response = await _dio.delete(
        '/api/v1/reminders/$reminderId',
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete reminder: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Failed to delete reminder: ${e.message}');
    }
  }

  /// Test escalation (for debugging)
  Future<void> testEscalation(String reminderId, {int level = 1}) async {
    try {
      final response = await _dio.post(
        '/api/v1/reminders/$reminderId/test-escalation',
        data: {'level': level},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to test escalation: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Failed to test escalation: ${e.message}');
    }
  }

  /// Check server health
  Future<bool> checkHealth() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
