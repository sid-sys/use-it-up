import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:use_it_up/auth.dart';
import 'package:use_it_up/billing.dart';
import 'package:use_it_up/config.dart';
import 'package:use_it_up/main.dart' as app;
import 'package:use_it_up/screens/onboarding.dart';
import 'package:use_it_up/theme.dart';
import 'package:use_it_up/toast.dart';

Future<void> loadFonts() async {
  for (final (family, path) in [('Anton', 'assets/fonts/Anton-Regular.ttf'), ('Inter', 'assets/fonts/Inter.ttf')]) {
    final loader = FontLoader(family)..addFont(File(path).readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

Future<void> tapSignOut(WidgetTester tester) async {
  rootMessenger.currentState?.clearSnackBars(); // a message could sit on top of the row
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Sign out'), 200, scrollable: find.byType(Scrollable).first);
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -400)); // clear of the bottom bar
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sign out'));
}

/// One app start per test file, so each person signs in through the pretend sign-in in turn.
Future<void> signInAs(WidgetTester tester, String email) async {
  await tester.runAsync(() => Auth.instance.signOut());
  await tester.pumpAndSettle();
  await tester.runAsync(() => Auth.instance.signIn(AuthProvider.email, emailAddress: email, name: 'Someone'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Profile'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Who sees what in Profile: a person, the owner, and a review login', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'auth_email': 'person@example.com',
      'auth_name': 'Someone',
      'auth_provider': 'google',
    });
    await tester.runAsync(() => app.main());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1800)));
    await tester.pump();
    await tester.pumpAndSettle();

    // 1. A normal person
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Admin panel'), findsNothing);
    await tester.scrollUntilVisible(find.text('Sign out'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Restart onboarding'), findsNothing);
    expect(find.textContaining('sample'), findsNothing);
    expect(app.billing.isPremium, isFalse);

    // 2. The owner
    await tester.scrollUntilVisible(find.text('Sign out'), 200, scrollable: find.byType(Scrollable).first);
    await tapSignOut(tester);
    await signInAs(tester, AppConfig.adminEmail);
    expect(find.text('Admin panel'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Admin panel')).dy, lessThan(tester.getTopLeft(find.text('Someone')).dy), reason: 'on top');
    await tester.scrollUntilVisible(find.text('Sign out'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Restart onboarding'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Sign out')).style?.color, redDark);

    // 3. A review login: Premium without paying
    await tapSignOut(tester);
    await signInAs(tester, AppConfig.reviewEmails.first);
    expect(app.billing.isPremium, isTrue);
    expect(app.billing.plan, PlanKind.lifetime);
    expect(find.text('PREMIUM (REVIEW LOGIN)'), findsOneWidget);
    expect(find.text('Cancel plan'), findsNothing);
    expect(find.text('Admin panel'), findsNothing);
    expect(app.store.atItemLimit, isFalse, reason: 'no 20 food limit for a reviewer');

    // and a normal person again: back to free
    await tester.scrollUntilVisible(find.text('Sign out'), 200, scrollable: find.byType(Scrollable).first);
    await tapSignOut(tester);
    await signInAs(tester, 'person@example.com');
    expect(app.billing.isPremium, isFalse);

    // let every little message finish before the test ends
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
    rootMessenger.currentState?.clearSnackBars();
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
  });

  testWidgets('Sign in with Apple shows on iPhone only', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);
    for (final (platform, shown) in [(TargetPlatform.android, false), (TargetPlatform.iOS, true)]) {
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const SignInRequired()));
      await tester.pumpAndSettle();
      expect(find.text('Continue with Apple'), shown ? findsOneWidget : findsNothing, reason: platform.name);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with email'), findsOneWidget);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  test('the review login is also hidden from the admin numbers', () {
    expect(AppConfig.reviewEmails, isNotEmpty);
    expect(Auth.isReviewer, isFalse);
  });
}
