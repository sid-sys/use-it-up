import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:use_it_up/main.dart' as app;
import 'package:use_it_up/models.dart';

Future<void> loadFonts() async {
  for (final (family, path) in [('Anton', 'assets/fonts/Anton-Regular.ttf'), ('Inter', 'assets/fonts/Inter.ttf')]) {
    final loader = FontLoader(family)..addFont(File(path).readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

Map<String, dynamic> item(String id, String name, int daysFromNow, {String? storage}) {
  final d = DateTime.now().add(Duration(days: daysFromNow));
  return FoodItem(
    id: id,
    name: name,
    expiry: DateTime(d.year, d.month, d.day),
    storage: storage,
  ).toJson();
}

void main() {
  test('group boundaries: up to 7 days, 8 to 28 days, over 28 days', () {
    expect(shelfGroupOf(-1), ShelfGroup.eatFirst);
    expect(shelfGroupOf(0), ShelfGroup.eatFirst);
    expect(shelfGroupOf(7), ShelfGroup.eatFirst);
    expect(shelfGroupOf(8), ShelfGroup.stillFresh);
    expect(shelfGroupOf(28), ShelfGroup.stillFresh);
    expect(shelfGroupOf(29), ShelfGroup.longKeepers);
    expect(shelfGroupOf(365), ShelfGroup.longKeepers);
    expect(ShelfGroup.stillFresh.sub, 'Lasts 1–4 weeks');
    expect(ShelfGroup.longKeepers.sub, 'Lasts 1–12 months');
    expect(ShelfGroup.eatFirst.sub, 'Lasts up to 7 days');
  });

  testWidgets('Home shows the three groups with the fruit bowl art', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'items': jsonEncode([
        item('1', 'Spinach', 0),
        item('2', 'Greek yogurt', 1),
        item('3', 'Strawberries', 3),
        item('4', 'Cheddar cheese', 14),
        item('5', 'Dumplings', 20, storage: 'Freezer'),
        item('6', 'Rice', 200),
        item('7', 'Tomatoes', 300, storage: 'Canned'),
      ]),
    });

    await tester.runAsync(() => app.main());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1800)));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Eat me first'), findsOneWidget);
    expect(find.text('Lasts up to 7 days'), findsOneWidget);
    expect(find.text('ASAP 2'), findsOneWidget);
    expect(find.text('This week 1'), findsOneWidget);
    final list = find.descendant(of: find.byType(TabBarView), matching: find.byType(Scrollable)).first;
    await tester.dragUntilVisible(find.text('Still fresh'), list, const Offset(0, -150));
    expect(find.text('Still fresh'), findsOneWidget);
    expect(find.text('Lasts 1–4 weeks'), findsOneWidget);
    expect(find.text('cheddar cheese'), findsOneWidget);
    expect(find.text('frozen'), findsOneWidget);

    await tester.dragUntilVisible(find.text('Full inventory'), list, const Offset(0, -150));
    expect(find.text('Long keepers'), findsOneWidget);
    expect(find.text('Lasts 1–12 months'), findsOneWidget);
    expect(find.text('canned'), findsOneWidget);
    expect(find.text('Full inventory'), findsOneWidget);

    // Full inventory opens the group list.
    await tester.tap(find.text('Full inventory'));
    await tester.pumpAndSettle();
    expect(find.text('LONG KEEPERS'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
  });
}
