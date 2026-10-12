import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

enum PlanKind { free, trial, monthly, yearly }

/// Premium state. Local stand-in for RevenueCat (StoreKit / Google Play Billing).
/// To go live: replace [subscribe], [cancel] and [restore] with purchases_flutter calls.
/// The rest of the app only reads [isPremium], [plan] and the dates below.
class Billing extends ChangeNotifier {
  static const trialDays = AppConfig.trialDays;

  DateTime? _trialStart;
  PlanKind _chosen = PlanKind.yearly; // plan the trial will turn into
  bool _paid = false; // a paid plan is active (mock)
  bool _cancelled = false;

  bool get trialUsed => _trialStart != null;
  bool get trialActive =>
      !_cancelled && !_paid && _trialStart != null && DateTime.now().difference(_trialStart!).inDays < trialDays;
  bool get isPremium => _paid || trialActive;
  int get trialDaysLeft =>
      _trialStart == null ? 0 : (trialDays - DateTime.now().difference(_trialStart!).inDays).clamp(0, trialDays);
  bool get cancelled => _cancelled;

  PlanKind get plan => _paid ? _chosen : (trialActive ? PlanKind.trial : PlanKind.free);

  DateTime? get trialEnds => _trialStart?.add(const Duration(days: trialDays));

  String get planName => switch (plan) {
        PlanKind.free => 'Free',
        PlanKind.trial => 'Premium trial',
        PlanKind.monthly => 'Premium monthly',
        PlanKind.yearly => 'Premium yearly',
      };

  String get chosenPriceText => _chosen == PlanKind.monthly
      ? '${AppConfig.money(AppConfig.monthlyPrice)} per month'
      : '${AppConfig.money(AppConfig.yearlyPrice)} per year';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('trial_start');
    _trialStart = s == null ? null : DateTime.tryParse(s);
    _chosen = p.getString('chosen_plan') == 'monthly' ? PlanKind.monthly : PlanKind.yearly;
    _paid = p.getBool('paid') ?? false;
    _cancelled = p.getBool('cancelled') ?? false;
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    if (_trialStart != null) await p.setString('trial_start', _trialStart!.toIso8601String());
    await p.setString('chosen_plan', _chosen == PlanKind.monthly ? 'monthly' : 'yearly');
    await p.setBool('paid', _paid);
    await p.setBool('cancelled', _cancelled);
  }

  /// Start the free trial (or continue) with the plan the user picked.
  Future<void> subscribe({required bool annual}) async {
    _chosen = annual ? PlanKind.yearly : PlanKind.monthly;
    _cancelled = false;
    if (_trialStart == null) {
      _trialStart = DateTime.now();
    } else {
      _paid = true; // trial already used: a real store would charge now
    }
    await _save();
    notifyListeners();
  }

  /// Cancel. In the real app the stores do this; we send the user to their store page.
  Future<void> cancel() async {
    _cancelled = true;
    _paid = false;
    await _save();
    notifyListeners();
  }

  Future<void> restore() async => load();

  Future<void> reset() async {
    _trialStart = null;
    _paid = false;
    _cancelled = false;
    final p = await SharedPreferences.getInstance();
    await p.remove('trial_start');
    await p.remove('paid');
    await p.remove('cancelled');
    notifyListeners();
  }
}
