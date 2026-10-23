import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:use_it_up/analytics.dart';
import 'package:use_it_up/install_info.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reading the install link', () {
    test('a campaign link: source, medium and campaign', () {
      const i = InstallInfo(referrer: 'utm_source=instagram&utm_medium=bio&utm_campaign=launch%20week');
      expect(i.source, 'instagram');
      expect(i.medium, 'bio');
      expect(i.campaign, 'launch week');
      expect(i.label, 'instagram / bio / launch week');
    });

    test('a search in Google Play has no link: Google says google-play and organic', () {
      const i = InstallInfo(referrer: 'utm_source=google-play&utm_medium=organic');
      expect(i.label, 'google-play / organic');
    });

    test('"(not set)", an empty link and no link all mean: nothing known', () {
      expect(const InstallInfo(referrer: 'utm_source=(not set)&utm_medium=(not set)').label, isNull);
      expect(const InstallInfo(referrer: '').label, isNull);
      expect(const InstallInfo().label, isNull);
      expect(const InstallInfo(referrer: '%%%not a link').utm, isEmpty);
    });

    test('Google Play is the installer', () {
      expect(const InstallInfo(installer: 'com.android.vending').fromGooglePlay, isTrue);
      expect(const InstallInfo(installer: 'com.sec.android.app.samsungapps').fromGooglePlay, isFalse);
      expect(const InstallInfo().fromGooglePlay, isFalse);
    });

    test('it survives being saved and read back', () {
      final i = InstallInfo(
        referrer: 'utm_source=x&utm_medium=y',
        firstInstallTime: DateTime(2026, 10, 1, 9),
        clickTime: DateTime(2026, 10, 1, 8, 59),
        installer: 'com.android.vending',
      );
      final back = InstallInfo.fromJson(i.toJson());
      expect(back.referrer, i.referrer);
      expect(back.firstInstallTime, i.firstInstallTime);
      expect(back.clickTime, i.clickTime);
      expect(back.installer, i.installer);
    });

    test('what the Android code returns is understood', () {
      final i = InstallInfo.fromChannel({
        'referrer': 'utm_source=tiktok&utm_medium=video',
        'firstInstallTime': DateTime(2026, 10, 2).millisecondsSinceEpoch,
        'clickSeconds': DateTime(2026, 10, 1).millisecondsSinceEpoch ~/ 1000,
        'installer': 'com.android.vending',
      });
      expect(i.label, 'tiktok / video');
      expect(i.firstInstallTime, DateTime(2026, 10, 2));
      expect(i.clickTime, DateTime(2026, 10, 1));
      expect(i.error, isNull);
    });
  });

  group('collecting it on Android', () {
    const channel = MethodChannel('useitup/install');

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({});
      Analytics.instance.events.clear();
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    test('it asks Android once, records the source, and remembers the answer', () async {
      var asked = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        asked++;
        return {'referrer': 'utm_source=facebook&utm_medium=ad', 'installer': 'com.android.vending'};
      });
      final first = await InstallInfo.collect();
      expect(first?.label, 'facebook / ad');
      expect(Analytics.instance.events.where((e) => e.type == Ev.installSource).map((e) => e.detail), ['facebook / ad']);
      final second = await InstallInfo.collect();
      expect(second?.label, 'facebook / ad');
      expect(asked, 1, reason: 'Google answers once per install, so the app does not ask again');
      expect(Analytics.instance.events.where((e) => e.type == Ev.installSource).length, 1);
    });

    test('if Google could not answer yet, it tries again next time', () async {
      var asked = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        asked++;
        return {'referrerError': 1}; // the Play service was not available
      });
      await InstallInfo.collect();
      await InstallInfo.collect();
      expect(asked, 2);
    });

    test('a broken answer never crashes the app', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'boom');
      });
      expect(await InstallInfo.collect(), isNull);
    });

    test('on iPhone and the web it does nothing', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var asked = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        asked++;
        return {};
      });
      expect(await InstallInfo.collect(), isNull);
      expect(asked, 0);
    });
  });
}
