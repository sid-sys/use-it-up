import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:use_it_up/billing.dart';
import 'package:use_it_up/main.dart' as app;
import 'package:use_it_up/screens/paywall.dart';
import 'package:use_it_up/store.dart';
import 'package:use_it_up/theme.dart';

Future<void> loadFonts() async {
  for (final (family, path) in [('Anton', 'assets/fonts/Anton-Regular.ttf'), ('Inter', 'assets/fonts/Inter.ttf')]) {
    final loader = FontLoader(family)..addFont(File(path).readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

void main() {
  testWidgets('7-day trial: reminder screen, then Continue starts the trial', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);
    SharedPreferences.setMockInitialValues({});
    app.billing = Billing();
    app.store = Store(app.billing);

    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const PaywallScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Start 7-day free trial'), findsOneWidget);
    expect(find.text('Start free trial'), findsNothing);

    await tester.tap(find.text('Start 7-day free trial'));
    await tester.pumpAndSettle();
    expect(find.textContaining('REMINDER BEFORE'), findsOneWidget);
    expect(find.textContaining('7 days free, then \$39.99 per year'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(app.billing.trialActive, isTrue);
    expect(app.billing.plan, PlanKind.trial);
  });
}
