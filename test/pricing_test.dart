import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:use_it_up/billing.dart';
import 'package:use_it_up/config.dart';

void main() {
  test('prices are in USD', () {
    expect(AppConfig.money(AppConfig.monthlyPrice), r'$6.99');
    expect(AppConfig.money(AppConfig.yearlyPrice), r'$49.99');
    expect(AppConfig.money(AppConfig.lifetimePrice), r'$99');
    expect(AppConfig.money(0), r'$0');
    expect(AppConfig.yearlySavingsPct, 40);
    expect(AppConfig.moneyShort(2893.4), r'$2893');
  });

  test('lifetime is premium with no trial', () async {
    SharedPreferences.setMockInitialValues({});
    final b = Billing();
    await b.subscribe(PlanKind.lifetime);
    expect(b.isPremium, isTrue);
    expect(b.plan, PlanKind.lifetime);
    expect(b.trialUsed, isFalse);
  });
}
