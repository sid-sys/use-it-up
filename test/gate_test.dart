import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:use_it_up/auth.dart';
import 'package:use_it_up/main.dart' as app;

Future<void> loadFonts() async {
  for (final (family, path) in [('Anton', 'assets/fonts/Anton-Regular.ttf'), ('Inter', 'assets/fonts/Inter.ttf')]) {
    final loader = FontLoader(family)..addFont(File(path).readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

void main() {
  testWidgets('Sign out goes to the sign-up screen. There is no guest way in', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);
    Auth.demoSignIn = true;
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'auth_email': 'tester@example.com',
      'auth_name': 'Tester',
      'auth_provider': 'google',
    });
    await tester.runAsync(() => app.main());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1800)));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sign out'), 200, scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400)); // clear of the bottom bar
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(Auth.signedIn, isFalse);
    expect(find.text("LET'S GET YOU\nSTARTED."), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue without an account'), findsNothing);
    expect(find.byTooltip('Back'), findsNothing);
    expect(find.text('Home'), findsNothing, reason: 'the app is not reachable while signed out');

    // Signing in again goes straight back to the app.
    await tester.tap(find.text('Continue with Apple'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}
