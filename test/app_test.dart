import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:use_it_up/main.dart' as app;
import 'package:use_it_up/billing.dart';
import 'package:use_it_up/store.dart';

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

  test('app entrypoint compiles', () => expect(app.UseItUpApp, isNotNull));
}
