import 'dart:async';
import 'package:use_it_up/auth.dart';
import 'package:use_it_up/config.dart';

/// Runs before every test file. The tests cannot reach the App Store, Google Play or Firebase, so they
/// get pretend payments and a pretend sign-in. The real app never turns these on.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppConfig.mock = true;
  Auth.demoSignIn = true;
  await testMain();
}
