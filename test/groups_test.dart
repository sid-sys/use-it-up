import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:use_it_up/main.dart' as app;
import 'package:intl/intl.dart';
import 'package:use_it_up/models.dart';
import 'package:use_it_up/theme.dart';

Future<void> loadFonts() async {
  for (final (family, path) in [('Anton', 'assets/fonts/Anton-Regular.ttf'), ('Inter', 'assets/fonts/Inter.ttf')]) {
    final loader = FontLoader(family)..addFont(File(path).readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

Map<String, dynamic> item(String id, String name, int daysFromNow, {String? storage}) {
  final d = DateTime.now().add(Duration(days: daysFromNow));
  return FoodItem(id: id, name: name, expiry: DateTime(d.year, d.month, d.day), storage: storage).toJson();
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

  test('red means the date is within one week or already passed', () {
    FoodItem inDays(int d) {
      final t = DateTime.now().add(Duration(days: d));
      return FoodItem(id: 'x', name: 'X', expiry: DateTime(t.year, t.month, t.day));
    }

    expect(inDays(-3).isUrgent, isTrue);
    expect(inDays(0).isUrgent, isTrue);
    expect(inDays(7).isUrgent, isTrue);
    expect(inDays(8).isUrgent, isFalse);
    final used = inDays(2)..used = true;
    expect(used.isUrgent, isFalse);
  });

  testWidgets('Home shows group cards with pills. Foods tab holds the three lists', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'items': jsonEncode([
        item('0', 'Cucumber', -2, storage: 'Cut'),
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

    // Home: pills in every group
    final list = find.byType(Scrollable).first;
    expect(find.text('Eat me first'), findsOneWidget);
    expect(find.text('Lasts up to 7 days'), findsOneWidget);
    expect(find.text('ASAP 2'), findsOneWidget);
    expect(find.text('This week 1'), findsOneWidget);
    expect(find.text('spinach'), findsOneWidget);
    expect(find.text('greek yogurt'), findsOneWidget);

    // The attention card counts and opens exactly the urgent foods
    expect(find.text('4 items'), findsOneWidget);
    await tester.tap(find.text('NEEDS YOUR ATTENTION'));
    await tester.pumpAndSettle();
    expect(find.text('Cucumber'), findsOneWidget);
    expect(find.text('Spinach'), findsOneWidget);
    expect(find.text('Strawberries'), findsOneWidget);
    expect(find.text('Cheddar cheese'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(find.text('Still fresh'), list, const Offset(0, -150));
    expect(find.text('Check before toss'), findsOneWidget);
    expect(find.text('cucumber'), findsOneWidget);
    expect(find.text('cut'), findsOneWidget);
    expect(find.text('Lasts 1–4 weeks'), findsOneWidget);
    expect(find.text('cheddar cheese'), findsOneWidget);
    expect(find.text('frozen'), findsOneWidget);
    await tester.dragUntilVisible(find.text('Full inventory'), list, const Offset(0, -150));
    expect(find.text('Long keepers'), findsOneWidget);
    expect(find.text('Lasts 1–12 months'), findsOneWidget);
    expect(find.text('canned'), findsOneWidget);

    // Full inventory opens the group list, then back.
    await tester.tap(find.text('Full inventory'));
    await tester.pumpAndSettle();
    expect(find.text('LONG KEEPERS'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Foods nav item: the three tabs live here
    await tester.tap(find.text('Foods'));
    await tester.pumpAndSettle();
    expect(find.text('ALL YOUR FOOD'), findsOneWidget);
    expect(find.text('Foods 7'), findsOneWidget);

    // Dates within a week are red. Later ones are not.
    final fmt = DateFormat('d MMM yyyy');
    Color? dateColor(int days) =>
        tester.widget<Text>(find.text(fmt.format(DateTime.now().add(Duration(days: days))))).style?.color;
    expect(dateColor(0), redDark);
    expect(dateColor(3), redDark);
    expect(dateColor(14), isNot(redDark));
    expect(find.text('Expired 1'), findsOneWidget);
    expect(find.text('Used 0'), findsOneWidget);
    await tester.tap(find.text('Expired 1'));
    await tester.pumpAndSettle();
    expect(find.text('EXPIRED'), findsOneWidget);

    // Home can open the Expired tab directly
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    app.openFoods.value = app.FoodsRequest(1);
    await tester.pumpAndSettle();
    expect(find.text('ALL YOUR FOOD'), findsOneWidget);
    expect(find.textContaining('These passed their date'), findsOneWidget);
  });
}
