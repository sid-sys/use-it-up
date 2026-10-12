import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../notification_log.dart';
import '../notifications.dart';
import '../theme.dart';
import 'widgets.dart';

/// Every notification this phone scheduled or sent: expiry reminders and admin tests.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NOTIFICATIONS')),
      body: ListenableBuilder(
        listenable: NotificationLog.instance,
        builder: (context, _) {
          final all = NotificationLog.instance.entries;
          final upcoming = all.where((e) => e.status == NotifStatus.scheduled).length;
          final tests = all.where((e) => e.kind == 'test').length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              FilledButton.icon(
                style: limeButton(),
                icon: const Icon(Icons.notifications_active_outlined),
                onPressed: () async {
                  if (!Notifier.supported) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Notifications work in the phone app only.')));
                    return;
                  }
                  await Notifier.sendTest();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Test sent now. Another comes in about 1 minute.')));
                  }
                },
                label: const Text('Send test notification'),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _Count('Logged', '${all.length}', pSky)),
                const SizedBox(width: 10),
                Expanded(child: _Count('Upcoming', '$upcoming', pLime)),
                const SizedBox(width: 10),
                Expanded(child: _Count('Tests', '$tests', pLilac)),
              ]),
              const SizedBox(height: 16),
              if (all.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Nothing logged yet. Add a food, or send a test.', style: body(15), textAlign: TextAlign.center),
                )
              else ...[
                for (final e in all) _Row(e),
                const SizedBox(height: 8),
                TextButton(onPressed: NotificationLog.instance.clear, child: const Text('Clear log')),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Count(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: display(26)),
          Text(label, style: body(12, FontWeight.w600)),
        ]),
      );
}

class _Row extends StatelessWidget {
  final NotifEntry e;
  const _Row(this.e);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (e.status) {
      NotifStatus.scheduled => ('Scheduled', pSky),
      NotifStatus.due => ('Due', pLime),
      NotifStatus.test => ('Test sent', pLilac),
      NotifStatus.cancelled => ('Cancelled', const Color(0xFFE8E8E0)),
    };
    final when = DateFormat('d MMM, h:mm a').format(e.fireAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cardWhite, borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(e.kind == 'test' ? '🧪' : '🔔', style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.kind == 'test' ? e.title : e.body, style: body(14, FontWeight.w700)),
            if (e.kind == 'test') Text(e.body, style: body(12.5, FontWeight.w400, Colors.black54)),
            const SizedBox(height: 2),
            Text(e.kind == 'reminder' ? 'Fires $when' : 'At $when', style: body(12, FontWeight.w500, Colors.black54)),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: body(11, FontWeight.w700)),
        ),
      ]),
    );
  }
}
