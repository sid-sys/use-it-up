import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NotifStatus { scheduled, due, test, cancelled }

class NotifEntry {
  final int id;
  final String kind; // reminder | test
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime fireAt;
  bool cancelled;

  NotifEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.fireAt,
    this.cancelled = false,
  });

  NotifStatus get status {
    if (cancelled) return NotifStatus.cancelled;
    if (kind == 'test' && !fireAt.isAfter(DateTime.now())) return NotifStatus.test;
    return fireAt.isAfter(DateTime.now()) ? NotifStatus.scheduled : NotifStatus.due;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'k': kind,
        't': title,
        'b': body,
        'c': createdAt.toIso8601String(),
        'f': fireAt.toIso8601String(),
        'x': cancelled,
      };

  factory NotifEntry.fromJson(Map<String, dynamic> j) => NotifEntry(
        id: j['id'],
        kind: j['k'],
        title: j['t'],
        body: j['b'],
        createdAt: DateTime.parse(j['c']),
        fireAt: DateTime.parse(j['f']),
        cancelled: j['x'] ?? false,
      );
}

/// Every notification this device scheduled or sent. Shown in the admin panel.
class NotificationLog extends ChangeNotifier {
  static final NotificationLog instance = NotificationLog._();
  NotificationLog._();

  final List<NotifEntry> entries = []; // newest first

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('notif_log');
    if (raw != null) {
      entries
        ..clear()
        ..addAll((jsonDecode(raw) as List).map((e) => NotifEntry.fromJson(e)));
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('notif_log', jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  Future<void> add(NotifEntry e) async {
    entries.removeWhere((x) => x.id == e.id && x.kind == 'reminder' && e.kind == 'reminder');
    entries.insert(0, e);
    if (entries.length > 300) entries.removeRange(300, entries.length);
    notifyListeners();
    await _save();
  }

  Future<void> markCancelled(int id) async {
    var changed = false;
    for (final e in entries) {
      if (e.id == id && e.kind == 'reminder' && !e.cancelled) {
        e.cancelled = true;
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      await _save();
    }
  }

  Future<void> clear() async {
    entries.clear();
    notifyListeners();
    await _save();
  }
}
