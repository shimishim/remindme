import 'package:flutter/services.dart';

/// Speech-to-text service using Android's built-in speech recognizer via MethodChannel.
class SpeechService {
  static const _channel = MethodChannel('com.example.remindme/speech');

  bool _isListening = false;
  bool get isListening => _isListening;

  Function(String text, bool isFinal)? onResult;
  Function()? onDone;
  Function(String error)? onError;

  SpeechService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onResult':
        final text = call.arguments['text'] as String? ?? '';
        final isFinal = call.arguments['isFinal'] as bool? ?? false;
        onResult?.call(text, isFinal);
        if (isFinal) {
          _isListening = false;
          onDone?.call();
        }
        break;
      case 'onError':
        _isListening = false;
        onError?.call(call.arguments as String? ?? 'Unknown error');
        break;
    }
  }

  Future<bool> startListening({String locale = 'he-IL'}) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'startListening',
        {'locale': locale},
      );
      _isListening = result ?? false;
      return _isListening;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to start');
      return false;
    }
  }

  Future<void> stopListening() async {
    try {
      await _channel.invokeMethod('stopListening');
    } catch (_) {}
    _isListening = false;
  }
}
