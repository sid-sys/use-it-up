import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'notifications.dart';

enum PlanKind { free, trial, monthly, yearly, lifetime }

/// The person closed the store sheet. Not an error: the screen just goes back to normal.
class PurchaseCancelled implements Exception {}

/// Premium state.
///
/// MOCK build: a local stand-in, so the whole flow can be tried without paying.
/// Real build: Apple App Store and Google Play billing through `in_app_purchase`. The store
/// decides who has Premium. This phone asks the store at every launch and can lose Premium
/// if the store says it ended. Nothing is checked on our own server yet; see README.
/// The rest of the app only reads [isPremium], [plan] and the dates below.
class Billing extends ChangeNotifier {
  static const trialDays = AppConfig.trialDays;
  static bool get _storeSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  // ---- mock state ----
  DateTime? _trialStart;
  PlanKind _chosen = PlanKind.yearly; // plan the trial will turn into
  bool _paid = false; // a paid plan is active (mock)
  bool _cancelled = false;

  // ---- real store state (cached on the phone, then confirmed by the store) ----
  bool _entitled = false;
  DateTime? _since;
  bool _withTrial = false;
  bool _trialEver = false;

  bool get trialUsed => AppConfig.mock ? _trialStart != null : _trialEver;
  bool get trialActive => AppConfig.mock
      ? !_cancelled && !_paid && _trialStart != null && DateTime.now().difference(_trialStart!).inDays < trialDays
      : _entitled &&
          _chosen != PlanKind.lifetime &&
          _withTrial &&
          _since != null &&
          DateTime.now().difference(_since!).inDays < trialDays;
  bool get isPremium => AppConfig.mock ? (_paid || trialActive) : _entitled;
  int get trialDaysLeft {
    final start = AppConfig.mock ? _trialStart : _since;
    return start == null ? 0 : (trialDays - DateTime.now().difference(start).inDays).clamp(0, trialDays);
  }

  bool get cancelled => AppConfig.mock && _cancelled;

  PlanKind get plan {
    if (!AppConfig.mock) {
      if (!_entitled) return PlanKind.free;
      return trialActive ? PlanKind.trial : _chosen;
    }
    return _paid ? _chosen : (trialActive ? PlanKind.trial : PlanKind.free);
  }

  DateTime? get trialEnds => (AppConfig.mock ? _trialStart : _since)?.add(const Duration(days: trialDays));

  String get planName => switch (plan) {
        PlanKind.free => 'Free',
        PlanKind.trial => 'Premium trial',
        PlanKind.monthly => 'Premium monthly',
        PlanKind.yearly => 'Premium yearly',
        PlanKind.lifetime => 'Premium lifetime',
      };

  /// True once the store has told us its own prices (they are in local currency).
  bool get storePricesLoaded => _products.isNotEmpty;

  /// Price as the store shows it (local currency). Falls back to the dollar price.
  String priceFor(PlanKind kind) {
    final id = _productId(kind);
    final d = id == null ? null : _pick(id);
    if (d != null) {
      final p = _recurringPrice(d);
      return switch (kind) {
        PlanKind.monthly => '$p / month',
        PlanKind.lifetime => '$p once',
        _ => '$p / year',
      };
    }
    return switch (kind) {
      PlanKind.monthly => '${AppConfig.money(AppConfig.monthlyPrice)} / month',
      PlanKind.lifetime => '${AppConfig.money(AppConfig.lifetimePrice)} once',
      _ => '${AppConfig.money(AppConfig.yearlyPrice)} / year',
    };
  }

  String get chosenPriceText => switch (_chosen) {
        PlanKind.monthly => priceFor(PlanKind.monthly).replaceFirst(' / month', ' per month'),
        PlanKind.lifetime => priceFor(PlanKind.lifetime),
        _ => priceFor(PlanKind.yearly).replaceFirst(' / year', ' per year'),
      };

