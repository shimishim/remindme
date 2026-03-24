import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';

/// Keys used in Firebase Remote Config console.
/// Default values mirror the hardcoded values in main.dart / providers.
class RemoteConfigService {
  final FirebaseRemoteConfig _rc;

  RemoteConfigService._(this._rc);

  // ─── Key names ────────────────────────────────────────────────────────────
  static const _kPrimaryColor = 'primary_color'; // e.g. "#3370E5"
  static const _kApiBaseUrl = 'api_base_url';
  static const _kAppTitle = 'app_title';

  // ─── Defaults (identical to current hardcoded values) ────────────────────
  static const _defaultPrimaryColor = '#3370E5';
  static const _defaultApiBaseUrl = 'https://remindme-evwv.onrender.com';
  static const _defaultAppTitle = 'תזכיר לי';

  // ─── Init ────────────────────────────────────────────────────────────────

  /// Call once after [Firebase.initializeApp()].
  /// Never throws — falls back to defaults on any error.
  static Future<RemoteConfigService> initialize() async {
    final rc = FirebaseRemoteConfig.instance;

    try {
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // Zero interval — always fetch fresh values on app start (good for testing).
        // Change back to Duration(hours: 1) before wide release.
        minimumFetchInterval: Duration.zero,
      ));

      await rc.setDefaults(const {
        _kPrimaryColor: _defaultPrimaryColor,
        _kApiBaseUrl: _defaultApiBaseUrl,
        _kAppTitle: _defaultAppTitle,
      });

      await rc.fetchAndActivate();
    } catch (e) {
      // Non-fatal — the app will use the defaults set above.
      debugPrint('RemoteConfig: init/fetch failed, using defaults: $e');
    }

    return RemoteConfigService._(rc);
  }

  // ─── Typed getters ────────────────────────────────────────────────────────

  /// Primary brand color.  Set as "#RRGGBB" or "#AARRGGBB" in the console.
  Color get primaryColor {
    try {
      final raw = _rc.getString(_kPrimaryColor).trim();
      if (raw.startsWith('#')) {
        final hex = raw.substring(1);
        if (hex.length == 6) return Color(int.parse('0xFF$hex'));
        if (hex.length == 8) return Color(int.parse('0x$hex'));
      }
    } catch (_) {}
    return const Color(0xFF3370E5); // unchanged fallback
  }

  /// Backend base URL — change in console to redirect all clients instantly.
  String get apiBaseUrl {
    final v = _rc.getString(_kApiBaseUrl).trim();
    return v.isNotEmpty ? v : _defaultApiBaseUrl;
  }

  /// App name shown in the AppBar / title.
  String get appTitle {
    final v = _rc.getString(_kAppTitle).trim();
    return v.isNotEmpty ? v : _defaultAppTitle;
  }
}
