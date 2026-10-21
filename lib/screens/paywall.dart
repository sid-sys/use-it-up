import 'package:flutter/material.dart';
import '../analytics.dart';
import '../billing.dart';
import '../config.dart';
import '../main.dart';
import '../theme.dart';
import '../toast.dart';
import 'profile.dart' show openUrl;
import 'trial_reminder.dart';

/// Soft paywall. Always dismissible. X and "Maybe later" do the same thing.
/// [onClose] lets the onboarding flow take over closing; otherwise the screen just pops.
class PaywallScreen extends StatefulWidget {
  final String? reason;
  final bool fromOnboarding;
  final VoidCallback? onClose;
  const PaywallScreen({super.key, this.reason, this.fromOnboarding = false, this.onClose});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  PlanKind _plan = PlanKind.yearly;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Analytics.instance.log(Ev.paywallView, widget.reason ?? (widget.fromOnboarding ? 'onboarding' : 'opened'));
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Nothing is charged until the store confirms the purchase.
  /// A real build opens the App Store or Google Play sheet here, and marks Premium only after it confirms.
  Future<void> _buy() async {
    // A plan with a free trial first shows "we'll remind you before your trial ends".
    if (!billing.trialUsed && _plan != PlanKind.lifetime) {
      final go = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => TrialReminderScreen(plan: _plan)));
      if (go != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      Analytics.instance.log(Ev.paymentAttempt, _plan.name);
      final trial = !billing.trialUsed && _plan != PlanKind.lifetime;
      await billing.subscribe(_plan);
      Analytics.instance.log(Ev.subscribed, '${trial ? 'trial ' : ''}${_plan.name}');
      if (!mounted) return;
      if (widget.onClose == null) {
        toast('Premium is on. Enjoy!');
      }
      _close();
    } on PurchaseCancelled {
      Analytics.instance.log(Ev.payFailed, 'cancelled');
      if (mounted) setState(() => _busy = false); // closed the store sheet: not an error
    } catch (e) {
      final text = e.toString();
      Analytics.instance.log(Ev.payFailed, text.contains('not available') || text.contains('Purchases work') ? 'store_unavailable' : 'failed');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = AppConfig.mock
              ? 'The purchase did not go through. You have not been charged. Please try again.'
              : 'The purchase did not go through. ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: billing,
          builder: (context, _) {
            final canTrial = !billing.trialUsed;
            final lifetime = _plan == PlanKind.lifetime;
            final trialApplies = canTrial && !lifetime;
            final price = billing.priceFor(_plan);
            return Column(children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: _close),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    Text('WASTE LESS.\nSTRESS LESS.', style: display(38)),
                    const SizedBox(height: 6),
                    if (widget.reason != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(widget.reason!, style: body(15, FontWeight.w700)),
                      ),
                    Text('Let Use It Up do the remembering for you.', style: body(14)),
                    const SizedBox(height: 10),
                    const _Feature('AI expiry scanning'),
                    const _Feature('Unlimited food tracking'),
                    const _Feature('Personalized reminders'),
                    if (canTrial) _Feature('${AppConfig.trialDays}-day free trial'),
                    const SizedBox(height: 8),
                    _Plan(
                      selected: _plan == PlanKind.yearly,
                      title: 'Yearly',
                      price: billing.priceFor(PlanKind.yearly),
                      sub: billing.storePricesLoaded
                          ? 'Billed once a year'
                          : 'About ${AppConfig.money(double.parse((AppConfig.yearlyPrice / 12).toStringAsFixed(2)))} a month',
                      badge: 'SAVE ${AppConfig.yearlySavingsPct}%',
                      onTap: () => setState(() => _plan = PlanKind.yearly),
                    ),
                    const SizedBox(height: 8),
                    _Plan(
                      selected: _plan == PlanKind.monthly,
                      title: 'Monthly',
                      price: billing.priceFor(PlanKind.monthly),
                      sub: 'Cancel any time',
                      onTap: () => setState(() => _plan = PlanKind.monthly),
                    ),
                    const SizedBox(height: 8),
                    _Plan(
                      selected: lifetime,
                      title: 'Lifetime',
                      price: billing.priceFor(PlanKind.lifetime),
                      sub: 'Pay once. Keep it.',
                      onTap: () => setState(() => _plan = PlanKind.lifetime),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      lifetime
                          ? 'One-time payment of $price. No renewal. The store shows the final price.'
                          : trialApplies
                              ? '${AppConfig.money(0)} today, then $price after your ${AppConfig.trialDays}-day trial. Cancel before renewal to avoid the charge.'
                              : 'Renews automatically at $price unless you cancel in your store account settings. The store shows the final price.',
                      style: body(12.5, FontWeight.w400, Colors.black54),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: cardWhite, borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: redDark),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_error!, style: body(13.5))),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 14),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
                child: Column(children: [
                  FilledButton(
                    style: limeButton(),
                    onPressed: _busy ? null : _buy,
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: charcoal))
                        : Text(_error != null ? 'Try again' : (lifetime ? 'Buy lifetime' : (canTrial ? 'Start ${AppConfig.trialDays}-day free trial' : 'Subscribe'))),
                  ),
                  const SizedBox(height: 4),
                  TextButton(onPressed: _busy ? null : _close, child: Text('Maybe later', style: body(15.5, FontWeight.w700))),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    TextButton(
                        onPressed: _busy ? null : () => restorePurchasesWithFeedback(context),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact, textStyle: body(13)),
                        child: const Text('Restore purchases')),
                    const Text('·'),
                    TextButton(onPressed: () => openUrl(context, AppConfig.termsUrl), style: TextButton.styleFrom(visualDensity: VisualDensity.compact, textStyle: body(13)), child: const Text('Terms')),
                    const Text('·'),
                    TextButton(onPressed: () => openUrl(context, AppConfig.privacyUrl), style: TextButton.styleFrom(visualDensity: VisualDensity.compact, textStyle: body(13)), child: const Text('Privacy')),
                  ]),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

/// "Restore purchases": shows a progress box, then tells the person what happened.
/// It can never hang: the billing code gives up after a short time and says so.
Future<void> restorePurchasesWithFeedback(BuildContext context) async {
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
          SizedBox(width: 18),
          Expanded(child: Text('Checking your purchases...')),
        ]),
      ),
    ),
  );
  String message;
  try {
    message = await billing.restore();
  } catch (_) {
    message = 'Could not check your purchases. Please try again.';
  }
  nav.pop();
  toast(message);
}

class _Feature extends StatelessWidget {
  final String title;
  const _Feature(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 1),
          decoration: const BoxDecoration(color: lime, shape: BoxShape.circle),
          child: const Icon(Icons.check, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: title, style: body(15, FontWeight.w700)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Plan extends StatelessWidget {
  final bool selected;
  final String title;
  final String price;
  final String sub;
  final String? badge;
  final VoidCallback onTap;
  const _Plan({required this.selected, required this.title, required this.price, required this.sub, this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? lime.withValues(alpha: 0.45) : cardWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? charcoal : Colors.transparent, width: 2),
        ),
        child: Row(children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(title, style: body(17, FontWeight.w800)),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: charcoal, borderRadius: BorderRadius.circular(8)),
                    child: Text(badge!, style: body(10, FontWeight.w700, Colors.white)),
                  ),
              ]),
              Text(sub, style: body(12.5)),
            ]),
          ),
          Text(price, style: body(15, FontWeight.w800)),
        ]),
      ),
    );
  }
}
