import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../admin/dashboard.dart';
import '../auth.dart';
import '../billing.dart';
import '../config.dart';
import '../main.dart';
import '../notifications.dart';
import '../theme.dart';
import 'paywall.dart';

Future<void> openUrl(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the link.')));
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _set(void Function(ReminderPrefs p) change) {
    final p = store.prefs;
    change(p);
    store.setPrefs(p);
  }

  bool get _isAdmin => AppConfig.mock || Auth.email == AppConfig.adminEmail;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, billing, Auth.instance]),
      builder: (context, _) {
        final p = store.prefs;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('PROFILE.', style: display(40)),
            const SizedBox(height: 16),
            Row(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: lime,
                child: Text(Auth.displayName[0].toUpperCase(), style: display(24)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(Auth.displayName, style: body(18, FontWeight.w800)),
                  Text(Auth.email ?? 'Not signed in. Your food stays on this phone.',
                      style: body(13, FontWeight.w400, Colors.black54)),
                ]),
              ),
            ]),
            const SizedBox(height: 20),
            const _PlanCard(),
            const SizedBox(height: 24),
            Text('Reminders', style: body(20, FontWeight.w800)),
            const SizedBox(height: 4),
            Text('These ask you to check the label and the food. Reminders always stay on, even on the free plan.',
                style: body(13, FontWeight.w400, Colors.black54)),
            const SizedBox(height: 8),
            _Box(children: [
              SwitchListTile(
                activeTrackColor: charcoal,
                title: const Text('3 days before'),
                value: p.threeDays,
                onChanged: (v) => _set((x) => x.threeDays = v),
              ),
              SwitchListTile(
                activeTrackColor: charcoal,
                title: const Text('1 day before'),
                value: p.oneDay,
                onChanged: (v) => _set((x) => x.oneDay = v),
              ),
              SwitchListTile(
                activeTrackColor: charcoal,
                title: const Text('On the day'),
                value: p.onDay,
                onChanged: (v) => _set((x) => x.onDay = v),
              ),
              SwitchListTile(
                activeTrackColor: charcoal,
                title: const Text('Weekly overview'),
                subtitle: const Text('Monday morning: how many items to use soon'),
                value: p.weekly,
                onChanged: (v) => _set((x) => x.weekly = v),
              ),
              SwitchListTile(
                activeTrackColor: charcoal,
                title: const Text('Nudge if I am away'),
                subtitle: const Text('After 3 days without opening the app'),
                value: p.reengage,
                onChanged: (v) => _set((x) => x.reengage = v),
              ),
            ]),
            if (!Notifier.supported)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Notifications work in the Android and iPhone apps.',
                    style: body(13, FontWeight.w400, Colors.black54)),
              ),
            const SizedBox(height: 24),
            _Box(children: [
              if (_isAdmin)
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Admin panel'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminDashboard())),
                ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Restore purchases'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => restorePurchasesWithFeedback(context),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => openUrl(context, AppConfig.privacyUrl),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms of Use'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => openUrl(context, AppConfig.termsUrl),
              ),
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Contact us'),
                subtitle: const Text(AppConfig.contactEmail),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => openUrl(context, 'mailto:${AppConfig.contactEmail}'),
              ),
              if (Auth.signedIn)
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  onTap: () => Auth.instance.signOut(),
                ),
              // With an account, deleting means deleting the account too (an App Store rule).
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined, color: redDark),
                title: Text(Auth.signedIn ? 'Delete my account' : 'Delete my data', style: const TextStyle(color: redDark)),
                onTap: () => Auth.signedIn ? _confirmDeleteAccount(context) : _confirmDelete(context),
              ),
            ]),
            const SizedBox(height: 20),
            Center(child: Text('Use It Up 1.0.0 · ${AppConfig.developerName}', style: body(13, FontWeight.w400, Colors.black45))),
          ],
        );
      },
    );
  }

  /// Deletes the cloud account and everything on this phone. Asks the person to confirm
  /// again, because Firebase only deletes an account after a fresh sign-in.
  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final passC = TextEditingController();
    String? error;
    var busy = false;
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Delete your account?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'This deletes your account (${Auth.email ?? 'your account'}) and erases your food, history and settings from this phone. '
              'It cannot be undone. It does not cancel a store subscription: do that in your App Store or Google Play settings.',
            ),
            if (Auth.usesPassword) ...[
              const SizedBox(height: 12),
              TextField(
                controller: passC,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Type your password to confirm'),
              ),
            ] else if (!AppConfig.mock) ...[
              const SizedBox(height: 12),
              const Text('You will be asked to sign in again to confirm it is you.'),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: redDark, fontWeight: FontWeight.w600)),
            ],
          ]),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(c, false), child: const Text('Keep')),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      setD(() {
                        busy = true;
                        error = null;
                      });
                      final err = await Auth.instance.deleteAccount(password: passC.text);
                      if (!c.mounted) return;
                      if (err == null) {
                        Navigator.pop(c, true);
                      } else {
                        setD(() {
                          busy = false;
                          error = err;
                        });
                      }
                    },
              child: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Delete', style: TextStyle(color: redDark)),
            ),
          ],
        ),
      ),
    );
    if (done == true) await store.deleteAllData();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete all your data?'),
        content: const Text('This erases your food, history and settings from this phone. It cannot be undone. '
            'It does not cancel a store subscription.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: redDark))),
        ],
      ),
    );
    if (ok == true) await store.deleteAllData();
  }
}

