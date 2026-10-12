import 'dart:math';
import '../analytics.dart';
import '../auth.dart';
import '../billing.dart';
import '../config.dart';
import '../main.dart' show billing;
import 'models.dart';

/// Every admin screen reads users ONLY through this. Swap [MockAdminRepository] for a
/// Firestore version later without touching any screen.
///
/// SECURITY: when real data is added, the server (Firestore rules / Cloud Function) must
/// check that the caller is [AppConfig.adminEmail]. Hiding the button is not security.
abstract class AdminRepository {
  Future<List<AdminUser>> loadUsers();
}

AdminRepository createAdminRepository() =>
    AppConfig.mock ? MockAdminRepository() : LocalAdminRepository();

/// Real build, before a backend exists: shows only this phone as one user.
class LocalAdminRepository implements AdminRepository {
  @override
  Future<List<AdminUser>> loadUsers() async {
    final ev = Analytics.instance.events;
    final now = DateTime.now();
    final events = [for (final e in ev) AdminEvent(e.time, e.type, e.detail)];
    final first = events.isEmpty ? now : events.last.time;
    final plan = switch (billing.plan) {
      PlanKind.monthly => AdminPlan.monthly,
      PlanKind.yearly => AdminPlan.yearly,
      _ => AdminPlan.none,
    };
    return [
      AdminUser(
        id: 'this-device',
        name: 'This device',
        email: Auth.email ?? 'not signed in',
        country: '-',
        joinedAt: first,
        lastSeen: events.isEmpty ? now : events.first.time,
        onboardingComplete: events.any((e) => e.type == Ev.onboardingDone),
        addedFirstFood: events.any((e) => e.type == Ev.foodAdded),
        paywallViews: events.where((e) => e.type == Ev.paywallView).length,
        paymentAttempts: events.where((e) => e.type == Ev.paymentAttempt).length,
        plan: plan,
        subscribedAt: events.where((e) => e.type == Ev.subscribed).map((e) => e.time).fold<DateTime?>(null, (a, b) => a ?? b),
        payments: const [],
        events: events,
        streak: 0,
      ),
    ];
  }
}

/// About 50 believable users. Fixed seed, so the numbers are the same on every run.
class MockAdminRepository implements AdminRepository {
  static const _first = ['Aarav', 'Diya', 'Vihaan', 'Anaya', 'Arjun', 'Isha', 'Kabir', 'Meera', 'Rohan', 'Saanvi',
    'Ishaan', 'Kavya', 'Neil', 'Priya', 'Rahul', 'Sara', 'Tanvi', 'Yash', 'Zoya', 'Aditya', 'Nisha', 'Dev', 'Riya',
    'Karan', 'Ananya'];
  static const _last = ['Sharma', 'Nair', 'Iyer', 'Patel', 'Khan', 'Reddy', 'Menon', 'Das', 'Gupta', 'Joseph'];
  static const _countries = ['India', 'India', 'India', 'India', 'India', 'UAE', 'UK', 'USA', 'Canada', 'Australia'];
  static const _foods = ['Milk', 'Yogurt', 'Bread', 'Spinach', 'Eggs', 'Cheese', 'Chicken', 'Tomatoes', 'Butter',
    'Paneer', 'Mango juice', 'Rice', 'Carrots', 'Soup'];

