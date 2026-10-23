import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../analytics.dart';
import '../theme.dart';
import 'models.dart';

// The admin panel uses the app's own colours: lime for actions and highlights, charcoal for text,
// ivory for the page and white for cards. Text colours below all pass 4.5:1 on their background.
const muted = Color(0xFF55574F); // secondary text. About 7:1 on white and 6:1 on ivory.
const barLime = Color(0xFFC6F23C);
const gain = Color(0xFF1B6B2F); // "Net gain"
const loss = Color(0xFFB3261E); // "Net loss"
const paleLime = Color(0xFFEAFBB5);
const quietGrey = Color(0xFFE8E8E0);

// Old names, kept so other screens keep working.
const pLime = paleLime;
const pPeach = Color(0xFFFFE3D1);
const pLilac = Color(0xFFE6DFFF);
const pSky = Color(0xFFD8EEFF);
const pMint = Color(0xFFD5F5E3);
const pPink = Color(0xFFFFDCE6);

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 30) return '${d.inDays}d ago';
  return DateFormat('d MMM').format(t);
}

String initials(String name) {
  final n = name.trim();
  if (n.isEmpty) return '?';
  if (n.startsWith('Guest ')) return 'G';
  if (n.contains('@')) return n[0].toUpperCase();
  final p = n.split(' ').where((s) => s.isNotEmpty).toList();
  return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
}

String planLabel(AdminPlan p) => switch (p) {
      AdminPlan.none => 'Free',
      AdminPlan.monthly => 'Monthly',
      AdminPlan.yearly => 'Yearly',
      AdminPlan.lifetime => 'Lifetime',
    };

Color planColor(AdminPlan p) => switch (p) {
      AdminPlan.none => quietGrey,
      AdminPlan.monthly => paleLime,
      AdminPlan.yearly => lime,
      AdminPlan.lifetime => charcoal,
    };

Color planText(AdminPlan p) => p == AdminPlan.lifetime ? lime : charcoal;

(String, String) eventLook(String type) => switch (type) {
      Ev.opened => ('👋', 'Opened the app'),
      Ev.onboardingStarted => ('🚀', 'Started onboarding'),
      Ev.signedUp => ('🔑', 'Signed up'),
      Ev.heardFrom => ('📣', 'Told us where they heard about us'),
      Ev.answered => ('📝', 'Answered the questions'),
      Ev.notifAllowed => ('🔔', 'Allowed reminders'),
      Ev.onboardingDone => ('✅', 'Finished onboarding'),
      Ev.foodAdded => ('🥛', 'Added food'),
      Ev.scanUsed => ('📷', 'Scanned a label'),
      Ev.foodUsed => ('🍽️', 'Marked food as used'),
      Ev.paywallView => ('💎', 'Saw the paywall'),
      Ev.paymentAttempt => ('💳', 'Tried to pay'),
      Ev.payFailed => ('⚠️', 'Payment did not happen'),
      Ev.subscribed => ('🎉', 'Subscribed'),
      Ev.feedbackSent => ('💬', 'Sent feedback'),
      _ => ('•', type),
    };

const problemLabels = {
  'forget_fridge': "I forget what's in my fridge",
  'expires_first': 'Food expires before I use it',
  'buy_more': 'I buy more than I need',
  'leftovers': 'Leftovers get forgotten',
  'everything': 'A bit of everything',
};
const householdLabels = {
  'just_me': 'Just me',
  'two': '2 people',
  'three_four': '3–4 people',
  'five_plus': '5+ people',
};
const remindLabels = {'three': '3 days before', 'one': '1 day before', 'both': '3 days and 1 day before'};

class PlanPill extends StatelessWidget {
  final AdminPlan plan;
  const PlanPill(this.plan, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: planColor(plan), borderRadius: BorderRadius.circular(20)),
        child: Text(planLabel(plan), style: body(12, FontWeight.w700, planText(plan))),
      );
}

/// A small label such as "Guest" or "Test purchase".
class Tag extends StatelessWidget {
  final String text;
  final Color? color;
  final Color textColor;
  const Tag(this.text, {super.key, this.color, this.textColor = charcoal});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color ?? quietGrey, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: body(11, FontWeight.w700, textColor)),
      );
}

class UserAvatar extends StatelessWidget {
  final AdminUser user;
  final double radius;
  const UserAvatar(this.user, {super.key, this.radius = 20});

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: planColor(user.plan) == charcoal ? charcoal : planColor(user.plan),
        child: Text(initials(user.displayName), style: body(radius * 0.7, FontWeight.w800, planText(user.plan))),
      );
}

/// A number card. It is a button when [onTap] is given.
class MetricCard extends StatelessWidget {
  final bool highlight; // lime card
  final IconData icon;
  final String title;
  final String value;
  final String sub;
  final VoidCallback? onTap;
  const MetricCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.sub,
    this.highlight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight ? lime : cardWhite,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: highlight ? cardWhite : lime, shape: BoxShape.circle),
                child: Icon(icon, size: 17, color: charcoal),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: body(13, FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
            const Spacer(),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: display(32))),
            const SizedBox(height: 4),
            Text(sub, style: body(11.5, FontWeight.w500, highlight ? charcoal : muted), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final String? sub;
  final Widget? trailing;
  const SectionCard({super.key, required this.title, required this.child, this.sub, this.trailing});

  @override
  // A Material (not a coloured box), so taps inside it show their ripple.
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: Material(
          color: cardWhite,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(title, style: body(17, FontWeight.w800))),
                ?trailing,
              ]),
              if (sub != null) Text(sub!, style: body(12, FontWeight.w400, muted)),
              const SizedBox(height: 14),
              child,
            ]),
          ),
        ),
      );
}

/// One step of the funnel. Tap to see who reached it.
class FunnelRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final bool biggestDrop;
  final VoidCallback? onTap;
  const FunnelRow({super.key, required this.label, required this.count, required this.total, this.biggestDrop = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label, style: body(13.5, FontWeight.w600))),
            if (biggestDrop) ...[const Tag('Most leave here', color: lime), const SizedBox(width: 8)],
            Text('$count · ${(pct * 100).round()}%', style: body(13, FontWeight.w800)),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(children: [
              Container(height: 10, color: ivory),
              FractionallySizedBox(
                widthFactor: pct.clamp(0.0, 1.0),
                child: Container(height: 10, decoration: BoxDecoration(color: barLime, border: Border.all(color: charcoal, width: 1))),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A bar with a label and a count. Tap to see the people.
class BarRow extends StatelessWidget {
  final String label;
  final int count;
  final int max;
  final VoidCallback? onTap;
  const BarRow({super.key, required this.label, required this.count, required this.max, this.onTap});

  @override
  Widget build(BuildContext context) {
    final frac = max == 0 ? 0.0 : count / max;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: count == 0 ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label, style: body(13.5, FontWeight.w600))),
            Text('$count', style: body(13, FontWeight.w800)),
            if (count > 0 && onTap != null) const Icon(Icons.chevron_right, size: 18),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(children: [
              Container(height: 10, color: ivory),
              FractionallySizedBox(
                widthFactor: frac.clamp(0.0, 1.0),
                child: Container(height: 10, decoration: BoxDecoration(color: barLime, border: Border.all(color: charcoal, width: 1))),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