class _Box extends StatelessWidget {
  final List<Widget> children;
  const _Box({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: cardWhite, borderRadius: BorderRadius.circular(20)),
        child: Column(children: children),
      );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard();

  @override
  Widget build(BuildContext context) {
    // Const widget: it must watch billing itself, or the plan stays stale after Cancel.
    return ListenableBuilder(listenable: billing, builder: (context, _) => _card(context));
  }

  Widget _card(BuildContext context) {
    final f = DateFormat('d MMM yyyy');
    final plan = billing.plan;
    final String sub;
    switch (plan) {
      case PlanKind.free:
        sub = billing.cancelled
            ? 'Premium cancelled. Your food and reminders stay.'
            : '${AppConfig.freeItemLimit} items, ${AppConfig.freeScans} free scans, 7 days of history.';
      case PlanKind.trial:
        sub = '${billing.trialDaysLeft} days left. Then ${billing.chosenPriceText} unless you cancel before ${f.format(billing.trialEnds!)}.';
      case PlanKind.monthly:
      case PlanKind.yearly:
        sub = 'Renews at ${billing.chosenPriceText}.';
      case PlanKind.lifetime:
        sub = 'Paid once. Yours for good.';
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('YOUR PLAN', style: body(12, FontWeight.w700)),
        const SizedBox(height: 4),
        Text(billing.planName.toUpperCase(), style: display(28)),
        const SizedBox(height: 6),
        Text(sub, style: body(14)),
        const SizedBox(height: 14),
        if (plan == PlanKind.free)
          FilledButton(
            style: darkButton(),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PaywallScreen())),
            child: Text(billing.trialUsed ? 'Upgrade to Premium' : 'Try 7 days free'),
          )
        else if (plan != PlanKind.lifetime) ...[
          if (plan == PlanKind.trial || plan == PlanKind.monthly)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FilledButton(
                style: darkButton(),
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PaywallScreen())),
                child: const Text('Change plan'),
              ),
            ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: charcoal,
              side: const BorderSide(color: charcoal),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => _cancel(context),
            child: const Text('Cancel plan'),
          ),
        ],
      ]),
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final storeUrl = defaultTargetPlatform == TargetPlatform.iOS
        ? 'https://apps.apple.com/account/subscriptions'
        : 'https://play.google.com/store/account/subscriptions';
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel Premium?'),
        content: const Text(
            'You keep Premium until the end of the period you paid for. Your saved food and reminders stay. '
            'The store handles billing, so you can also cancel on the store page.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Keep Premium')),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              openUrl(context, storeUrl);
            },
            child: const Text('Open store page'),
          ),
          // Only the stores can end a real subscription. This shortcut is for the demo build.
          if (AppConfig.mock)
            TextButton(
              onPressed: () async {
                await billing.cancel();
                if (c.mounted) Navigator.pop(c);
              },
              child: const Text('Cancel now', style: TextStyle(color: redDark)),
            ),
        ],
      ),
    );
  }
}
