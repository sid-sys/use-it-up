import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:use_it_up/main.dart' as app;
import 'package:use_it_up/models.dart';
import 'package:use_it_up/theme.dart';
import 'package:use_it_up/widgets/week_strip.dart';

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
    expect(shelfGroupOf(0), ShelfGroup.eatFirst);
    expect(shelfGroupOf(7), ShelfGroup.eatFirst);
    expect(shelfGroupOf(8), ShelfGroup.stillFresh);
    expect(shelfGroupOf(28), ShelfGroup.stillFresh);
    expect(shelfGroupOf(29), ShelfGroup.longKeepers);
    expect(shelfGroupOf(365), ShelfGroup.longKeepers);
    expect(ShelfGroup.stillFresh.sub, 'Lasts 1–4 weeks');
    expect(ShelfGroup.longKeepers.sub, 'Lasts 1–12 months');
    expect(ShelfGroup.eatFirst.sub, 'Lasts up to 7 days');
    expect(ShelfGroup.checkBeforeToss.sub, 'Past its date, not used yet');
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

  test('check before toss: date passed and not used. Today does not count', () {
    FoodItem inDays(int d, {bool used = false}) {
      final t = DateTime.now().add(Duration(days: d));
      return FoodItem(id: 'x', name: 'X', expiry: DateTime(t.year, t.month, t.day), used: used);
    }

    expect(inDays(-1).isExpired, isTrue);
    expect(inDays(0).isExpired, isFalse);
    expect(inDays(-5, used: true).isExpired, isFalse);
  });

  testWidgets('Home: week strip and four cards. Foods nav: lists. Back button', (tester) async {
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

    // Home: add button, counter, week strip with legend
    expect(find.text('Add food'), findsOneWidget);
    expect(find.text('8/20 items'), findsOneWidget);
    expect(find.byType(WeekStrip), findsOneWidget);
    expect(find.text('food expiring'), findsOneWidget);
    expect(find.text('passed its date'), findsOneWidget);

    // Four cards in a grid. Cards show counts, not food names.
    expect(find.text('Eat me first'), findsOneWidget);
    expect(find.text('Check before toss'), findsOneWidget);
    expect(find.text('Still fresh'), findsOneWidget);
    expect(find.text('Long keepers'), findsOneWidget);
    expect(find.text('3 items'), findsNWidgets(1));
    expect(find.text('1 item'), findsWidgets);
    expect(find.text('spinach'), findsNothing);
    expect(find.text('Spinach'), findsNothing);

    // Attention card opens exactly the urgent foods
    expect(find.text('4 items'), findsOneWidget);
    await tester.tap(find.text('NEEDS YOUR ATTENTION'));
    await tester.pumpAndSettle();
    expect(find.text('Cucumber'), findsOneWidget);
    expect(find.text('Spinach'), findsOneWidget);
    expect(find.text('Strawberries'), findsOneWidget);
    expect(find.text('Cheddar cheese'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Each card opens the foods behind it
    await tester.tap(find.text('Long keepers'));
    await tester.pumpAndSettle();
    expect(find.text('LONG KEEPERS'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Tomatoes'), findsOneWidget);
    expect(find.text('Spinach'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check before toss'));
    await tester.pumpAndSettle();
    expect(find.text('CHECK BEFORE TOSS'), findsOneWidget);
    expect(find.text('Cucumber'), findsOneWidget);
    expect(find.text('EXPIRED'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Tapping a day in the week strip opens that day's foods
    final today = DateTime.now();
    await tester.tap(find.descendant(of: find.byType(WeekStrip), matching: find.text('${today.day}')));
    await tester.pumpAndSettle();
    expect(find.text(DateFormat('EEE d MMM').format(today).toUpperCase()), findsOneWidget);
    expect(find.text('Spinach'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Foods nav item: the three tabs live here, without the Add food button
    await tester.tap(find.text('Foods'));
    await tester.pumpAndSettle();
    expect(find.text('ALL YOUR FOOD'), findsOneWidget);
    expect(find.text('Add food'), findsNothing);
    expect(find.text('Foods 7'), findsOneWidget);
    expect(find.text('Expired 1'), findsOneWidget);
    expect(find.text('Used 0'), findsOneWidget);

    // Dates within a week are red. Later ones are not.
    final fmt = DateFormat('d MMM yyyy');
    Color? dateColor(int days) =>
        tester.widget<Text>(find.text(fmt.format(DateTime.now().add(Duration(days: days))))).style?.color;
    expect(dateColor(0), redDark);
    expect(dateColor(3), redDark);
    expect(dateColor(14), isNot(redDark));
    // A long name is not cut: the card gives the name its own full line
    expect(find.text('Strawberries'), findsOneWidget);

    // Back button on Foods goes to Home. On Home it asks first.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Add food'), findsOneWidget);
    expect(find.text('ALL YOUR FOOD'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Leave Use It Up?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Leave Use It Up?'), findsNothing);
    expect(find.text('Add food'), findsOneWidget);

    // The Home counter and cards refresh when the food list changes
    expect(find.text('8/20 items'), findsOneWidget);
    expect(find.text('2 items'), findsNWidgets(2)); // Still fresh and Long keepers
    await app.store.markUsed(app.store.fresh.firstWhere((i) => i.name == 'Rice'));
    await tester.pumpAndSettle();
    expect(find.text('7/20 items'), findsOneWidget);
    expect(find.text('2 items'), findsNWidgets(1), reason: 'Long keepers card refreshed');
    expect(find.text('1 item'), findsNWidgets(2), reason: 'Check before toss and Long keepers');
    await app.store.restoreItem(app.store.usedItems.firstWhere((i) => i.name == 'Rice'));
    await tester.pumpAndSettle();
    expect(find.text('8/20 items'), findsOneWidget);

    // The demo button switches between Load and Remove, filling up to the free limit
    final load = find.text('Load sample foods (demo)');
    await tester.dragUntilVisible(load, find.byType(Scrollable).first, const Offset(0, -300));
    await tester.tap(load);
    await tester.pumpAndSettle();
    expect(app.store.itemCount, 20);
    expect(find.text('Remove sample foods (demo)'), findsOneWidget);
    expect(find.text('Load sample foods (demo)'), findsNothing);
    await tester.tap(find.text('Remove sample foods (demo)'));
    await tester.pumpAndSettle();
    expect(app.store.itemCount, 8);
    expect(find.text('Load sample foods (demo)'), findsOneWidget);
    await tester.dragUntilVisible(find.text('Add food'), find.byType(Scrollable).first, const Offset(0, 300));

    // Home can open the Expired tab directly
    app.openFoods.value = app.FoodsRequest(1);
    await tester.pumpAndSettle();
    expect(find.text('ALL YOUR FOOD'), findsOneWidget);
    expect(find.textContaining('These passed their date'), findsOneWidget);
  });
}
