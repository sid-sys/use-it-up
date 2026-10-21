import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:use_it_up/billing.dart';
import 'package:use_it_up/models.dart';
import 'package:use_it_up/store.dart';

FoodItem food(String id, String name, int days, {DateTime? usedAt}) {
  final d = DateTime.now().add(Duration(days: days));
  return FoodItem(
    id: id,
    name: name,
    expiry: DateTime(d.year, d.month, d.day),
    used: usedAt != null,
    usedAt: usedAt,
  );
}

void main() {
  test('used foods are removed after 24 hours', () async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'items': jsonEncode([
        food('a', 'Milk', 3).toJson(),
        food('b', 'Eggs', 5, usedAt: now.subtract(const Duration(hours: 2))).toJson(),
        food('c', 'Bread', 2, usedAt: now.subtract(const Duration(hours: 30))).toJson(),
      ]),
    });
    final s = Store(Billing());
    await s.load();
    expect(s.usedItems.map((i) => i.name), ['Eggs'], reason: 'the one used 30 hours ago is gone');
    expect(s.activeAll.map((i) => i.name), ['Milk']);
    expect(s.usedCount, 1, reason: 'removed for good, not only hidden');

    // Marking a food as used keeps it for the next 24 hours, so Undo works.
    await s.markUsed(s.activeAll.first);
    expect(s.usedItems.length, 2);
  });

  test('a new food goes to the card it belongs to', () {
    expect(groupFor(food('1', 'Spinach', 0)), ShelfGroup.eatFirst);
    expect(groupFor(food('2', 'Cheese', 14)), ShelfGroup.stillFresh);
    expect(groupFor(food('3', 'Rice', 200)), ShelfGroup.longKeepers);
    expect(groupFor(food('4', 'Old milk', -2)), ShelfGroup.checkBeforeToss);
  });

  test('restart onboarding keeps the food', () async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'items': jsonEncode([food('a', 'Milk', 3).toJson()]),
    });
    final s = Store(Billing());
    await s.load();
    expect(s.onboarded, isTrue);
    await s.restartOnboarding();
    expect(s.onboarded, isFalse);
    expect(s.onbStep, 0);
    expect(s.activeAll.length, 1);
  });
}
