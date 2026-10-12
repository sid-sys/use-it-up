import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Event names. Real data later uses the same names under Firestore users/{uid}/events.
class Ev {
  static const opened = 'opened';
  static const onboardingDone = 'onboarding_done';
  static const foodAdded = 'food_added'; // key step: first food added
  static const scanUsed = 'scan_used'; // main feature
  static const foodUsed = 'food_marked_used';
  static const paywallView = 'paywall_view';
  static const paymentAttempt = 'payment_attempt';
  static const subscribed = 'subscribed';
}

class LoggedEvent {
  final DateTime time;
  final String type;
  final String detail;
  LoggedEvent(this.time, this.type, this.detail);

  Map<String, dynamic> toJson() => {'t': time.toIso8601String(), 'y': type, 'd': detail};
  factory LoggedEvent.fromJson(Map<String, dynamic> j) =>
      LoggedEvent(DateTime.parse(j['t']), j['y'], j['d'] ?? '');
}

/// Stores events on this device only. Newest first, capped at 500.
/// Later: also send each one to Firestore under users/{uid}/events.
class Analytics extends ChangeNotifier {
  static final Analytics instance = Analytics._();
  Analytics._();

  final List<LoggedEvent> events = [];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('events');
    if (raw != null) {
      events
        ..clear()
        ..addAll((jsonDecode(raw) as List).map((e) => LoggedEvent.fromJson(e)));
    }
  }

  Future<void> log(String type, [String detail = '']) async {
    events.insert(0, LoggedEvent(DateTime.now(), type, detail));
    if (events.length > 500) events.removeRange(500, events.length);
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('events', jsonEncode(events.map((e) => e.toJson()).toList()));
  }

  int count(String type) => events.where((e) => e.type == type).length;
}
