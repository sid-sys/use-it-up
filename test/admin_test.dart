import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:use_it_up/admin/admin_config.dart';
import 'package:use_it_up/admin/dashboard.dart';
import 'package:use_it_up/admin/models.dart';
import 'package:use_it_up/admin/repository.dart';
import 'package:use_it_up/analytics.dart';
import 'package:use_it_up/config.dart';
import 'package:use_it_up/main.dart' as app;
import 'package:use_it_up/theme.dart';

Future<void> loadFonts() async {
  for (final (family, path) in [('Anton', 'assets/fonts/Anton-Regular.ttf'), ('Inter', 'assets/fonts/Inter.ttf')]) {
    final loader = FontLoader(family)..addFont(File(path).readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

AdminUser user(String name, String email, {bool test = false, int? secs}) => AdminUser(
      id: email,
      name: name,
      email: email,
      country: 'India',
      joinedAt: DateTime(2026, 10, 1),
      lastSeen: DateTime(2026, 10, 2),
      isGuest: false,
      paywallViews: 0,
      paymentAttempts: 0,
      plan: AdminPlan.none,
      subscribedAt: null,
      payments: const [],
      events: const [],
      streak: 0,
      testPurchase: test,
      onboardingSeconds: secs,
    );

void main() {
  final now = DateTime(2026, 10, 20, 14, 0);

  group('Real users only: the hide rules', () {
    test('each rule hides the right account with the right reason', () {
      expect(AdminConfig.hiddenReason(user('Me', AppConfig.adminEmail)), 'Your own account');
      expect(AdminConfig.hiddenReason(user('', AdminConfig.reviewTeamEmails.first)), 'Play review login');
      expect(AdminConfig.hiddenReason(user('', 'abc@cloudtestlabaccounts.com')), 'Google test robot');
      expect(AdminConfig.hiddenReason(user(AdminConfig.reviewTeamEmails.first, 'x@example.com')), 'Play review robot');
      expect(AdminConfig.hiddenReason(user('', 'testuser12345@example.com')), 'Automated test');
      expect(AdminConfig.hiddenReason(user('Lucky', 'lucky@example.com', test: true)), 'Test purchase');
      expect(AdminConfig.hiddenReason(user('Fast', 'fast@example.com', secs: 24)), 'Looks like a robot');
    });

    test('a real person is never hidden', () {
      expect(AdminConfig.hiddenReason(user('Aarav Sharma', 'aarav@example.com', secs: 25)), isNull);
      expect(AdminConfig.hiddenReason(user('Diya', 'diya.testuser@example.com', secs: 90)), isNull);
      expect(AdminConfig.hiddenReason(user('', '')), isNull, reason: 'a guest with no data is a real person');
      expect(AdminConfig.hiddenReason(user('Slow', 'slow@example.com', secs: null)), isNull, reason: 'no timing is not a robot');
    });
  });

  group('mock data', () {
    final data = MockAdminRepository().build(now);

    test('is the same every time', () {
      final again = MockAdminRepository().build(now);
      expect(data.users.map((u) => u.id).toList(), again.users.map((u) => u.id).toList());
      expect(data.devices.length, again.devices.length);
    });

    test('has 50 real people and exactly the 10 accounts that must be hidden', () {
      final hidden = data.users.where((u) => u.hiddenReason != null).toList();
      expect(data.users.length, 60);
      expect(hidden.length, 10);
      expect(hidden.every((u) => u.id.startsWith('x9')), isTrue, reason: 'no real person is hidden');
      expect(hidden.map((u) => u.hiddenReason).toSet(), {
        'Your own account',
        'Play review login',
        'Google test robot',
        'Play review robot',
        'Automated test',
        'Test purchase',
        'Looks like a robot',
      });
    });

    test('the switch changes every number', () {
      final real = data.users.where((u) => u.hiddenReason == null).toList();
      final all = AdminStats.from(data.users, data.devices, now);
      final onlyReal = AdminStats.from(real, data.devices, now);
      expect(onlyReal.totalUsers, 50);
      expect(all.totalUsers, 60);
      expect(onlyReal.funnel.first.count, 50);
      expect(all.revenueTotal, greaterThan(onlyReal.revenueTotal), reason: 'the test purchase is not counted as revenue');
      // The funnel never grows from one step to the next.
      for (var i = 1; i < onlyReal.funnel.length; i++) {
        expect(onlyReal.funnel[i].count, lessThanOrEqualTo(onlyReal.funnel[i - 1].count), reason: onlyReal.funnel[i].label);
      }
      expect(onlyReal.profitAfter, lessThanOrEqualTo(onlyReal.profitBefore));
    });

    test('installs and uninstalls: one phone counts once, owned by a shown person', () {
      final real = data.users.where((u) => u.hiddenReason == null).toList();
      final s = AdminStats.from(real, data.devices, now);
      expect(s.installs30.length, 30);
      final ids = real.map((u) => u.id).toSet();
      final installedPeople = s.installs30.expand((d) => d.installed).toList();
      expect(installedPeople.every((u) => ids.contains(u.id)), isTrue, reason: 'hidden owners are not counted');
      expect(installedPeople.length, installedPeople.map((u) => u.id).toSet().length, reason: 'a phone counts once');
      expect(s.installs30.any((d) => d.uninstalled.isNotEmpty), isTrue);
      final d = s.installs30.firstWhere((d) => d.installed.isNotEmpty);
      expect(d.net, d.installed.length - d.uninstalled.length);
      expect(d.netWords, d.net > 0 ? 'Net gain +${d.net}' : (d.net < 0 ? 'Net loss ${d.net}' : 'No change'));
    });

    test('sources and payment problems add up', () {
      final real = data.users.where((u) => u.hiddenReason == null).toList();
      final s = AdminStats.from(real, data.devices, now);
      expect(s.sources.values.fold<int>(0, (a, l) => a + l.length), 50, reason: 'everybody is in one bar');
      expect(s.payProblems.keys.toSet(), {'cancelled', 'failed', 'store_unavailable'});
    });

    test('names are real: the name, else the email, else "Guest" and 6 characters. Never made up', () {
      expect(user('Aarav Sharma', 'a@example.com').displayName, 'Aarav Sharma');
      expect(user('', 'a@example.com').displayName, 'a@example.com');
      expect(user('', 'a@example.com').subtitleLine, 'No name given');
      final guest = AdminUser(
        id: '3f9a2c1e77aa',
        name: '',
        email: '',
        country: 'India',
        joinedAt: now,
        lastSeen: now,
        isGuest: true,
        paywallViews: 0,
        paymentAttempts: 0,
        plan: AdminPlan.none,
        subscribedAt: null,
        payments: const [],
        events: const [],
        streak: 0,
      );
      expect(guest.displayName, 'Guest 3f9a2c');
      expect(guest.subtitleLine, 'No name, no email');
      for (final u in data.users) {
        final ok = u.displayName == u.name || u.displayName == u.email || u.displayName == 'Guest ${u.id.substring(0, 6)}';
        expect(ok, isTrue, reason: 'every name is the real name, the email or Guest plus the id: ${u.displayName}');
      }
      expect(data.users.any((u) => u.displayName.startsWith('Guest ')), isTrue);
      expect(data.users.every((u) => !RegExp(r'^User \d+$|^Person \d+$').hasMatch(u.displayName)), isTrue);
    });

    test('the active bars list the people who opened the app that day', () {
      final real = data.users.where((u) => u.hiddenReason == null).toList();
      final s = AdminStats.from(real, data.devices, now);
      expect(s.active30.length, 30);
      for (final d in s.active30) {
        expect(d.users.every((u) => u.events.any((e) => DateUtils.isSameDay(e.time, d.day))), isTrue);
      }
      expect(s.active30.any((d) => d.users.isNotEmpty), isTrue);
    });
  });

  testWidgets('Dashboard: Real users only hides test accounts and shows who is hidden', (tester) async {
    tester.view.physicalSize = const Size(1080, 14000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);
    SharedPreferences.setMockInitialValues({});
    Analytics.instance.events.clear();
    expect(app.UseItUpApp, isNotNull);

    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const AdminDashboard()));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('ADMIN PANEL'), findsOneWidget);
    expect(find.text('Real users only'), findsOneWidget);
    expect(find.text('Hiding 10 test, review and my own accounts'), findsOneWidget);
    expect(find.text('Installs and uninstalls'), findsOneWidget); // the second half of the chart switch
    expect(find.text('From joining to subscribing'), findsOneWidget);
    expect(find.text('When paying did not happen'), findsOneWidget);
    expect(find.text('Where people heard about us'), findsOneWidget);
    expect(find.text('Total users'), findsOneWidget);
    expect(find.text('50'), findsWidgets);

    await tester.tap(find.text('Hiding 10 test, review and my own accounts'));
    await tester.pumpAndSettle();
    expect(find.text('HIDDEN ACCOUNTS'), findsOneWidget);
    expect(find.text('Your own account'), findsOneWidget);
    expect(find.text('Google test robot'), findsNWidgets(2));
    await tester.pageBack();
    await tester.pumpAndSettle();

    // ONE chart card with a switch. It opens on "Active users".
    expect(find.text('Active users'), findsOneWidget);
    expect(find.byKey(const ValueKey('active-chart')), findsOneWidget);
    expect(find.byKey(const ValueKey('installs-chart')), findsNothing);
    final real = MockAdminRepository().build(DateTime.now()).users.where((u) => u.hiddenReason == null).toList();
    final stats = AdminStats.from(real, MockAdminRepository().build(DateTime.now()).devices, DateTime.now());

    // Tap today's bar: the people behind it open straight away.
    await tester.tap(find.byKey(const ValueKey('bar-active-29')));
    await tester.pumpAndSettle();
    expect(find.textContaining('ACTIVE ON'), findsOneWidget);
    if (stats.active30.last.users.isEmpty) {
      expect(find.text('Nobody was active that day'), findsOneWidget);
    } else {
      expect(find.byType(Card), findsNothing); // rows, not a day screen
      await tester.tap(find.text(stats.active30.last.users.first.displayName).first);
      await tester.pumpAndSettle();
      expect(find.text('USER'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    await tester.pageBack();
    await tester.pumpAndSettle();

    // The switch swaps the bars inside the same card.
    await tester.tap(find.text('Installs and uninstalls'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('installs-chart')), findsOneWidget);
    expect(find.byKey(const ValueKey('active-chart')), findsNothing);
    expect(find.textContaining('Installed '), findsWidgets);
    expect(find.textContaining('Uninstalled '), findsWidgets);

    // A bar with nobody behind it says so.
    final today = stats.installs30.last;
    await tester.tap(find.byKey(const ValueKey('bar-installed-29')));
    await tester.pumpAndSettle();
    expect(find.textContaining('INSTALLED ON'), findsOneWidget);
    if (today.installed.isEmpty) expect(find.text('Nobody installed that day'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bar-uninstalled-29')));
    await tester.pumpAndSettle();
    expect(find.textContaining('UNINSTALLED ON'), findsOneWidget);
    if (today.uninstalled.isEmpty) expect(find.text('Nobody uninstalled that day'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Turning the switch off shows everything.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Showing everything, including 10 test, review and my own accounts'), findsOneWidget);
    expect(find.text('60'), findsWidgets);
  });
}
