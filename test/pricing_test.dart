import 'package:flutter_test/flutter_test.dart';
import 'package:use_it_up/config.dart';

void main() {
  test('prices are in USD and yearly is 75% off', () {
    expect(AppConfig.money(AppConfig.monthlyPrice), r'$6.99');
    expect(AppConfig.money(AppConfig.yearlyPrice), r'$20.99');
    expect(AppConfig.money(0), r'$0');
    expect(AppConfig.yearlySavingsPct, 75);
    expect(AppConfig.moneyShort(2893.4), r'$2893');
  });
}
