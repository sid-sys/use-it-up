import 'dart:math';
import '../analytics.dart';
import '../auth.dart';
import '../billing.dart';
import '../config.dart';
import '../feedback_log.dart';
import '../main.dart' show billing, store;
import 'admin_config.dart';
import 'models.dart';

/// Every admin screen reads data ONLY through this. A Firestore version can replace
/// [MockAdminRepository] and [LocalAdminRepository] without touching any screen.
///
/// SECURITY: a real version MUST check on the server that the caller is an admin
/// (see firestore.rules). Hiding the button in the app is not security.
abstract class AdminRepository {
  Future<AdminData> load();
}

AdminRepository createAdminRepository() => AppConfig.mock ? MockAdminRepository() : LocalAdminRepository();

/// Real build, before a backend exists: shows only this phone, as one user.
/// Nothing is invented. The screens say that no server is connected.
class LocalAdminRepository implements AdminRepository {
  @override
  Future<AdminData> load() async {
    final ev = Analytics.instance.events;
    final now = DateTime.now();
    final events = [for (final e in ev) AdminEvent(e.time, e.type, e.detail)];
    final first = events.isEmpty ? now : events.last.time;
    final last = events.isEmpty ? now : events.first.time;
    final plan = switch (billing.plan) {
      PlanKind.monthly => AdminPlan.monthly,
      PlanKind.yearly => AdminPlan.yearly,
      PlanKind.lifetime => AdminPlan.lifetime,
      _ => AdminPlan.none,
    };
    final failures = [
      for (final e in events.where((e) => e.type == Ev.payFailed)) AdminPayFailure(e.time, e.detail, ''),
    ];
    final signedIn = Auth.signedIn;
    final user = AdminUser(
      id: 'this-phone',
      name: signedIn ? Auth.displayName : '',
      email: Auth.email ?? '',
      country: '-',
      joinedAt: first,
      lastSeen: last,
      isGuest: !signedIn,
      paywallViews: events.where((e) => e.type == Ev.paywallView).length,
      paymentAttempts: events.where((e) => e.type == Ev.paymentAttempt).length,
      plan: plan,
      subscribedAt: events.where((e) => e.type == Ev.subscribed).map((e) => e.time).fold<DateTime?>(null, (a, b) => a ?? b),
      payments: const [],
      failures: failures,
      events: events,
      streak: 0,
      heardFrom: store.heardFrom,
      answers: {
        if (store.problem != null) 'What usually gets forgotten': store.problem!,
        if (store.household != null) 'People shopping for': store.household!,
        'Reminders': store.remindWhen,
      },
    );
    final feedback = [
      for (final f in FeedbackLog.instance.entries)
        AdminFeedback(id: f.id, name: user.displayName, kind: f.kind, text: f.text, time: f.time, handled: f.handled),
    ];
    return AdminData(
      users: [user],
      devices: [AdminDevice(installId: 'this-phone', ownerId: user.id, installedAt: first, lastSeen: last)],
      feedback: feedback,
      serverConnected: false,
    );
  }
}

/// About 60 believable accounts: 50 real people and 10 that "Real users only" hides.
/// Fixed seed, so the numbers are the same on every run.
class MockAdminRepository implements AdminRepository {
  static const _first = ['Aarav', 'Diya', 'Vihaan', 'Anaya', 'Arjun', 'Isha', 'Kabir', 'Meera', 'Rohan', 'Saanvi',
    'Ishaan', 'Kavya', 'Neil', 'Priya', 'Rahul', 'Sara', 'Tanvi', 'Yash', 'Zoya', 'Aditya', 'Nisha', 'Dev', 'Riya',
    'Karan', 'Ananya'];
  static const _last = ['Sharma', 'Nair', 'Iyer', 'Patel', 'Khan', 'Reddy', 'Menon', 'Das', 'Gupta', 'Joseph'];
  static const _countries = ['India', 'India', 'India', 'India', 'India', 'UAE', 'UK', 'USA', 'Canada', 'Australia'];
  static const _foods = ['Milk', 'Yogurt', 'Bread', 'Spinach', 'Eggs', 'Cheese', 'Chicken', 'Tomatoes', 'Butter',
    'Paneer', 'Mango juice', 'Rice', 'Carrots', 'Soup'];
  static const _providers = ['google', 'google', 'apple', 'email'];
  static const _problems = ['forget_fridge', 'expires_first', 'buy_more', 'leftovers', 'everything'];
  static const _households = ['just_me', 'two', 'three_four', 'five_plus'];
  static const _sourceWeights = <(String, double)>[
    ('friend', .28), ('social', .24), ('store', .18), ('youtube', .1), ('google', .1), ('other', .1),
  ];
  static const _feedbackTexts = [
    ('Feedback', 'Love the Eat me first cards. Could I add a barcode scan?'),
    ('Bug', 'The date was read as 12 Nov but the label says 11 Dec.'),
    ('Feedback', 'Please add a dark mode.'),
    ('Bug', 'Reminder came a day late on my phone.'),
    ('Feedback', 'Simple and clear. Thank you!'),
    ('Feedback', 'Can I share my fridge with my partner?'),
  ];

