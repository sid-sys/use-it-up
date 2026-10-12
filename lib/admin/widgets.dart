import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../analytics.dart';
import '../theme.dart';
import 'models.dart';

// Pastel card colors.
const pLime = Color(0xFFEAFBB5);
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
  final p = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
}

String planLabel(AdminPlan p) => switch (p) {
      AdminPlan.none => 'Free',
      AdminPlan.monthly => 'Monthly',
      AdminPlan.yearly => 'Yearly',
      AdminPlan.lifetime => 'Lifetime',
    };

Color planColor(AdminPlan p) => switch (p) {
      AdminPlan.none => const Color(0xFFE8E8E0),
      AdminPlan.monthly => pSky,
      AdminPlan.yearly => pLime,
      AdminPlan.lifetime => pLilac,
    };

(String, String) eventLook(String type) => switch (type) {
      Ev.opened => ('👋', 'Opened the app'),
      Ev.onboardingDone => ('✅', 'Finished onboarding'),
      Ev.foodAdded => ('🥛', 'Added food'),
      Ev.scanUsed => ('📷', 'Scanned a label'),
      Ev.foodUsed => ('🍽️', 'Marked food as used'),
      Ev.paywallView => ('💎', 'Saw the paywall'),
      Ev.paymentAttempt => ('💳', 'Tried to pay'),
      Ev.subscribed => ('🎉', 'Subscribed'),
      _ => ('•', type),
    };

class PlanPill extends StatelessWidget {
  final AdminPlan plan;
  const PlanPill(this.plan, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: planColor(plan), borderRadius: BorderRadius.circular(20)),
        child: Text(planLabel(plan), style: body(12, FontWeight.w700)),
      );
}

class MockTag extends StatelessWidget {
  const MockTag({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: charcoal, borderRadius: BorderRadius.circular(6)),
        child: Text('MOCK DATA', style: body(10, FontWeight.w800, lime)),
      );
}

class MetricCard extends StatelessWidget {
  final Color color;
  final String emoji;
  final String title;
  final String value;
  final String sub;
  const MetricCard({super.key, required this.color, required this.emoji, required this.title, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: body(13, FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis)),
          Text(emoji, style: const TextStyle(fontSize: 18)),
        ]),
        const Spacer(),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: display(32))),
        const SizedBox(height: 4),
        Text(sub, style: body(11.5, FontWeight.w500, Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final String? sub;
  const SectionCard({super.key, required this.title, required this.child, this.sub});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cardWhite, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: body(17, FontWeight.w800)),
          if (sub != null) Text(sub!, style: body(12, FontWeight.w400, Colors.black54)),
          const SizedBox(height: 14),
          child,
        ]),
      );
}

/// Last 14 days. Count above each bar. Today is dark.
class DauChart extends StatelessWidget {
  final List<int> values;
  const DauChart({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<int>(1, (a, b) => b > a ? b : a);
    final today = DateTime.now();
    const chartH = 110.0;
    return SizedBox(
      height: chartH + 40,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('${values[i]}', style: body(10, i == values.length - 1 ? FontWeight.w800 : FontWeight.w500)),
                const SizedBox(height: 2),
                Container(
                  height: (values[i] / maxV * chartH).clamp(3.0, chartH),
                  decoration: BoxDecoration(
                    color: i == values.length - 1 ? charcoal : const Color(0xFFBFE04A),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(height: 4),
                Text('${today.subtract(Duration(days: values.length - 1 - i)).day}',
                    style: body(10, FontWeight.w500, Colors.black54)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class FunnelRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  const FunnelRow({super.key, required this.label, required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: body(13.5, FontWeight.w600))),
          Text('$count · ${(pct * 100).round()}%', style: body(13, FontWeight.w800)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(children: [
            Container(height: 10, color: ivory),
            FractionallySizedBox(widthFactor: pct.clamp(0.0, 1.0), child: Container(height: 10, color: const Color(0xFFBFE04A))),
          ]),
        ),
      ]),
    );
  }
}
