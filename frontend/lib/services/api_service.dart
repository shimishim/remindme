import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reminder_app/models/reminder.dart';

class ApiService {
  final String baseUrl;
  late final Dio _dio;

  ApiService({required this.baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final token = await user.getIdToken();
            options.headers['Authorization'] = 'Bearer $token';
          }

          print('➡️ ${options.method} ${options.uri}');
          print('Body: ${options.data}');

          return handler.next(options);
        },
        onError: (e, handler) {
          print('❌ ERROR: ${e.response?.statusCode}');
          print('Response: ${e.response?.data}');
          return handler.next(e);
        },
      ),
    );
  }

  // ================= CREATE =================
  Future<Reminder> createReminder({
    required String text,
    required String personality,
    required bool allowVoice,
  }) async {
    const url = '/api/v1/reminders';

    try {
      final response = await _dio.post(
        url,
        data: {
          'text': text,
          'personality': personality,
          'allowVoice': allowVoice,
        },
      );

      print('SUMMARY → ${response.statusCode} | ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;

        if (data is Map && data.containsKey('reminder')) {
          return Reminder.fromJson(data['reminder']);
        }

        return Reminder.fromJson(data);
      }

      throw Exception('Failed to create reminder: ${response.statusCode}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final body = e.response?.data;

      print('❌ CREATE ERROR → $statusCode | $body');

      throw Exception('Failed to create reminder: $statusCode');
    }
  }

  // ================= GET =================
  Future<List<Reminder>> getReminders() async {
    final response = await _dio.get('/api/v1/reminders');

    if (response.statusCode == 200) {
      final List list = response.data['reminders'];
      return list.map((e) => Reminder.fromJson(e)).toList();
    }

    throw Exception('Failed to fetch reminders');
  }

  // ================= COMPLETE =================
  Future<void> completeReminder(String id) async {
    final res = await _dio.put('/api/v1/reminders/$id/complete');
    if (res.statusCode != 200) {
      throw Exception('Failed to complete');
    }
  }

  // ================= SNOOZE =================
  Future<void> snoozeReminder(String id, {int minutes = 10}) async {
    final res = await _dio.put(
      '/api/v1/reminders/$id/snooze',
      data: {'minutes': minutes},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to snooze');
    }
  }

  // ================= DELETE =================
  Future<void> deleteReminder(String id) async {
    final res = await _dio.delete('/api/v1/reminders/$id');

    if (res.statusCode != 200) {
      throw Exception('Failed to delete');
    }
  }

  // ================= HEALTH =================
  Future<bool> checkHealth() async {
    try {
      final res = await _dio.get('/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ================= FCM TOKEN =================
  Future<void> registerFcmToken(String token) async {
    try {
      final res =
          await _dio.put('/api/v1/users/fcm-token', data: {'fcmToken': token});
      if (res.statusCode != 200) {
        throw Exception('Failed to register FCM token');
      }
    } catch (e) {
      print('❌ registerFcmToken error: $e');
      // Not critical, so don't rethrow
    }
  }

  Future<void> unregisterFcmToken() async {
    try {
      final res = await _dio.delete('/api/v1/users/fcm-token');
      if (res.statusCode != 200) {
        throw Exception('Failed to unregister FCM token');
      }
    } catch (e) {
      print('❌ unregisterFcmToken error: $e');
      // Not critical, so don't rethrow
    }
  }

  Future<String?> getMyPhoneNumber() async {
    final res = await _dio.get('/api/v1/users/me');

    if (res.statusCode == 200) {
      final user = res.data['user'];
      if (user is Map<String, dynamic>) {
        return user['phoneNumber'] as String?;
      }
      if (user is Map) {
        return user['phoneNumber']?.toString();
      }
    }

    throw Exception('Failed to fetch user profile');
  }

  Future<void> updatePhoneNumber(String phoneNumber) async {
    final res = await _dio.put(
      '/api/v1/users/phone-number',
      data: {'phoneNumber': phoneNumber},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to update phone number');
    }
  }
}
