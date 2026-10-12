import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config.dart';
import '../theme.dart';
import 'models.dart';
import 'widgets.dart';

class UserDetailScreen extends StatelessWidget {
  final AdminUser user;
  const UserDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool isToday(AdminEvent e) => DateTime(e.time.year, e.time.month, e.time.day) == today;
    final todays = user.events.where(isToday).toList();
    final earlier = user.events.where((e) => !isToday(e)).take(25).toList();
    final df = DateFormat('d MMM yyyy');
    return Scaffold(
      appBar: AppBar(title: const Text('USER')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: planColor(user.plan).withValues(alpha: 0.7), borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(radius: 26, backgroundColor: cardWhite, child: Text(initials(user.name), style: body(18, FontWeight.w800))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.name, style: body(18, FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(user.email, style: body(12.5, FontWeight.w400, Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                PlanPill(user.plan),
              ]),
              const SizedBox(height: 14),
              Wrap(spacing: 18, runSpacing: 8, children: [
                _Fact('Country', user.country),
                _Fact('Streak', '${user.streak} days'),
                _Fact('Joined', df.format(user.joinedAt)),
                _Fact('Last seen', timeAgo(user.lastSeen)),
                _Fact('Total actions', '${user.events.length}'),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Journey',
            child: Column(children: [
              _Step(user.onboardingComplete, 'Finished onboarding'),
              _Step(user.addedFirstFood, 'Added first food'),
              _Step(user.reachedPaywall, 'Reached paywall', user.reachedPaywall ? '${user.paywallViews} time${user.paywallViews == 1 ? '' : 's'}' : null),
              _Step(user.triedToPay, 'Tried to pay', user.triedToPay ? '${user.paymentAttempts} attempt${user.paymentAttempts == 1 ? '' : 's'}' : null),
              _Step(
                user.everSubscribed,
                'Subscribed',
                user.subscribedAt == null
                    ? null
                    : '${user.plan == AdminPlan.none ? 'Cancelled later' : planLabel(user.plan)} · ${df.format(user.subscribedAt!)}',
              ),
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
            title: 'Today',
            child: todays.isEmpty
                ? Text('Nothing yet today.', style: body(14, FontWeight.w400, Colors.black54))
                : Column(children: [for (final e in todays) _EventRow(e, timeOnly: true)]),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Earlier activity',
            sub: 'Last ${earlier.length} actions',
            child: earlier.isEmpty
                ? Text('No earlier activity.', style: body(14, FontWeight.w400, Colors.black54))
                : Column(children: [for (final e in earlier) _EventRow(e)]),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final String k;
  final String v;
  const _Fact(this.k, this.v);

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: body(11, FontWeight.w500, Colors.black54)),
        Text(v, style: body(14, FontWeight.w800)),
      ]);
}

class _Step extends StatelessWidget {
  final bool done;
  final String title;
  final String? note;
  const _Step(this.done, this.title, [this.note]);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? const Color(0xFF2E7D32) : Colors.black26),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: body(14.5, FontWeight.w600))),
          if (note != null) Flexible(child: Text(note!, style: body(12, FontWeight.w500, Colors.black54), textAlign: TextAlign.end)),
        ]),
      );
}

class _EventRow extends StatelessWidget {
  final AdminEvent e;
  final bool timeOnly;
  const _EventRow(this.e, {this.timeOnly = false});

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
            if (e.detail.isNotEmpty) Text(e.detail, style: body(12, FontWeight.w400, Colors.black54)),
          ]),
        ),
        const SizedBox(width: 8),
        Text(timeOnly ? DateFormat('h:mm a').format(e.time) : DateFormat('d MMM').format(e.time),
            style: body(12, FontWeight.w500, Colors.black54)),
      ]),
    );
  }
}
