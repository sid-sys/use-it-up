import '../analytics.dart';
import '../config.dart';
import 'admin_config.dart';

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

/// A payment that did not happen. [reason] is cancelled, failed or store_unavailable.
class AdminPayFailure {
  final DateTime time;
  final String reason;
  final String detail;
  const AdminPayFailure(this.time, this.reason, this.detail);
}

/// One record per phone, however many accounts use it. Written by the server only.
class AdminDevice {
  final String installId;
  final String ownerId; // the account that last logged in on this phone
  final DateTime installedAt; // the install time Android itself reports
  final DateTime lastSeen;
  final DateTime? uninstalledAt; // set only when Google says the push address is gone
  const AdminDevice({
    required this.installId,
    required this.ownerId,
    required this.installedAt,
    required this.lastSeen,
    this.uninstalledAt,
  });
  bool get uninstalled => uninstalledAt != null;
}

class AdminFeedback {
  final String id;
  final String name;
  final String kind; // Feedback or Bug
  final String text;
  final DateTime time;
  bool handled;
  AdminFeedback({required this.id, required this.name, required this.kind, required this.text, required this.time, this.handled = false});
}

/// Where people say they heard about the app. Same keys as the onboarding question.
const heardLabels = {
  'tiktok': 'TikTok',
  'instagram': 'Instagram',
  'youtube': 'YouTube',
  'facebook': 'Facebook',
  'store': 'App Store or Play Store',
  'google': 'Google search',
  'friend': 'A friend or family',
  'other': 'Somewhere else',
};

/// The steps people go through, in order, for THIS app. Each is an event the app records.
/// "Installed" is every account's phone, so it has no event.
const funnelSteps = <(String label, String? event)>[
  ('Installed the app', null),
  ('Opened the app', Ev.opened),
  ('Started onboarding', Ev.onboardingStarted),
  ('Signed up or chose guest', Ev.signedUp),
  ('Answered the questions', Ev.answered),
  ('Allowed reminders', Ev.notifAllowed),
  ('Added the first food', Ev.foodAdded),
  ('Saw the paywall', Ev.paywallView),
  ('Tried to pay', Ev.paymentAttempt),
  ('Subscribed', Ev.subscribed),
];

class JourneyStep {
  final String label;
  final DateTime? time;
  const JourneyStep(this.label, this.time);
  bool get done => time != null;
}

class AdminUser {
  final String id;
  final String name; // empty for a guest
  final String email; // empty for a guest
  final String country;
  final DateTime joinedAt;
  final DateTime lastSeen;
  final bool isGuest;
  final int paywallViews;
  final int paymentAttempts;
  final AdminPlan plan; // none = free or churned
  final DateTime? subscribedAt;
  final List<AdminPayment> payments;
  final List<AdminPayFailure> failures;
  final List<AdminEvent> events; // newest first
  final int streak;
  final bool testPurchase; // the store says this was a license-tester purchase
  final int? onboardingSeconds; // how long the welcome tour took
  final String? heardFrom; // key in [heardLabels]
  final Map<String, String> answers; // what they told us in onboarding

  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.country,
    required this.joinedAt,
    required this.lastSeen,
    required this.isGuest,
    required this.paywallViews,
    required this.paymentAttempts,
    required this.plan,
    required this.subscribedAt,
    required this.payments,
    required this.events,
    required this.streak,
    this.failures = const [],
    this.testPurchase = false,
    this.onboardingSeconds,
    this.heardFrom,
    this.answers = const {},
  });

  /// The real name. If there is none, the real email. If there is neither (a guest), "Guest" and the
  /// first 6 characters of the account id. A name is NEVER made up.
  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    if (email.trim().isNotEmpty) return email.trim();
    return 'Guest ${id.length > 6 ? id.substring(0, 6) : id}';
  }

  /// The line under the name: the real email, or what is missing.
  String get subtitleLine {
    if (name.trim().isNotEmpty) return email.trim().isEmpty ? 'No email' : email.trim();
    if (email.trim().isNotEmpty) return 'No name given';
    return 'No name, no email';
  }
  bool get everSubscribed => subscribedAt != null;
  double get paidTotal => payments.fold(0.0, (a, p) => a + p.amount);
  String? get hiddenReason => AdminConfig.hiddenReason(this);

  bool activeOn(DateTime day) => lastSeen.year == day.year && lastSeen.month == day.month && lastSeen.day == day.day;

  /// The first time this event happened, or null.
  DateTime? firstOf(String type) {
    DateTime? t;
    for (final e in events) {
      if (e.type == type && (t == null || e.time.isBefore(t))) t = e.time;
    }
    return t;
  }

  bool paidWithin(DateTime since) => payments.any((p) => p.time.isAfter(since));

  List<JourneyStep> get journey => [
        for (final (label, event) in funnelSteps) JourneyStep(label, event == null ? joinedAt : firstOf(event)),
      ];
}

/// Everything the admin screens need. The repository fills it, the screens never ask a database.
class AdminData {
  final List<AdminUser> users;
  final List<AdminDevice> devices;
  final List<AdminFeedback> feedback;

  /// False until a server exists: then only this phone is shown and the screens say so.
  final bool serverConnected;
  const AdminData({required this.users, required this.devices, required this.feedback, required this.serverConnected});
}

/// One day on the "Active users" bars: who opened the app.
class DayActive {
  final DateTime day;
  final List<AdminUser> users;
  const DayActive(this.day, this.users);
}

