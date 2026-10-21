import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:use_it_up/main.dart' as app;

/// Load the real brand fonts so layout in the test matches the phone.
Future<void> loadFonts() async {
  for (final (family, path) in [('Anton', 'assets/fonts/Anton-Regular.ttf'), ('Inter', 'assets/fonts/Inter.ttf')]) {
    final loader = FontLoader(family)..addFont(File(path).readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

void main() {
  testWidgets('closing the app midway resumes at the saved onboarding step', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // Saved state: the user was on question 2.
    await tester.runAsync(loadFonts);
    SharedPreferences.setMockInitialValues({'onb_step': 3, 'onb_problem': 'buy_more'});

    await tester.runAsync(() => app.main());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1800))); // splash timer
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('2 of 4'), findsOneWidget);
    expect(app.store.problem, 'buy_more');
    expect(app.store.onboarded, isFalse);
  });
}
