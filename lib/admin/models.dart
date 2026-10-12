import '../analytics.dart';
import '../config.dart';

enum AdminPlan { none, monthly, yearly, lifetime }

class AdminEvent {
  final DateTime time;
  final String type; // see Ev in analytics.dart
  final String detail;
  const AdminEvent(this.time, this.type, this.detail);
}

class AdminPayment {
  final DateTime time;
  final double amount;
  const AdminPayment(this.time, this.amount);
}

class AdminUser {
  final String id;
  final String name;
  final String email;
  final String country;
  final DateTime joinedAt;
  final DateTime lastSeen;
  final bool onboardingComplete;
  final bool addedFirstFood; // key step of this app
  final int paywallViews;
  final int paymentAttempts;
  final AdminPlan plan; // none = free or churned
  final DateTime? subscribedAt;
  final List<AdminPayment> payments;
  final List<AdminEvent> events; // newest first
  final int streak;

  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.country,
    required this.joinedAt,
    required this.lastSeen,
    required this.onboardingComplete,
    required this.addedFirstFood,
    required this.paywallViews,
    required this.paymentAttempts,
    required this.plan,
    required this.subscribedAt,
    required this.payments,
    required this.events,
    required this.streak,
  });

  bool get everSubscribed => subscribedAt != null;
  bool get reachedPaywall => paywallViews > 0;
  bool get triedToPay => paymentAttempts > 0;
  double get paidTotal => payments.fold(0.0, (a, p) => a + p.amount);

  bool activeOn(DateTime day) => lastSeen.year == day.year && lastSeen.month == day.month && lastSeen.day == day.day;
}

/// Computed from the users list. Costs come from [AppConfig].
class AdminStats {
  final int totalUsers;
  final int newThisWeek;
  final int subscribed; // plan is not none
  final int payingNow; // monthly + yearly
  final int lifetime;
  final int activeToday;
  final int activeWeek;
  final double revenueTotal;
  final double revenue30;
  final int aiRequests30;
  final double aiCost30;
  final double fixedCost30;
  final double profitBefore; // revenue minus costs, before store cut
  final double profitAfter; // after the store cut
  final List<int> dau14; // oldest first, last item is today
  final List<int> funnel; // joined, onboarding, first food, paywall, tried to pay, subscribed

  AdminStats._({
    required this.totalUsers,
    required this.newThisWeek,
    required this.subscribed,
    required this.payingNow,
    required this.lifetime,
    required this.activeToday,
    required this.activeWeek,
    required this.revenueTotal,
    required this.revenue30,
    required this.aiRequests30,
    required this.aiCost30,
    required this.fixedCost30,
    required this.profitBefore,
    required this.profitAfter,
    required this.dau14,
    required this.funnel,
  });

  double get costs30 => aiCost30 + fixedCost30;
  double get subscribedPct => totalUsers == 0 ? 0 : subscribed * 100 / totalUsers;

  factory AdminStats.from(List<AdminUser> users, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = now.subtract(const Duration(days: 30));

    var revTotal = 0.0, rev30 = 0.0, ai30 = 0;
    for (final u in users) {
      for (final p in u.payments) {
        revTotal += p.amount;
        if (p.time.isAfter(monthAgo)) rev30 += p.amount;
      }
      ai30 += u.events.where((e) => e.type == Ev.scanUsed && e.time.isAfter(monthAgo)).length;
    }
    final aiCost = ai30 * AppConfig.aiCostPerRequest;
    const fixed = AppConfig.fixedMonthlyCosts;

    final dau = List<int>.filled(14, 0);
    for (var i = 0; i < 14; i++) {
      final d = today.subtract(Duration(days: 13 - i));
      dau[i] = users.where((u) => u.events.any((e) => DateTime(e.time.year, e.time.month, e.time.day) == d)).length;
    }

    return AdminStats._(
      totalUsers: users.length,
      newThisWeek: users.where((u) => u.joinedAt.isAfter(weekAgo)).length,
      subscribed: users.where((u) => u.plan != AdminPlan.none).length,
      payingNow: users.where((u) => u.plan == AdminPlan.monthly || u.plan == AdminPlan.yearly).length,
      lifetime: users.where((u) => u.plan == AdminPlan.lifetime).length,
      activeToday: users.where((u) => u.activeOn(today)).length,
      activeWeek: users.where((u) => u.lastSeen.isAfter(weekAgo)).length,
      revenueTotal: revTotal,
      revenue30: rev30,
      aiRequests30: ai30,
      aiCost30: aiCost,
      fixedCost30: fixed,
      profitBefore: rev30 - aiCost - fixed,
      profitAfter: rev30 * (1 - AppConfig.storeCut) - aiCost - fixed,
      dau14: dau,
      funnel: [
        users.length,
        users.where((u) => u.onboardingComplete).length,
        users.where((u) => u.addedFirstFood).length,
        users.where((u) => u.reachedPaywall).length,
        users.where((u) => u.triedToPay).length,
        users.where((u) => u.everSubscribed).length,
      ],
    );
  }
}
