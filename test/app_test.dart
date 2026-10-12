import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:use_it_up/main.dart' as app;
import 'package:use_it_up/billing.dart';
import 'package:use_it_up/scan/parser.dart';
import 'package:use_it_up/store.dart';
import 'package:use_it_up/admin/models.dart';
import 'package:use_it_up/admin/repository.dart';

void main() {
  group('label parser', () {
    test('reads EXP date and product name', () {
      final r = parseLabel(['Fresh Whole Milk', 'MFG 01/10/26', 'EXP 12/11/26', 'Batch 99812']);
      expect(r.name, 'Fresh Whole Milk');
      expect(r.dates.first.date, DateTime(2026, 11, 12));
      expect(r.dates.first.type, 'use_by');
      expect(r.dates.first.ambiguous, isTrue);
      expect(r.dates.any((d) => d.date == DateTime(2026, 10, 1)), isFalse, reason: 'MFG ignored');
    });

    test('reads named month and month-year', () {
      expect(parseLabel(['BEST BEFORE 15 NOV 2026']).dates.first.date, DateTime(2026, 11, 15));
      expect(parseLabel(['BB 03/2027']).dates.first.date, DateTime(2027, 3, 31));
    });

    test('no date means no guess', () {
      expect(parseLabel(['Tasty Bread', 'Keep cool']).dates, isEmpty);
    });
  });

  group('store', () {
    test('free limits and trial unlock', () async {
      SharedPreferences.setMockInitialValues({});
      final b = Billing();
      final s = Store(b);
      await s.load();
      expect(s.canScan, isTrue);
      for (var i = 0; i < 3; i++) {
        await s.recordScan();
      }
      expect(s.canScan, isFalse);
      await b.subscribe(annual: true);
      expect(b.isPremium, isTrue);
      expect(s.canScan, isTrue);
      expect(b.trialDaysLeft, 7);
    });
  });

  test('mock admin data is stable and sensible', () async {
    final a = await MockAdminRepository().loadUsers();
    final b = await MockAdminRepository().loadUsers();
    expect(a.length, 50);
    expect(a.map((u) => u.email).toList(), b.map((u) => u.email).toList());
    final s = AdminStats.from(a, DateTime.now());
    expect(s.funnel[0], 50);
    for (var i = 1; i < s.funnel.length; i++) {
      expect(s.funnel[i], lessThanOrEqualTo(s.funnel[i - 1]));
    }
    expect(s.dau14.length, 14);
    expect(s.revenueTotal, greaterThan(0));
    expect(s.profitAfter, lessThanOrEqualTo(s.profitBefore));
  });

  test('app entrypoint compiles', () => expect(app.UseItUpApp, isNotNull));
}
