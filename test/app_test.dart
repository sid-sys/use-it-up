import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:use_it_up/main.dart' as app;
import 'package:use_it_up/billing.dart';
import 'package:use_it_up/store.dart';
import 'package:use_it_up/admin/models.dart';
import 'package:use_it_up/admin/repository.dart';

void main() {
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
      await b.subscribe(PlanKind.yearly);
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
