import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'analytics.dart';

/// Where this install came from, on Android.
///
/// Google Play remembers the link a person used to install the app. A link can carry a "referrer" such as
/// utm_source=instagram&utm_campaign=launch. The old way to read it, a broadcast receiver, was switched off by
/// Google in March 2020. The current way is the Play Install Referrer library, used here through a small
/// piece of Android code (MainActivity.kt).
///
/// A person who finds the app by searching in Google Play has no link. Google then answers
/// utm_source=google-play&utm_medium=organic.
class InstallInfo {
  /// The raw text Google Play gives, for example utm_source=instagram&utm_medium=bio&utm_campaign=launch.
  final String? referrer;
  final DateTime? firstInstallTime; // the install time Android itself reports
  final DateTime? clickTime; // when the link was tapped
  final String? installer; // for example com.android.vending (Google Play)
  final int? error; // Play Install Referrer error code, when Google could not answer

  const InstallInfo({this.referrer, this.firstInstallTime, this.clickTime, this.installer, this.error});

  /// The parts of the referrer link: utm_source, utm_medium, utm_campaign...
  Map<String, String> get utm {
    final r = referrer;
    if (r == null || r.trim().isEmpty) return const {};
    try {
      return Uri.splitQueryString(r);
    } catch (_) {
      return const {};
    }
  }

  String? get source => utm['utm_source'];
  String? get medium => utm['utm_medium'];
  String? get campaign => utm['utm_campaign'];

  /// "google-play / organic", "instagram / bio / launch", or null when nothing is known.
  String? get label {
    final parts = [source, medium, campaign].whereType<String>().where((s) => s.isNotEmpty && s != '(not set)').toList();
    return parts.isEmpty ? null : parts.join(' / ');
  }

  /// True when the person installed from Google Play (not from a file or another store).
  bool get fromGooglePlay => installer == 'com.android.vending';

  Map<String, dynamic> toJson() => {
        'r': referrer,
        'f': firstInstallTime?.toIso8601String(),
        'c': clickTime?.toIso8601String(),
        'i': installer,
        'e': error,
      };

  factory InstallInfo.fromJson(Map<String, dynamic> j) => InstallInfo(
        referrer: j['r'] as String?,
        firstInstallTime: j['f'] == null ? null : DateTime.tryParse(j['f'] as String),
        clickTime: j['c'] == null ? null : DateTime.tryParse(j['c'] as String),
        installer: j['i'] as String?,
        error: j['e'] as int?,
      );

  /// Builds the info from what the Android code returns.
  factory InstallInfo.fromChannel(Map<dynamic, dynamic> m) {
    DateTime? ms(Object? v) => v is int && v > 0 ? DateTime.fromMillisecondsSinceEpoch(v) : null;
    DateTime? sec(Object? v) => v is int && v > 0 ? DateTime.fromMillisecondsSinceEpoch(v * 1000) : null;
    return InstallInfo(
      referrer: m['referrer'] as String?,
      firstInstallTime: ms(m['firstInstallTime']),
      clickTime: sec(m['clickSeconds']),
      installer: m['installer'] as String?,
      error: m['referrerError'] as int?,
    );
  }

  // ------------------------------------------------------------------ reading it

  static const _channel = MethodChannel('useitup/install');
  static const _prefsKey = 'install_info';
  static InstallInfo? _cached;

  /// What we know about this install, or null if it has not been read yet (or this is not Android).
  static InstallInfo? get current => _cached;

  /// Reads the install info once, the first time the app opens, and remembers it on this phone.
  /// Never throws and never waits more than a few seconds. A phone that is not Android returns null.
  static Future<InstallInfo?> collect() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final p = await SharedPreferences.getInstance();
    final saved = p.getString(_prefsKey);
    if (saved != null) {
      try {
        return _cached = InstallInfo.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      } catch (_) {
        // read it again below
      }
    }
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('getInstallInfo').timeout(const Duration(seconds: 8));
      if (raw == null) return null;
      final info = InstallInfo.fromChannel(raw);
      // Google answers once per install. Only keep an answer that is final, so a failed try is repeated next time.
      final isFinal = info.error == null || info.error == 2; // 2 = this phone has no Play referrer feature
      if (isFinal) await p.setString(_prefsKey, jsonEncode(info.toJson()));
      if (info.label != null) Analytics.instance.log(Ev.installSource, info.label!);
      return _cached = info;
    } catch (e) {
      debugPrint('Could not read the install source: $e');
      return null;
    }
  }
}
