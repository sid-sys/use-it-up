/// All app-wide settings in ONE place. Edit values here, not inside widgets.
class AppConfig {
  /// Mock build: everyone can open the admin panel and it shows made-up data.
  /// Release builds MUST be built with:  flutter build apk --release --dart-define=MOCK=false
  static const bool mock = bool.fromEnvironment('MOCK', defaultValue: true);

  /// The only account that sees "Admin panel" in a real build.
  /// Hiding the button is NOT security. See README: the server must check this too.
  static const adminEmail = 'sidharthbabu9@gmail.com';

  static const developerName = 'Tetra Developers';
  static const contactEmail = 'tetraheaddevelopers@gmail.com';

  // Public pages (GitHub Pages). Needed by App Store and Google Play.
  static const legalBase = 'https://sid-sys.github.io/use-it-up';
  static const privacyUrl = '$legalBase/privacy.html';
  static const termsUrl = '$legalBase/terms.html';
  static const deleteDataUrl = '$legalBase/delete-account.html';

  // Store prices in rupees, copied from the closest competitor (FreshKeeper: $8.99 a month,
  // $19.99 a year) and NoWaste's lifetime price ($29.99), at about Rs 84 per US dollar.
  // The stores show the final local price. Keep in sync with App Store Connect and Play Console.
  // Market check from store listings (US dollars, may have changed): NoWaste Pro $6.99/yr, FreshKeeper $8.99/mo and
  // $19.99/yr, Cooklist $49.99-59.99/yr, Pantry Pal $59.99/yr.
  static const currency = '₹';
  static const monthlyPrice = 749.0;
  static const yearlyPrice = 1699.0;
  static const lifetimePrice = 2499.0;
  static const trialDays = 7;

  /// Share the stores keep. 15% = small business programs. Use 0.30 to be careful.
  static const storeCut = 0.15;

  // ---- Costs, used by the admin dashboard to show honest profit ----
  /// Cost of one cloud AI scan request, in rupees. On-device reading is free.
  static const aiCostPerRequest = 0.30;

  /// Fixed monthly fees in rupees (hosting, backend, tools). Edit to your real bills.
  static const fixedMonthlyCosts = 1500.0;

  // Free plan limits
  static const freeItemLimit = 20;
  static const freeScans = 3;
  static const premiumScansPerMonth = 100;

  static String money(num v) => '$currency${v.round()}';
}
