import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'analytics.dart';
import 'billing.dart';
import 'config.dart';
import 'models.dart';
import 'notification_log.dart';
import 'notifications.dart';

class Store extends ChangeNotifier {
  final Billing billing;
  Store(this.billing);

  final List<FoodItem> _items = [];
  ReminderPrefs prefs = ReminderPrefs();
  int _freeScansUsed = 0;
  int _monthScans = 0;
  String _scanMonth = '';
  bool onboarded = false;
  bool loaded = false;

  List<FoodItem> _sorted(Iterable<FoodItem> l) => l.toList()..sort((a, b) => a.expiry.compareTo(b.expiry));

  /// Not used and not past its date.
  List<FoodItem> get fresh => _sorted(_items.where((i) => !i.used && i.daysLeft() >= 0));

  /// Not used and past its date. Shown in the Expired tab.
  List<FoodItem> get expired => _sorted(_items.where((i) => i.isExpired)).reversed.toList();

  List<FoodItem> get usedItems {
    final list = _items.where((i) => i.used).toList()
      ..sort((a, b) => (b.usedAt ?? b.addedAt).compareTo(a.usedAt ?? a.addedAt));
    if (billing.isPremium) return list;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return list.where((i) => (i.usedAt ?? i.addedAt).isAfter(cutoff)).toList();
  }

  List<FoodItem> get activeAll => _items.where((i) => !i.used).toList();
  int get usedCount => _items.where((i) => i.used).length;
  bool get atItemLimit => !billing.isPremium && fresh.length >= AppConfig.freeItemLimit;

  bool get canScan => billing.isPremium
      ? _monthScans < AppConfig.premiumScansPerMonth
      : _freeScansUsed < AppConfig.freeScans;
  int get scansLeft => billing.isPremium
      ? AppConfig.premiumScansPerMonth - _monthScans
      : AppConfig.freeScans - _freeScansUsed;

  String _monthKey() => DateTime.now().toIso8601String().substring(0, 7);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('items');
    if (raw != null) {
      _items
        ..clear()
        ..addAll((jsonDecode(raw) as List).map((e) => FoodItem.fromJson(e)));
    }
    prefs = ReminderPrefs(
      threeDays: p.getBool('r3') ?? true,
      oneDay: p.getBool('r1') ?? true,
      onDay: p.getBool('r0') ?? true,
      weekly: p.getBool('rw2') ?? true,
      reengage: p.getBool('rg') ?? true,
    );
    _freeScansUsed = p.getInt('free_scans') ?? 0;
    _monthScans = p.getInt('month_scans') ?? 0;
    _scanMonth = p.getString('scan_month') ?? _monthKey();
    if (_scanMonth != _monthKey()) {
      _scanMonth = _monthKey();
      _monthScans = 0;
    }
    onboarded = p.getBool('onboarded') ?? false;
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('items', jsonEncode(_items.map((e) => e.toJson()).toList()));
    await p.setInt('free_scans', _freeScansUsed);
    await p.setInt('month_scans', _monthScans);
    await p.setString('scan_month', _scanMonth);
    await p.setBool('onboarded', onboarded);
    await p.setBool('r3', prefs.threeDays);
    await p.setBool('r1', prefs.oneDay);
    await p.setBool('r0', prefs.onDay);
    await p.setBool('rw2', prefs.weekly);
    await p.setBool('rg', prefs.reengage);
  }

  /// Re-plans the weekly overview and the inactivity nudge. Call when the app opens
  /// and after any change to the food list or reminder settings.
  Future<void> refreshGeneralReminders() => Notifier.refreshGeneral(activeAll, prefs);

  Future<void> finishOnboarding() async {
    onboarded = true;
    await _save();
    notifyListeners();
    Analytics.instance.log(Ev.onboardingDone);
  }

  Future<void> recordScan() async {
    if (billing.isPremium) {
      _monthScans++;
    } else {
      _freeScansUsed++;
    }
    await _save();
    notifyListeners();
    Analytics.instance.log(Ev.scanUsed);
  }

  Future<void> add(FoodItem i) async {
    final first = _items.isEmpty;
    _items.add(i);
    await _save();
    notifyListeners();
    Analytics.instance.log(Ev.foodAdded, i.name);
    if (first) await Notifier.requestPermission();
    await Notifier.scheduleFor(i, prefs);
    await refreshGeneralReminders();
  }

  Future<void> update(FoodItem i) async {
    await _save();
    notifyListeners();
    await Notifier.scheduleFor(i, prefs);
    await refreshGeneralReminders();
  }

  Future<void> markUsed(FoodItem i) async {
    i.used = true;
    i.usedAt = DateTime.now();
    await _save();
    notifyListeners();
    Analytics.instance.log(Ev.foodUsed, i.name);
    await Notifier.cancelFor(i);
    await refreshGeneralReminders();
  }

  Future<void> restoreItem(FoodItem i) async {
    i.used = false;
    i.usedAt = null;
    await _save();
    notifyListeners();
    await Notifier.scheduleFor(i, prefs);
    await refreshGeneralReminders();
  }

  Future<void> delete(FoodItem i) async {
    _items.remove(i);
    await _save();
    notifyListeners();
    await Notifier.cancelFor(i);
    await refreshGeneralReminders();
  }

  Future<void> setPrefs(ReminderPrefs p) async {
    prefs = p;
    await _save();
    notifyListeners();
    await Notifier.rescheduleAll(activeAll, prefs);
    await refreshGeneralReminders();
  }

  /// Erase everything saved on this device.
  Future<void> deleteAllData() async {
    await Notifier.cancelAll();
    await NotificationLog.instance.clear();
    _items.clear();
    _freeScansUsed = 0;
    _monthScans = 0;
    onboarded = false;
    final p = await SharedPreferences.getInstance();
    await p.clear();
    await billing.reset();
    Analytics.instance.events.clear();
    notifyListeners();
  }
}
