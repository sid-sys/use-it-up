import 'package:flutter/material.dart';
import '../main.dart';
import '../theme.dart';
import 'paywall.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(30)),
                child: Text('USE IT UP', style: body(13, FontWeight.w700)),
              ),
              const SizedBox(height: 20),
              Text('STOP FORGETTING\nFOOD IN THE\nFRIDGE.', style: display(52)),
              const SizedBox(height: 20),
              Text('Add food in seconds. Get a nudge before its date. Waste less.', style: body(18)),
              const SizedBox(height: 28),
              const _Point(Icons.photo_camera_outlined, 'Snap the date', 'Take a photo. Check it. Save.'),
              const _Point(Icons.edit_outlined, 'Or just type it', 'Name and date. That is all.'),
              const _Point(Icons.notifications_none, 'Get a reminder', 'We ask you to check before it is too late.'),
              const Spacer(flex: 2),
              FilledButton(
                style: limeButton(),
                onPressed: () => store.finishOnboarding(),
                child: const Text('Get started'),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () async {
                    await store.finishOnboarding();
                    if (context.mounted) {
                      Navigator.of(context).push(MaterialPageRoute(
                          fullscreenDialog: true, builder: (_) => const PaywallScreen()));
                    }
                  },
                  child: Text('See Premium (7 days free)', style: body(15, FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  const _Point(this.icon, this.title, this.sub);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        CircleAvatar(backgroundColor: cardWhite, child: Icon(icon, color: charcoal)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: body(16, FontWeight.w700)),
            Text(sub, style: body(14)),
          ]),
        ),
      ]),
    );
  }
}
