import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedbackEntry {
  final String id;
  final DateTime time;
  final String kind; // Feedback or Bug
  final String text;
  bool handled;
  FeedbackEntry({required this.id, required this.time, required this.kind, required this.text, this.handled = false});

  Map<String, dynamic> toJson() => {'i': id, 't': time.toIso8601String(), 'k': kind, 'x': text, 'h': handled};
  factory FeedbackEntry.fromJson(Map<String, dynamic> j) =>
      FeedbackEntry(id: j['i'], time: DateTime.parse(j['t']), kind: j['k'], text: j['x'], handled: j['h'] ?? false);
}

/// Feedback and bug reports written on this phone. Until a server exists, the same text is also
/// sent to the developer by email, so it really reaches someone.
class FeedbackLog extends ChangeNotifier {
  static final FeedbackLog instance = FeedbackLog._();
  FeedbackLog._();

  final List<FeedbackEntry> entries = [];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('feedback_log');
    if (raw != null) {
      entries
        ..clear()
        ..addAll((jsonDecode(raw) as List).map((e) => FeedbackEntry.fromJson(e)));
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('feedback_log', jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  Future<void> add(String kind, String text) async {
    entries.insert(0, FeedbackEntry(id: DateTime.now().microsecondsSinceEpoch.toString(), time: DateTime.now(), kind: kind, text: text));
    notifyListeners();
    await _save();
  }

  Future<void> setHandled(String id, bool handled) async {
    for (final e in entries) {
      if (e.id == id) e.handled = handled;
    }
    notifyListeners();
    await _save();
  }
}
