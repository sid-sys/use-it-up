import 'dart:io';
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
  testWidgets('If the sign-in finishes in the background (Apple in the browser), the sign-up screen moves on by itself', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);
    Auth.demoSignIn = true;
    SharedPreferences.setMockInitialValues({'onb_step': 8}); // the sign-up step
    await tester.runAsync(() => app.main());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1800)));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(Auth.signedIn, isFalse);

    // The account appears without anyone tapping a button on this screen.
    await tester.runAsync(() => Auth.instance.signIn(AuthProvider.apple));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Apple'), findsNothing);
    expect(find.text('Start 7-day free trial'), findsOneWidget, reason: 'on to the paywall');
  });
}