/// One day on the installs chart.
class DayInstalls {
  final DateTime day;
  final List<AdminUser> installed;
  final List<AdminUser> uninstalled;
  const DayInstalls(this.day, this.installed, this.uninstalled);
  int get net => installed.length - uninstalled.length;
  String get netWords => net > 0 ? 'Net gain +$net' : (net < 0 ? 'Net loss $net' : 'No change');
}

class FunnelRowData {
  final String label;
  final int count;
  final List<AdminUser> users;
  const FunnelRowData(this.label, this.count, this.users);
}

/// Numbers for the dashboard. Costs come from [AppConfig].
/// Built from the users that are SHOWN, so the "Real users only" switch changes every number.
class AdminStats {
  final List<AdminUser> users; // the ones shown
  final int newThisWeek;
  final List<AdminUser> subscribed;
  final int payingNow; // monthly + yearly
  final int lifetime;
  final List<AdminUser> activeToday;
  final int activeWeek;
  final List<AdminUser> paidLast30;
  final double revenueTotal;
  final double revenue30;
  final int aiRequests30;
  final double aiCost30;
  final double fixedCost30;
  final double profitBefore;
  final double profitAfter;
  final List<DayActive> active30; // oldest first, last item is today
  final List<DayInstalls> installs30; // oldest first
  final List<FunnelRowData> funnel;
  final int biggestDropIndex; // the step where most people leave, or -1
  final Map<String, List<AdminUser>> payProblems; // cancelled, failed, store_unavailable
  final Map<String, List<AdminUser>> sources; // key in heardLabels, or 'none'

  AdminStats._({
    required this.users,
    required this.newThisWeek,
    required this.subscribed,
    required this.payingNow,
    required this.lifetime,
    required this.activeToday,
    required this.activeWeek,
    required this.paidLast30,
    required this.revenueTotal,
    required this.revenue30,
    required this.aiRequests30,
    required this.aiCost30,
    required this.fixedCost30,
    required this.profitBefore,
    required this.profitAfter,
    required this.active30,
    required this.installs30,
    required this.funnel,
    required this.biggestDropIndex,
    required this.payProblems,
    required this.sources,
  });

  int get totalUsers => users.length;
  double get costs30 => aiCost30 + fixedCost30;
  double get subscribedPct => users.isEmpty ? 0 : subscribed.length * 100 / users.length;

  static const payProblemLabels = {
    'cancelled': 'Closed the payment window',
    'failed': 'Payment failed',
    'store_unavailable': 'Store not available',
  };

  factory AdminStats.from(List<AdminUser> users, List<AdminDevice> devices, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = now.subtract(const Duration(days: 30));
    final byId = {for (final u in users) u.id: u};
    DateTime day(DateTime t) => DateTime(t.year, t.month, t.day);

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

    final active = <DayActive>[];
    for (var i = 29; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      active.add(DayActive(d, users.where((u) => u.events.any((e) => day(e.time) == d)).toList()));
    }

    // Installs and uninstalls: one record per phone. Only phones whose owner is shown.
    final installs = <DayInstalls>[];
    for (var i = 29; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final inst = <AdminUser>[];
      final uninst = <AdminUser>[];
      for (final dev in devices) {
        final owner = byId[dev.ownerId];
        if (owner == null) continue;
        if (day(dev.installedAt) == d) inst.add(owner);
        if (dev.uninstalledAt != null && day(dev.uninstalledAt!) == d) uninst.add(owner);
      }
      installs.add(DayInstalls(d, inst, uninst));
    }

    final funnel = <FunnelRowData>[];
    for (final (label, event) in funnelSteps) {
      final list = event == null ? List<AdminUser>.of(users) : users.where((u) => u.firstOf(event) != null).toList();
      funnel.add(FunnelRowData(label, list.length, list));
    }
    var worst = -1;
    var worstLoss = 0;
    for (var i = 1; i < funnel.length; i++) {
      final loss = funnel[i - 1].count - funnel[i].count;
      if (loss > worstLoss) {
        worstLoss = loss;
        worst = i;
      }
    }

    final problems = <String, List<AdminUser>>{for (final k in payProblemLabels.keys) k: []};
    for (final u in users) {
      for (final reason in u.failures.map((f) => f.reason).toSet()) {
        problems[reason]?.add(u);
      }
    }

    final sources = <String, List<AdminUser>>{for (final k in heardLabels.keys) k: [], 'none': []};
    for (final u in users) {
      sources[heardLabels.containsKey(u.heardFrom) ? u.heardFrom! : 'none']!.add(u);
    }

    return AdminStats._(
      users: users,
      newThisWeek: users.where((u) => u.joinedAt.isAfter(weekAgo)).length,
      subscribed: users.where((u) => u.plan != AdminPlan.none).toList(),
      payingNow: users.where((u) => u.plan == AdminPlan.monthly || u.plan == AdminPlan.yearly).length,
      lifetime: users.where((u) => u.plan == AdminPlan.lifetime).length,
      activeToday: users.where((u) => u.activeOn(today)).toList(),
      activeWeek: users.where((u) => u.lastSeen.isAfter(weekAgo)).length,
      paidLast30: users.where((u) => u.paidWithin(monthAgo)).toList(),
      revenueTotal: revTotal,
      revenue30: rev30,
      aiRequests30: ai30,
      aiCost30: aiCost,
      fixedCost30: fixed,
      profitBefore: rev30 - aiCost - fixed,
      profitAfter: rev30 * (1 - AppConfig.storeCut) - aiCost - fixed,
      active30: active,
      installs30: installs,
      funnel: funnel,
      biggestDropIndex: worst,
      payProblems: problems,
      sources: sources,
    );
  }
}