  @override
  Future<List<AdminUser>> loadUsers() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _build(DateTime.now());
  }

  List<AdminUser> _build(DateTime now) {
    final r = Random(42);
    final midnight = DateTime(now.year, now.month, now.day);
    final minutesToday = max(1, now.difference(midnight).inMinutes);
    final users = <AdminUser>[];

    for (var i = 0; i < 50; i++) {
      final name = '${_first[r.nextInt(_first.length)]} ${_last[r.nextInt(_last.length)]}';
      final joined = now.subtract(Duration(days: 1 + r.nextInt(60), hours: r.nextInt(20), minutes: r.nextInt(60)));
      final daysSince = max(1, now.difference(joined).inDays);

      final onboarded = r.nextDouble() < 0.92;
      final addedFood = onboarded && r.nextDouble() < 0.88;
      final paywallViews = addedFood && r.nextDouble() < 0.55 ? 1 + r.nextInt(3) : 0;
      final attempts = paywallViews > 0 && r.nextDouble() < 0.5 ? 1 + r.nextInt(2) : 0;
      final subscribed = attempts > 0 && r.nextDouble() < 0.65;

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

      // Events. Subscribers use the app more.
      final events = <AdminEvent>[];
      void add(DateTime t, String type, [String detail = '']) {
        if (t.isAfter(now)) t = now.subtract(Duration(minutes: r.nextInt(30)));
        events.add(AdminEvent(t, type, detail));
      }

      add(joined, Ev.opened, 'First open');
      if (onboarded) add(joined.add(const Duration(minutes: 2)), Ev.onboardingDone);
      if (addedFood) add(joined.add(Duration(minutes: 5 + r.nextInt(20))), Ev.foodAdded, _foods[r.nextInt(_foods.length)]);
      for (var k = 0; k < paywallViews; k++) {
        add(joined.add(Duration(hours: 1 + r.nextInt(daysSince * 24))), Ev.paywallView, 'Free limit or Premium tap');
      }
      for (var k = 0; k < attempts; k++) {
        add((subAt ?? joined.add(Duration(hours: 2))).subtract(Duration(minutes: 3 * (k + 1))), Ev.paymentAttempt,
            r.nextBool() ? 'Yearly' : 'Monthly');
      }
      if (subAt != null) add(subAt, Ev.subscribed, plan == AdminPlan.none ? 'Later cancelled' : plan.name);

      final extra = addedFood ? (isSub || subscribed ? 20 + r.nextInt(35) : 3 + r.nextInt(16)) : r.nextInt(3);
      for (var k = 0; k < extra; k++) {
        final bias = isSub ? r.nextDouble() * r.nextDouble() : r.nextDouble();
        final t = now.subtract(Duration(minutes: (bias * daysSince * 24 * 60).toInt() + r.nextInt(300)));
        final x = r.nextDouble();
        if (x < 0.4) {
          add(t, Ev.opened);
        } else if (x < 0.65) {
          add(t, Ev.foodAdded, _foods[r.nextInt(_foods.length)]);
        } else if (x < 0.85) {
          add(t, Ev.foodUsed, _foods[r.nextInt(_foods.length)]);
        } else {
          add(t, Ev.scanUsed, _foods[r.nextInt(_foods.length)]);
        }
      }
      if (onboarded && r.nextDouble() < (isSub ? 0.55 : 0.12)) {
        // Active today.
        add(now.subtract(Duration(minutes: r.nextInt(minutesToday))), Ev.opened);
        if (r.nextBool()) add(now.subtract(Duration(minutes: r.nextInt(minutesToday))), Ev.foodAdded, _foods[r.nextInt(_foods.length)]);
      }
      events.removeWhere((e) => e.time.isBefore(joined));
      events.sort((a, b) => b.time.compareTo(a.time));

      final last = events.first.time;
      final seenRecently = now.difference(last).inHours < 36;
      users.add(AdminUser(
        id: 'u${1000 + i}',
        name: name,
        email: '${name.toLowerCase().replaceAll(' ', '.')}${r.nextInt(90)}@example.com',
        country: _countries[r.nextInt(_countries.length)],
        joinedAt: joined,
        lastSeen: last,
        onboardingComplete: onboarded,
        addedFirstFood: addedFood,
        paywallViews: paywallViews,
        paymentAttempts: attempts,
        plan: plan,
        subscribedAt: subAt,
        payments: payments,
        events: events,
        streak: seenRecently ? (isSub ? 3 + r.nextInt(25) : r.nextInt(5)) : 0,
      ));
    }
    users.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    return users;
  }
}
