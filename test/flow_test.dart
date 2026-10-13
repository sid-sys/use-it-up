import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:use_it_up/auth.dart';
import 'package:use_it_up/main.dart' as app;

Future<void> tapText(WidgetTester t, String text) async {
  final f = find.text(text);
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(f, 150, scrollable: find.byType(Scrollable).first);
  }
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

/// Load the real brand fonts so layout in the test matches the phone.
Future<void> loadFonts() async {
  for (final (family, path) in [('Anton', 'assets/fonts/Anton-Regular.ttf'), ('Inter', 'assets/fonts/Inter.ttf')]) {
    final loader = FontLoader(family)..addFont(File(path).readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

void main() {
  testWidgets('first run: welcome, sign up, 3 questions, reminders, paywall, home', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);
    SharedPreferences.setMockInitialValues({});

    await tester.runAsync(() => app.main());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1800))); // splash timer
    await tester.pump();
    await tester.pumpAndSettle();

    // 1. Welcome
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Free to start · Takes less than a minute'), findsOneWidget);
    await tapText(tester, 'Get started');

    // 2. Sign up (mock build: Google makes a demo account)
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.text('Continue without an account'), findsOneWidget);
    await tapText(tester, 'Continue with Google');
    expect(Auth.signedIn, isTrue);
    expect(Auth.displayName, 'Demo Google'); // name comes from the email

    // 3. Question 1: pick, continue
    expect(find.text('1 of 3'), findsOneWidget);
    await tapText(tester, 'Leftovers get forgotten');
    await tapText(tester, 'Continue');

    // Question 2: skip
    expect(find.text('2 of 3'), findsOneWidget);
    await tapText(tester, 'Skip');

    // Question 3: choose "1 day before", finish
    expect(find.text('3 of 3'), findsOneWidget);
    await tapText(tester, '1 day before');
    await tapText(tester, 'Finish setup');

    // 4. Notification explanation
    expect(find.textContaining("We'll remind you before your food's expiry date"), findsOneWidget);
    await tapText(tester, 'Continue');

    // 5. Soft paywall, dismissible
    expect(find.text('Start free trial'), findsOneWidget);
    expect(find.text('Maybe later'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
    await tapText(tester, 'Maybe later');

    // 6. Home, empty state
    expect(find.text('Add your first food'), findsOneWidget);
    expect(find.text('Add food'), findsOneWidget);
    expect(app.store.onboarded, isTrue);
    expect(app.store.problem, 'leftovers');
    expect(app.store.household, isNull);
    expect(app.store.remindWhen, 'one');
    expect(app.store.prefs.oneDay, isTrue);
    expect(app.store.prefs.threeDays, isFalse);
    expect(app.billing.isPremium, isFalse, reason: 'Maybe later keeps the free tier');
  });
}
