# Use It Up: Food Expiry Tracker

Flutter app for Android and iOS. Track food expiry dates by typing or by photo, get reminders,
7-day free trial paywall, and an in-app admin panel.

Made by Tetra Developers. Contact: tetraheaddevelopers@gmail.com.
License: proprietary, all rights reserved (see [LICENSE](LICENSE)).

## Run

```bash
flutter pub get
flutter run                      # MOCK build (default): everyone can open the admin panel
flutter test
flutter analyze
```

Release builds **must** turn mock off:

```bash
flutter build apk --release --dart-define=MOCK=false
flutter build appbundle --release --dart-define=MOCK=false
```

## Where things are

| Path | What |
| --- | --- |
| `lib/config.dart` | Admin email, store prices, store cut, cost numbers, legal URLs, free limits. Edit here. |
| `lib/billing.dart` | Plan state. Local stand-in for RevenueCat. |
| `lib/analytics.dart` | `Analytics.log(type, detail)`. Events are stored on the device. |
| `lib/notifications.dart`, `lib/notification_log.dart` | Local reminders and the log shown in the admin panel. |
| `lib/scan/` | Photo reading (Google ML Kit, on device) and the date parser. |
| `lib/admin/` | Admin panel: models, repository (mock and local), dashboard, users, notifications. |
| `docs/` | Public pages for GitHub Pages: privacy, terms, data deletion. |

## Admin panel security (read this)

Hiding the "Admin panel" button in the app is **not security**. Anyone can unpack an app.

Today the panel shows made-up data (MOCK) or only this phone's own events, so nothing private is exposed.
When real user data is added (Firestore, Cloud Functions or an API), the **server must also check that the
caller is the admin email** (`sidharthbabu9@gmail.com`):

- Firestore rules: allow reading all users only when `request.auth.token.email == 'sidharthbabu9@gmail.com'`
  and `request.auth.token.email_verified == true`.
- Cloud Functions or an API: reject the call unless the verified ID token has that email.

Screens read data only through `AdminRepository` (`lib/admin/repository.dart`), so a real
`FirestoreAdminRepository` can replace the mock without changing any screen.

## Public pages (GitHub Pages)

The `docs/` folder is published at `https://sid-sys.github.io/use-it-up/`:

- Privacy Policy: `/privacy.html`
- Terms of Use: `/terms.html`
- Data deletion URL (for Google Play "Data safety"): `/delete-account.html`

## Payments (App Store and Google Play)

Real builds (`--dart-define=MOCK=false`) use the stores directly through `in_app_purchase`. There is no RevenueCat.

Create these three products. The ids must match `AppConfig.product*` in `lib/config.dart`:

| Id | Type | Price (USD) | Free trial |
|---|---|---|---|
| `monthly` | Auto-renewing subscription | 6.99 | 7 days |
| `yearly` | Auto-renewing subscription | 49.99 | 7 days |
| `lifetime` | Non-consumable (Apple) / One-time product (Google) | 99.00 | none |

- App Store Connect: Monetization > Subscriptions (group `Premium`, add an introductory offer: free, 7 days) and In-App Purchases.
- Google Play Console: Monetize > Subscriptions (one base plan each, plus an offer with a 7-day free trial) and In-app products.

Limits of this setup: the phone asks the store what it owns at every launch. Nothing is verified on our own server, so a rooted phone could fake Premium, and the Admin panel cannot show real revenue. When that matters, add a Cloud Function that verifies receipts with the Apple and Google server APIs.

## Still to do before store release

1. RevenueCat + store products (replace `lib/billing.dart` internals).
2. Firebase project: Auth (Google sign-in), Firestore events, rules that check the admin email.
3. Real app icon and splash. Release signing keys (never commit them).
4. iOS: build with the GitHub Action, then sign and upload with an Apple Developer account.
5. Update the Privacy Policy whenever Firebase, RevenueCat or any server is added.
