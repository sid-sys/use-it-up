import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:use_it_up/main.dart' as app;
import 'package:use_it_up/sample_data.dart';
import 'package:use_it_up/models.dart';

Future<void> loadFonts() async {
  for (final (family, path) in [('Anton', 'assets/fonts/Anton-Regular.ttf'), ('Inter', 'assets/fonts/Inter.ttf')]) {
    final loader = FontLoader(family)..addFont(File(path).readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

void main() {
  test('sample foods cover every group', () {
    final s = sampleFoods();
    int count(ShelfGroup g) => s.where((i) => i.daysLeft() >= 0 && shelfGroupOf(i.daysLeft()) == g).length;
    expect(count(ShelfGroup.eatFirst), greaterThanOrEqualTo(8));
    expect(count(ShelfGroup.stillFresh), greaterThanOrEqualTo(15));
    expect(count(ShelfGroup.longKeepers), greaterThanOrEqualTo(8));
    expect(s.where((i) => i.isExpired).length, 2);
    expect(s.every((i) => i.id.startsWith('sample_')), isTrue);
  });

  testWidgets('Load sample foods fills Home, Remove puts it back', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);
    SharedPreferences.setMockInitialValues({'onboarded': true});

    await tester.runAsync(() => app.main());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1800)));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('YOUR FRIDGE IS EMPTY'), findsOneWidget);
    final btn = find.text('Load sample foods (demo)');
    await tester.ensureVisible(btn);
    await tester.tap(btn);
    await tester.pumpAndSettle();

    expect(app.store.fresh.length, greaterThan(30));
    expect(find.text('Eat me first'), findsOneWidget);
    expect(find.text('fresh spinach'), findsOneWidget);

    final remove = find.text('Remove sample foods (demo)');
    await tester.dragUntilVisible(remove, find.byType(Scrollable).first, const Offset(0, -300));
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(app.store.activeAll, isEmpty);
    expect(find.text('YOUR FRIDGE IS EMPTY'), findsOneWidget);
  });
}