  @override
  Future<AdminData> load() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return build(DateTime.now());
  }

  String _pickSource(Random r) {
    var x = r.nextDouble();
    for (final (k, w) in _sourceWeights) {
      if (x < w) return k;
      x -= w;
    }
    return 'other';
  }

  AdminData build(DateTime now) {
    final r = Random(42);
    final midnight = DateTime(now.year, now.month, now.day);
    final minutesToday = max(1, now.difference(midnight).inMinutes);
    final users = <AdminUser>[];
    final devices = <AdminDevice>[];

    for (var i = 0; i < 50; i++) {
      final guest = r.nextDouble() < 0.3;
      final name = '${_first[r.nextInt(_first.length)]} ${_last[r.nextInt(_last.length)]}';
      final email = '${name.toLowerCase().replaceAll(' ', '.')}${r.nextInt(90)}@example.com';
      final joined = now.subtract(Duration(days: 1 + r.nextInt(44), hours: r.nextInt(20), minutes: r.nextInt(60)));
      final daysSince = max(1, now.difference(joined).inDays);

      // Each step is a smaller group than the one before it.
      final started = r.nextDouble() < 0.97;
      final signed = started && r.nextDouble() < 0.96;
      final answered = signed && r.nextDouble() < 0.9;
      final notif = answered && r.nextDouble() < 0.75;
      final addedFood = notif && r.nextDouble() < 0.9;
      final paywallViews = addedFood && r.nextDouble() < 0.55 ? 1 + r.nextInt(3) : 0;
      final attempts = paywallViews > 0 && r.nextDouble() < 0.5 ? 1 + r.nextInt(2) : 0;
      final subscribed = attempts > 0 && r.nextDouble() < 0.65;
      final tour = answered ? 40 + r.nextInt(180) : null;
      final heard = answered && r.nextDouble() < 0.85 ? _pickSource(r) : null;
      final provider = guest ? 'guest' : _providers[r.nextInt(_providers.length)];

      var plan = AdminPlan.none;
      DateTime? subAt;
      final payments = <AdminPayment>[];
      if (subscribed) {
        final p = r.nextDouble();
        final kind = p < 0.45 ? AdminPlan.monthly : (p < 0.85 ? AdminPlan.yearly : AdminPlan.lifetime);
        final hoursSinceJoin = max(6, now.difference(joined).inHours);
        subAt = joined.add(Duration(hours: 4 + r.nextInt(hoursSinceJoin - 4)));
        plan = kind;
        if (kind == AdminPlan.monthly) {
          final possible = (now.difference(subAt).inDays ~/ 30) + 1;
          final paid = r.nextDouble() < 0.35 ? 1 + r.nextInt(possible) : possible; // some churn
          for (var k = 0; k < paid; k++) {
            payments.add(AdminPayment(subAt.add(Duration(days: 30 * k)), AppConfig.monthlyPrice));
          }
          if (paid < possible) plan = AdminPlan.none; // churned
        } else if (kind == AdminPlan.yearly) {
          payments.add(AdminPayment(subAt, AppConfig.yearlyPrice));
        } else {
          payments.add(AdminPayment(subAt, AppConfig.lifetimePrice));
        }
      }
      final isSub = plan != AdminPlan.none;

      final events = <AdminEvent>[];
      void add(DateTime t, String type, [String detail = '']) {
        if (t.isAfter(now)) t = now.subtract(Duration(minutes: r.nextInt(30)));
        events.add(AdminEvent(t, type, detail));
      }

      add(joined, Ev.opened, 'First open');
      if (started) add(joined.add(const Duration(seconds: 8)), Ev.onboardingStarted);
      if (signed) add(joined.add(const Duration(seconds: 25)), Ev.signedUp, provider);
      if (heard != null) add(joined.add(Duration(seconds: 30 + (tour ?? 60) - 10)), Ev.heardFrom, heard);
      if (answered) {
        add(joined.add(Duration(seconds: 25 + tour!)), Ev.answered);
        add(joined.add(Duration(seconds: 30 + tour)), Ev.onboardingDone);
      }
      if (notif) add(joined.add(Duration(seconds: 32 + (tour ?? 60))), Ev.notifAllowed);
      if (addedFood) add(joined.add(Duration(minutes: 5 + r.nextInt(20))), Ev.foodAdded, _foods[r.nextInt(_foods.length)]);
      for (var k = 0; k < paywallViews; k++) {
        add(joined.add(Duration(hours: 1 + r.nextInt(daysSince * 24))), Ev.paywallView, 'Free limit or Premium tap');
      }
      final failures = <AdminPayFailure>[];
      for (var k = 0; k < attempts; k++) {
        final t = (subAt ?? joined.add(const Duration(hours: 2))).subtract(Duration(minutes: 3 * (k + 1)));
        final plan2 = r.nextBool() ? 'Yearly' : 'Monthly';
        add(t, Ev.paymentAttempt, plan2);
        final last = k == attempts - 1;
        if (!subscribed || !last) {
          final x = r.nextDouble();
          final reason = x < .6 ? 'cancelled' : (x < .85 ? 'failed' : 'store_unavailable');
          failures.add(AdminPayFailure(t.add(const Duration(minutes: 1)), reason,
              switch (reason) { 'failed' => 'Card declined', 'store_unavailable' => 'Play Store did not answer', _ => plan2 }));
          add(t.add(const Duration(minutes: 1)), Ev.payFailed, reason);
        }
      }
      if (subAt != null) add(subAt, Ev.subscribed, plan == AdminPlan.none ? 'Later cancelled' : plan.name);

      final extra = addedFood ? (isSub || subscribed ? 20 + r.nextInt(35) : 3 + r.nextInt(16)) : r.nextInt(3);
      for (var k = 0; k < extra; k++) {
        final bias = isSub ? r.nextDouble() * r.nextDouble() : r.nextDouble();
        final t = now.subtract(Duration(minutes: (bias * daysSince * 24 * 60).toInt() + r.nextInt(300)));
        final x = r.nextDouble();
        if (x < 0.4 || !addedFood) {
          add(t, Ev.opened); // someone who never added a food only opens the app
        } else if (x < 0.65) {
          add(t, Ev.foodAdded, _foods[r.nextInt(_foods.length)]);
        } else if (x < 0.85) {
          add(t, Ev.foodUsed, _foods[r.nextInt(_foods.length)]);
        } else {
          add(t, Ev.scanUsed, _foods[r.nextInt(_foods.length)]);
        }
      }
      if (started && r.nextDouble() < (isSub ? 0.55 : 0.12)) {
        add(now.subtract(Duration(minutes: r.nextInt(minutesToday))), Ev.opened);
        if (addedFood && r.nextBool()) add(now.subtract(Duration(minutes: r.nextInt(minutesToday))), Ev.foodAdded, _foods[r.nextInt(_foods.length)]);
      }
      events.removeWhere((e) => e.time.isBefore(joined));
      events.sort((a, b) => b.time.compareTo(a.time));

      final last = events.first.time;
      final seenRecently = now.difference(last).inHours < 36;
      final id = 'u${1000 + i}';
      users.add(AdminUser(
        id: id,
        name: guest ? '' : name,
        email: guest ? '' : email,
        country: _countries[r.nextInt(_countries.length)],
        joinedAt: joined,
        lastSeen: last,
        isGuest: guest,
        paywallViews: paywallViews,
        paymentAttempts: attempts,
        plan: plan,
        subscribedAt: subAt,
        payments: payments,
        failures: failures,
        events: events,
        streak: seenRecently ? (isSub ? 3 + r.nextInt(25) : r.nextInt(5)) : 0,
        onboardingSeconds: tour,
        heardFrom: heard,
        answers: answered
            ? {
                'What usually gets forgotten': _problems[r.nextInt(_problems.length)],
                'People shopping for': _households[r.nextInt(_households.length)],
                'Reminders': ['three', 'one', 'both'][r.nextInt(3)],
              }
            : const {},
      ));

      // The phone. Android reports the install time, a little before the first open.
      final installed = joined.subtract(Duration(minutes: 1 + r.nextInt(90)));
      DateTime? gone;
      final quiet = now.difference(last).inDays >= 4;
      if (quiet && r.nextDouble() < 0.55 || r.nextDouble() < 0.05) {
        final t = last.add(Duration(days: 1 + r.nextInt(3), hours: r.nextInt(12)));
        gone = t.isAfter(now) ? now.subtract(const Duration(hours: 3)) : t;
      }
      devices.add(AdminDevice(installId: 'd$i', ownerId: id, installedAt: installed, lastSeen: last, uninstalledAt: gone));
    }

    // Accounts that "Real users only" must hide. Each one fits one rule.
    int n = 0;
    AdminUser special(String name, String email, {bool testPurchase = false, int? seconds, AdminPlan plan = AdminPlan.none}) {
      final joined = now.subtract(Duration(days: 2 + n * 3, hours: n));
      final id = 'x${900 + n++}';
      final pays = plan == AdminPlan.yearly ? [AdminPayment(joined.add(const Duration(hours: 1)), AppConfig.yearlyPrice)] : <AdminPayment>[];
      final ev = <AdminEvent>[
        AdminEvent(now.subtract(const Duration(hours: 2)), Ev.opened, ''),
        AdminEvent(joined.add(const Duration(seconds: 20)), Ev.signedUp, 'email'),
        AdminEvent(joined.add(const Duration(seconds: 8)), Ev.onboardingStarted, ''),
        AdminEvent(joined, Ev.opened, 'First open'),
      ];
      devices.add(AdminDevice(installId: 'd$id', ownerId: id, installedAt: joined.subtract(const Duration(minutes: 5)), lastSeen: now));
      return AdminUser(
        id: id,
        name: name,
        email: email,
        country: 'USA',
        joinedAt: joined,
        lastSeen: now.subtract(const Duration(hours: 2)),
        isGuest: false,
        paywallViews: 0,
        paymentAttempts: 0,
        plan: plan,
        subscribedAt: pays.isEmpty ? null : pays.first.time,
        payments: pays,
        events: ev,
        streak: 1,
        testPurchase: testPurchase,
        onboardingSeconds: seconds,
      );
    }

    users.addAll([
      special('Sidharth Babu', AppConfig.adminEmail),
      special('', AdminConfig.reviewTeamEmails.first),
      special('', 'robot1@cloudtestlabaccounts.com'),
      special('', 'robot2@cloudtestlabaccounts.com'),
      special('', 'testuser48213@example.com'),
      special('', 'testuser90117@example.com'),
      special(AdminConfig.reviewTeamEmails.first, 'robot.signup@example.com'),
      special('Lucky Tester', 'tester.lucky@example.com', testPurchase: true, plan: AdminPlan.yearly),
      special('Quick Clicker', 'quick.clicker@example.com', seconds: 9),
      special('Fast Finger', 'fast.finger@example.com', seconds: 14),
    ]);

    users.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

    final realIds = users.where((u) => u.hiddenReason == null).map((u) => u.id).toList();
    final feedback = <AdminFeedback>[
      for (var i = 0; i < _feedbackTexts.length; i++)
        AdminFeedback(
          id: 'f$i',
          name: users.firstWhere((u) => u.id == realIds[i * 3 % realIds.length]).displayName,
          kind: _feedbackTexts[i].$1,
          text: _feedbackTexts[i].$2,
          time: now.subtract(Duration(hours: 5 + i * 19)),
          handled: i == 4,
        ),
    ];
    return AdminData(users: users, devices: devices, feedback: feedback, serverConnected: true);
  }
}
