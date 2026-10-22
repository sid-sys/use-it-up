import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:use_it_up/billing.dart';
import 'package:use_it_up/auth.dart';
import 'package:use_it_up/main.dart' as app;
import 'package:use_it_up/models.dart';
import 'package:use_it_up/toast.dart';

Future<void> loadFonts() async {
  for (final (family, path) in [('Anton', 'assets/fonts/Anton-Regular.ttf'), ('Inter', 'assets/fonts/Inter.ttf')]) {
    final loader = FontLoader(family)..addFont(File(path).readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

void main() {
  testWidgets('At 20 foods, Add food opens the upgrade paywall', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);
    Auth.demoSignIn = true;
    SharedPreferences.setMockInitialValues({'onboarded': true, 'auth_email': 'tester@example.com', 'auth_name': 'Tester', 'auth_provider': 'google'});

    await tester.runAsync(() => app.main());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1800)));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('YOUR FRIDGE IS EMPTY'), findsOneWidget);
    for (var i = 0; i < 20; i++) {
      await app.store.add(FoodItem(id: 'f$i', name: 'Food $i', expiry: DateTime.now().add(Duration(days: i + 1))));
    }
    await tester.pumpAndSettle();

    expect(app.store.itemCount, 20, reason: 'never more than the free limit');
    expect(find.text('20/20 items'), findsOneWidget);
    expect(find.text('Eat me first'), findsOneWidget);
    expect(find.textContaining('sample'), findsNothing, reason: 'no demo foods or demo buttons in the app');

    // At the limit, Add food goes straight to the upgrade paywall.
    await tester.tap(find.text('Add food'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Free plan holds 20 foods'), findsOneWidget);
    expect(find.text('Start 7-day free trial'), findsOneWidget);

    // Start 7-day free trial first shows "we will remind you before the trial ends". Back buys nothing.
    rootMessenger.currentState?.clearSnackBars(); // a message at the bottom would cover the button
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start 7-day free trial'));
    await tester.pumpAndSettle();
    expect(find.textContaining('REMINDER BEFORE'), findsOneWidget);
    expect(find.text('No commitment, cancel anytime'), findsOneWidget);
    expect(find.textContaining('7 days free, then'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(app.billing.isPremium, isFalse);
    expect(find.text('Start 7-day free trial'), findsOneWidget);

    // Restore purchases shows progress and then always says what happened
    rootMessenger.currentState?.clearSnackBars(); // a message at the bottom would cover the button
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore purchases'));
    await tester.pumpAndSettle();
    expect(find.text('No past purchases found.'), findsOneWidget);
    expect(find.text('Checking your purchases...'), findsNothing);

    await tester.tap(find.text('Maybe later'));
    await tester.pumpAndSettle();
    expect(find.text('Add food'), findsOneWidget);
    expect(app.store.atItemLimit, isTrue);

    // Premium lifts the limit.
    await app.billing.subscribe(PlanKind.lifetime);
    expect(app.store.atItemLimit, isFalse);

  });
}
