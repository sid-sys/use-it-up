import 'package:flutter/material.dart';
import '../analytics.dart';
import '../config.dart';
import '../main.dart';
import '../theme.dart';
import 'profile.dart' show openUrl;

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
  bool _annual = true;
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
  /// Live build: call the store purchase sheet here (RevenueCat) and only then mark Premium.
  Future<void> _buy() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      Analytics.instance.log(Ev.paymentAttempt, _annual ? 'yearly' : 'monthly');
      final trial = !billing.trialUsed;
      await billing.subscribe(annual: _annual);
      Analytics.instance.log(Ev.subscribed, '${trial ? 'trial ' : ''}${_annual ? 'yearly' : 'monthly'}');
      if (!mounted) return;
      if (widget.onClose == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Premium is on. Enjoy!')));
      }
      _close();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'The purchase did not go through. You have not been charged. Please try again.';
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
            final price = _annual
                ? '${AppConfig.money(AppConfig.yearlyPrice)} / year'
                : '${AppConfig.money(AppConfig.monthlyPrice)} / month';
            return Column(children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: _close),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    Text('WASTE LESS.\nSTRESS LESS.', style: display(44)),
                    const SizedBox(height: 10),
                    if (widget.reason != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(widget.reason!, style: body(15, FontWeight.w700)),
                      ),
                    Text('Let Use It Up do the remembering for you.', style: body(17)),
                    const SizedBox(height: 20),
                    const _Feature('AI expiry scanning', 'Add food from a photo.'),
                    const _Feature('Unlimited food tracking', 'Keep your entire fridge organized.'),
                    const _Feature('Personalized reminders', 'Know what needs attention.'),
                    if (canTrial) _Feature('${AppConfig.trialDays}-day free trial', 'Try Premium before you pay.'),
                    const SizedBox(height: 14),
                    _Plan(
                      selected: _annual,
                      title: 'Premium',
                      price: '${AppConfig.money(AppConfig.yearlyPrice)} / year',
                      sub: 'About ${AppConfig.money(AppConfig.yearlyPrice / 12)} a month',
                      badge: 'BEST VALUE',
                      onTap: () => setState(() => _annual = true),
                    ),
                    const SizedBox(height: 10),
                    _Plan(
                      selected: !_annual,
                      title: 'Monthly',
                      price: '${AppConfig.money(AppConfig.monthlyPrice)} / month',
                      sub: 'Cancel any time',
                      onTap: () => setState(() => _annual = false),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      canTrial
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
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(children: [
                  FilledButton(
                    style: limeButton(),
                    onPressed: _busy ? null : _buy,
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: charcoal))
                        : Text(_error != null ? 'Try again' : (canTrial ? 'Start free trial' : 'Subscribe')),
                  ),
                  const SizedBox(height: 4),
                  TextButton(onPressed: _busy ? null : _close, child: Text('Maybe later', style: body(15.5, FontWeight.w700))),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    TextButton(
                        onPressed: () async {
                          await billing.restore();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(content: Text('Checked for past purchases.')));
                          }
                        },
                        child: const Text('Restore purchases')),
                    const Text('·'),
                    TextButton(onPressed: () => openUrl(context, AppConfig.termsUrl), child: const Text('Terms')),
                    const Text('·'),
                    TextButton(onPressed: () => openUrl(context, AppConfig.privacyUrl), child: const Text('Privacy')),
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

class _Feature extends StatelessWidget {
  final String title;
  final String sub;
  const _Feature(this.title, this.sub);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(color: lime, shape: BoxShape.circle),
          child: const Icon(Icons.check, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: body(16, FontWeight.w700)),
            Text(sub, style: body(14, FontWeight.w400, Colors.black54)),
          ]),
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
        padding: const EdgeInsets.all(16),
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
              Text(sub, style: body(13)),
            ]),
          ),
          Text(price, style: body(15, FontWeight.w800)),
        ]),
      ),
    );
  }
}