  // ------------------------------------------------------------------ persistence

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('trial_start');
    _trialStart = s == null ? null : DateTime.tryParse(s);
    final c = p.getString('chosen_plan');
    _chosen = c == 'monthly' ? PlanKind.monthly : (c == 'lifetime' ? PlanKind.lifetime : PlanKind.yearly);
    _paid = p.getBool('paid') ?? false;
    _cancelled = p.getBool('cancelled') ?? false;
    _entitled = p.getBool('store_entitled') ?? false;
    final since = p.getString('store_since');
    _since = since == null ? null : DateTime.tryParse(since);
    _withTrial = p.getBool('store_trial') ?? false;
    _trialEver = p.getBool('store_trial_ever') ?? false;
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    if (_trialStart != null) await p.setString('trial_start', _trialStart!.toIso8601String());
    await p.setString('chosen_plan', _chosen.name);
    await p.setBool('paid', _paid);
    await p.setBool('cancelled', _cancelled);
    await p.setBool('store_entitled', _entitled);
    if (_since != null) await p.setString('store_since', _since!.toIso8601String());
    await p.setBool('store_trial', _withTrial);
    await p.setBool('store_trial_ever', _trialEver);
  }

  // ------------------------------------------------------------------ real store

  // Lazy on purpose: a MOCK build and the tests must never touch the store plugin.
  InAppPurchase get _iap => InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  List<ProductDetails> _products = [];
  bool _storeReady = false;
  Completer<void>? _purchase;
  final Set<String> _seen = {};

  static String? _productId(PlanKind k) => switch (k) {
        PlanKind.monthly => AppConfig.productMonthly,
        PlanKind.yearly => AppConfig.productYearly,
        PlanKind.lifetime => AppConfig.productLifetime,
        _ => null,
      };

  static PlanKind? _kindOf(String id) => switch (id) {
        AppConfig.productMonthly => PlanKind.monthly,
        AppConfig.productYearly => PlanKind.yearly,
        AppConfig.productLifetime => PlanKind.lifetime,
        _ => null,
      };

  /// Google Play lists one entry per offer. Prefer the free-trial offer: Play only lists
  /// it when this person is still allowed a trial.
  ProductDetails? _pick(String id) {
    final list = _products.where((p) => p.id == id).toList();
    if (list.isEmpty) return null;
    for (final p in list) {
      if (_hasFreePhase(p)) return p;
    }
    return list.first;
  }

  static bool _hasFreePhase(ProductDetails p) {
    if (p is! GooglePlayProductDetails || p.subscriptionIndex == null) return false;
    final offers = p.productDetails.subscriptionOfferDetails;
    if (offers == null || p.subscriptionIndex! >= offers.length) return false;
    return offers[p.subscriptionIndex!].pricingPhases.any((ph) => ph.priceAmountMicros == 0);
  }

  /// The price you pay after any free trial.
  static String _recurringPrice(ProductDetails p) {
    if (p is GooglePlayProductDetails && p.subscriptionIndex != null) {
      final offers = p.productDetails.subscriptionOfferDetails;
      if (offers != null && p.subscriptionIndex! < offers.length) {
        final phases = offers[p.subscriptionIndex!].pricingPhases;
        if (phases.isNotEmpty) return phases.last.formattedPrice;
      }
    }
    return p.price;
  }

  /// Call once at start. Does nothing in a MOCK build. Never throws.
  Future<void> initStore() async {
    if (AppConfig.mock || !_storeSupported || _storeReady) return;
    try {
      _sub ??= _iap.purchaseStream.listen(_onPurchases, onError: (_) {});
      _storeReady = await _iap.isAvailable();
      if (!_storeReady) return;
      final r = await _iap.queryProductDetails({
        AppConfig.productMonthly,
        AppConfig.productYearly,
        AppConfig.productLifetime,
      });
      _products = r.productDetails;
      notifyListeners();
      unawaited(_refreshFromStore());
    } catch (e) {
      debugPrint('Store not ready: $e');
    }
  }

  /// Ask the store what this person owns. If it says nothing is active, Premium ends.
  Future<void> _refreshFromStore() async {
    try {
      await _checkStore();
    } catch (e) {
      debugPrint('Could not check purchases: $e'); // keep what we had: we could not ask
    }
  }

  /// Throws if the store does not answer in time.
  Future<void> _checkStore() async {
    _seen.clear();
    await _iap.restorePurchases().timeout(const Duration(seconds: 15));
    // Purchases arrive on the stream. Wait up to 5 seconds, and stop as soon as one arrives.
    for (var i = 0; i < 25 && _seen.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (_seen.isEmpty && _entitled) {
      _entitled = false;
      await _save();
      notifyListeners();
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _seen.add(p.productID);
          await _grant(p);
          _purchase?.complete();
          _purchase = null;
        case PurchaseStatus.canceled:
          _purchase?.completeError(PurchaseCancelled());
          _purchase = null;
        case PurchaseStatus.error:
          _purchase?.completeError(Exception(p.error?.message ?? 'The store reported an error.'));
          _purchase = null;
      }
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (_) {}
      }
    }
  }

  Future<void> _grant(PurchaseDetails p) async {
    final kind = _kindOf(p.productID);
    if (kind == null) return;
    // A lifetime purchase always wins. Otherwise the newest purchase decides.
    if (_entitled && _chosen == PlanKind.lifetime && kind != PlanKind.lifetime) return;
    final ms = int.tryParse(p.transactionDate ?? '');
    final when = ms == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(ms);
    final isNew = !(_entitled && _chosen == kind);
    _entitled = true;
    _chosen = kind;
    if (isNew || _since == null) _since = when;
    if (kind != PlanKind.lifetime) {
      if (p.status == PurchaseStatus.purchased && !_trialEver) {
        _withTrial = true;
        unawaited(Notifier.scheduleTrialReminder(_since ?? DateTime.now(), trialDays));
      }
      _trialEver = true;
    } else {
      unawaited(Notifier.cancelTrialReminder()); // a lifetime purchase has no trial to remind about
    }
    await _save();
    notifyListeners();
  }

  // ------------------------------------------------------------------ actions

  /// Start the free trial (or buy) with the plan the user picked. Lifetime has no trial.
  /// MOCK build: instant. Real build: opens the store's purchase sheet and waits.
  /// Throws [PurchaseCancelled] if the person closes the sheet.
  Future<void> subscribe(PlanKind kind) async {
    if (!AppConfig.mock) return _buy(kind);
    _chosen = kind;
    _cancelled = false;
    if (kind == PlanKind.lifetime) {
      _paid = true; // one-time purchase: a real store charges once, here
    } else if (_trialStart == null) {
      _trialStart = DateTime.now();
      unawaited(Notifier.scheduleTrialReminder(_trialStart!, trialDays));
    } else {
      _paid = true; // trial already used: a real store would charge now
    }
    await _save();
    notifyListeners();
  }

  Future<void> _buy(PlanKind kind) async {
    if (!_storeSupported) throw Exception('Purchases work on iPhone and Android only.');
    if (!_storeReady) {
      await initStore();
      if (!_storeReady) throw Exception('The store is not available right now.');
    }
    final id = _productId(kind);
    final details = id == null ? null : _pick(id);
    if (details == null) throw Exception('This plan is not available in the store yet.');
    final param = PurchaseParam(productDetails: details);
    _purchase = Completer<void>();
    final wait = _purchase!.future;
    bool started;
    try {
      started = await _iap.buyNonConsumable(purchaseParam: param); // subscriptions use the same call
    } catch (e) {
      _purchase = null;
      rethrow;
    }
    if (!started) {
      _purchase = null;
      throw PurchaseCancelled();
    }
    await wait.timeout(const Duration(minutes: 3), onTimeout: () {
      _purchase = null;
      throw Exception('The store is taking long. If you were charged, Premium will switch on by itself.');
    });
  }

  /// Cancel. Only the stores can cancel a subscription, so the real build sends the person
  /// to their store page. This works in a MOCK build only.
  Future<void> cancel() async {
    _cancelled = true;
    _paid = false;
    unawaited(Notifier.cancelTrialReminder());
    await _save();
    notifyListeners();
  }

  /// Check past purchases again. Used by "Restore purchases".
  /// Always answers within about 40 seconds, with a message to show the person.
  Future<String> restore() async {
    if (AppConfig.mock) {
      await load();
      return isPremium ? 'Premium is active on this phone.' : 'No past purchases found.';
    }
    if (!_storeSupported) return 'Purchases work on iPhone and Android only.';
    try {
      if (!_storeReady) await initStore().timeout(const Duration(seconds: 10));
      if (!_storeReady) return 'The store is not available right now. Please try again later.';
      await _checkStore().timeout(const Duration(seconds: 25));
    } on TimeoutException {
      return 'The store did not answer. Check your internet and try again.';
    } catch (_) {
      return 'Could not check your purchases. Please try again.';
    }
    return _entitled ? 'Premium restored. Welcome back!' : 'No active purchase found for this store account.';
  }

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

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
