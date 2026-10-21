import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config.dart';
import '../theme.dart';
import 'models.dart';
import 'widgets.dart';

class UserDetailScreen extends StatelessWidget {
  final AdminUser user;
  final AdminDevice? device;
  const UserDetailScreen({super.key, required this.user, this.device});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy');
    final hidden = user.hiddenReason;
    final steps = user.journey;
    final told = <(String, String)>[
      for (final e in user.answers.entries) (e.key, _pretty(e.key, e.value)),
      if (user.heardFrom != null) ('Where they heard about us', heardLabels[user.heardFrom] ?? user.heardFrom!),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('USER')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: paleLime, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                UserAvatar(user, radius: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.displayName, style: body(18, FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(user.subtitleLine, style: body(12.5, FontWeight.w400, muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                PlanPill(user.plan),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [
                Tag(user.isGuest ? 'Guest' : 'Signed up', color: cardWhite),
                if (user.testPurchase) const Tag('Test purchase', color: cardWhite),
                if (device?.uninstalled ?? false) Tag('Uninstalled ${df.format(device!.uninstalledAt!)}', color: cardWhite),
                if (hidden != null) Tag('Hidden from the numbers: $hidden', color: charcoal, textColor: Colors.white),
              ]),
              const SizedBox(height: 14),
              Wrap(spacing: 18, runSpacing: 8, children: [
                _Fact('Country', user.country),
                _Fact('Joined', df.format(user.joinedAt)),
                _Fact('Last seen', timeAgo(user.lastSeen)),
                _Fact('Streak', '${user.streak} days'),
                _Fact('Total actions', '${user.events.length}'),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Journey',
            sub: 'Each step, with the time it first happened',
            child: Column(children: [
              for (var i = 0; i < steps.length; i++) _TimelineStep(step: steps[i], last: i == steps.length - 1),
              const Divider(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Paid so far: ${AppConfig.money(user.paidTotal)} in ${user.payments.length} payment${user.payments.length == 1 ? '' : 's'}',
                  style: body(14, FontWeight.w800),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'What they told us',
            child: told.isEmpty
                ? Text('They skipped the questions.', style: body(14, FontWeight.w400, muted))
                : Column(children: [
                    for (final (k, v) in told)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(flex: 4, child: Text(k, style: body(13, FontWeight.w500, muted))),
                          Expanded(flex: 5, child: Text(v, style: body(14, FontWeight.w700), textAlign: TextAlign.end)),
                        ]),
                      ),
                  ]),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Activity',
            sub: user.events.length > 40 ? 'Newest 40 of ${user.events.length}' : 'Newest first',
            child: user.events.isEmpty
                ? Text('No activity yet.', style: body(14, FontWeight.w400, muted))
                : Column(children: [for (final e in user.events.take(40)) _EventRow(e)]),
          ),
        ],
      ),
    );
  }

  static String _pretty(String key, String value) {
    final map = switch (key) {
      'What usually gets forgotten' => problemLabels,
      'People shopping for' => householdLabels,
      'Reminders' => remindLabels,
      _ => const <String, String>{},
    };
    return map[value] ?? value;
  }
}

class _Fact extends StatelessWidget {
  final String k;
  final String v;
  const _Fact(this.k, this.v);

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: body(11, FontWeight.w500, muted)),
        Text(v, style: body(14, FontWeight.w800)),
      ]);
}

/// A vertical timeline: a tick for a step they did, an empty circle for one they did not.
class _TimelineStep extends StatelessWidget {
  final JourneyStep step;
  final bool last;
  const _TimelineStep({required this.step, required this.last});

  @override
  Widget build(BuildContext context) {
    final done = step.done;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 30,
          child: Column(children: [
            Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, size: 22, color: done ? gain : muted),
            if (!last) Expanded(child: Container(width: 2, color: done ? gain.withValues(alpha: .35) : quietGrey)),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Expanded(child: Text(step.label, style: body(14.5, done ? FontWeight.w700 : FontWeight.w500, done ? charcoal : muted))),
              Text(done ? DateFormat('d MMM, h:mm a').format(step.time!) : 'Not yet', style: body(12, FontWeight.w500, muted)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _EventRow extends StatelessWidget {
  final AdminEvent e;
  const _EventRow(this.e);

  @override
  Widget build(BuildContext context) {
    final (emoji, title) = eventLook(e.type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: body(14, FontWeight.w700)),
            if (e.detail.isNotEmpty) Text(e.detail, style: body(12, FontWeight.w400, muted)),
          ]),
        ),
        const SizedBox(width: 8),
        Text(DateFormat('d MMM, h:mm a').format(e.time), style: body(12, FontWeight.w500, muted)),
      ]),
    );
  }
}
