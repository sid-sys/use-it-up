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

  // Store prices in US dollars. Apple and Google convert them to local currency (for
  // example INR) when you set up the products, so the app only needs the dollar prices.
  // Yearly is 75% off twelve months of the monthly price: 12 x 6.99 = 83.88, 25% of that is
  // 20.97, and 20.99 is the nearest normal store price point.
  // Market check from store listings (may have changed): NoWaste Pro $6.99/yr, FreshKeeper
  // $8.99/mo and $19.99/yr, Cooklist $49.99-59.99/yr, Pantry Pal $59.99/yr.
  static const currency = '\$';
  static const monthlyPrice = 6.99;
  static const yearlyPrice = 20.99;
  static const lifetimePrice = 29.99; // not shown in the app yet
  static const trialDays = 7;

  /// Share the stores keep. 15% = small business programs. Use 0.30 to be careful.
  static const storeCut = 0.15;

  // ---- Costs, used by the admin dashboard to show honest profit ----
  /// Cost of one cloud AI scan request, in US dollars. On-device reading is free.
  static const aiCostPerRequest = 0.004;

  /// Fixed monthly fees in US dollars (hosting, backend, tools). Edit to your real bills.
  static const fixedMonthlyCosts = 20.0;

  // Free plan limits
  static const freeItemLimit = 20;
  static const freeScans = 3;
  static const premiumScansPerMonth = 100;

  /// Whole dollars show as $7, others as $6.99.
  static String money(num v) => v == v.roundToDouble() ? '$currency${v.round()}' : '$currency${v.toStringAsFixed(2)}';

  /// Whole dollars only. For totals on the admin dashboard.
  static String moneyShort(num v) => '$currency${v.round()}';

  /// How much cheaper yearly is than twelve months of monthly, in percent.
  static int get yearlySavingsPct => ((1 - yearlyPrice / (monthlyPrice * 12)) * 100).round();
}
