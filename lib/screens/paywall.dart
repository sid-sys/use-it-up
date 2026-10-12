import 'package:flutter/material.dart';
import '../analytics.dart';
import '../config.dart';
import '../main.dart';
import '../theme.dart';

class PaywallScreen extends StatefulWidget {
  final String? reason;
  const PaywallScreen({super.key, this.reason});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _annual = true;

  @override
  void initState() {
    super.initState();
    Analytics.instance.log(Ev.paywallView, widget.reason ?? "opened");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: billing,
          builder: (context, _) {
            final canTrial = !billing.trialUsed;
            return Column(children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(30)),
                        child: Text('USE IT UP PREMIUM', style: body(13, FontWeight.w700)),
                      ),
                    ),
                    Text('YOUR FOOD\nDESERVES A\nSECOND CHANCE.', style: display(44)),
                    const SizedBox(height: 10),
                    if (widget.reason != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(widget.reason!, style: body(15, FontWeight.w700)),
                      ),
                    Text('Waste less. Remember everything. Spend smarter.', style: body(17)),
                    const SizedBox(height: 20),
                    const _Feature('AI expiry scanning', '100 photo scans a month. Check and edit every date.'),
                    const _Feature('Unlimited food items', 'Free is up to 20 items at a time.'),
                    const _Feature('Smarter reminders', 'Choose when you get nudged.'),
                    const _Feature('Full history', 'Free keeps the last 7 days.'),
                    const SizedBox(height: 16),
                    _Plan(
                      selected: _annual,
                      title: 'Annual',
                      price: '${AppConfig.money(AppConfig.yearlyPrice)}/year',
                      sub: 'About ${AppConfig.money(AppConfig.yearlyPrice / 12)} a month${canTrial ? '. 7 days free' : ''}',
                      badge: 'BEST VALUE',
                      onTap: () => setState(() => _annual = true),
                    ),
                    const SizedBox(height: 10),
                    _Plan(
                      selected: !_annual,
                      title: 'Monthly',
                      price: '${AppConfig.money(AppConfig.monthlyPrice)}/month',
                      sub: 'Cancel any time',
                      onTap: () => setState(() => _annual = false),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      canTrial && _annual
                          ? '₹0 today, then ${AppConfig.money(AppConfig.yearlyPrice)} per year after the 7-day trial unless you cancel. Final price and terms are shown by the store.'
                          : 'Renews automatically at ${_annual ? '${AppConfig.money(AppConfig.yearlyPrice)} per year' : '${AppConfig.money(AppConfig.monthlyPrice)} per month'} unless you cancel in your store account settings.',
                      style: body(12.5, FontWeight.w400, Colors.black54),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(children: [
                  FilledButton(
                    style: limeButton(),
                    onPressed: () async {
                      // Replace with a RevenueCat purchase call for live billing.
                      Analytics.instance.log(Ev.paymentAttempt, _annual ? "yearly" : "monthly");
                      await billing.subscribe(annual: _annual);
                      Analytics.instance.log(Ev.subscribed, (canTrial ? "trial " : "") + (_annual ? "yearly" : "monthly"));
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Premium is on. Enjoy your 7 days.')));
                      }
                    },
                    child: Text(canTrial ? 'Start my 7-day free trial' : 'Continue'),
                  ),
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
                    TextButton(onPressed: () {}, child: const Text('Terms')),
                    const Text('·'),
                    TextButton(onPressed: () {}, child: const Text('Privacy')),
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
              Row(children: [
                Text(title, style: body(17, FontWeight.w800)),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: charcoal, borderRadius: BorderRadius.circular(8)),
                    child: Text(badge!, style: body(10, FontWeight.w700, Colors.white)),
                  ),
                ],
              ]),
              Text(sub, style: body(13)),
            ]),
          ),
          Text(price, style: body(16, FontWeight.w800)),
        ]),
      ),
    );
  }
}
