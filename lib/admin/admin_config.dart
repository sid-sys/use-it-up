import '../config.dart';
import 'models.dart';

/// The rules for "Real users only". They live HERE and nowhere else.
/// Edit this file to change who is hidden. No screen has its own rule.
class AdminConfig {
  AdminConfig._();

  /// Your own account. Your taps must not count as customers.
  static const adminEmails = <String>[AppConfig.adminEmail];

  /// The login the store review team uses. Replace with the real login email.
  static const reviewTeamEmails = AppConfig.reviewEmails;

  /// Email endings of robots. Google's Firebase Test Lab uses this one.
  static const robotEmailEndings = <String>['@cloudtestlabaccounts.com'];

  /// "testuser12345@..." looks like a robot sign-up.
  static final robotEmailPattern = RegExp(r'^testuser\d+@', caseSensitive: false);

  /// Nobody can read and answer the onboarding questions faster than this.
  static const minOnboardingSeconds = 25;

  /// Why this account is hidden from the numbers, or null if it is a real person.
  /// The first rule that fits wins. A rule never hides someone silently:
  /// the reason is shown on the hidden-accounts list and on the user row.
  static String? hiddenReason(AdminUser u) {
    final email = u.email.trim().toLowerCase();
    if (email.isNotEmpty && adminEmails.map((e) => e.toLowerCase()).contains(email)) return 'Your own account';
    if (email.isNotEmpty && reviewTeamEmails.map((e) => e.toLowerCase()).contains(email)) return 'Play review login';
    if (robotEmailEndings.any((e) => email.endsWith(e.toLowerCase()))) return 'Google test robot';
    final name = u.name.trim().toLowerCase();
    if (name.isNotEmpty && reviewTeamEmails.map((e) => e.toLowerCase()).contains(name)) return 'Play review robot';
    if (robotEmailPattern.hasMatch(email)) return 'Automated test';
    if (u.testPurchase) return 'Test purchase';
    final secs = u.onboardingSeconds;
    if (secs != null && secs < minOnboardingSeconds) return 'Looks like a robot';
    return null;
  }
}
