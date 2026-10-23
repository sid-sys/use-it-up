import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:use_it_up/auth.dart';
import 'package:use_it_up/config.dart';
import 'package:use_it_up/screens/onboarding.dart';
import 'package:use_it_up/theme.dart';

Future<void> loadFonts() async {
  for (final (family, path) in [('Anton', 'assets/fonts/Anton-Regular.ttf'), ('Inter', 'assets/fonts/Inter.ttf')]) {
    final loader = FontLoader(family)..addFont(File(path).readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

void main() {
  testWidgets('The eye icon next to the password shows and hides what is typed', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);
    Auth.demoSignIn = false; // the password box only exists with real sign-in. Nothing is sent from this test.
    addTearDown(() => Auth.demoSignIn = true);

    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const SignInRequired()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();

    final field = find.widgetWithText(TextField, 'Password');
    expect(field, findsOneWidget);
    await tester.enterText(field, 'Secret123');
    TextField box() => tester.widget<TextField>(field);
    expect(box().obscureText, isTrue, reason: 'hidden at first');
    expect(find.byTooltip('Show password'), findsOneWidget);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(box().obscureText, isFalse, reason: 'shown after tapping the eye');
    expect(find.byTooltip('Hide password'), findsOneWidget);
    expect(find.text('Secret123'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pumpAndSettle();
    expect(box().obscureText, isTrue);
  });

  test('the review login gets Premium only with its password, not by signing in with Google or Apple', () async {
    expect(AppConfig.reviewEmails, ['review@gmail.com']);
    Future<void> signInAs(String provider) async {
      SharedPreferences.setMockInitialValues({'auth_email': 'review@gmail.com', 'auth_name': 'Reviewer', 'auth_provider': provider});
      await Auth.instance.load();
    }

    await signInAs('email');
    expect(Auth.isReviewer, isTrue);
    await signInAs('google');
    expect(Auth.isReviewer, isFalse, reason: 'whoever owns that Gmail address could sign in with Google');
    await signInAs('apple');
    expect(Auth.isReviewer, isFalse);
    SharedPreferences.setMockInitialValues({'auth_email': 'someone@example.com', 'auth_name': 'S', 'auth_provider': 'email'});
    await Auth.instance.load();
    expect(Auth.isReviewer, isFalse);
  });
}
