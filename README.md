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
| `lib/admin/` | Admin panel: rules (`admin_config.dart`), models, repository (mock and local), dashboard, users, feedback. |
| `firestore.rules` | Server rules for the admin data. Not deployed yet. |
| `docs/` | Public pages for GitHub Pages: privacy, terms, data deletion. |

## Admin panel

Open it from Profile > Admin panel. In a real build only `AppConfig.adminEmail` sees the button.

**What is real today.** The panel reads data only through `AdminRepository` (`lib/admin/repository.dart`).
- A demo build (`MOCK`) shows about 60 made-up accounts: 50 real-looking people and 10 that "Real users only" must hide.
- A real build has no server yet, so it shows only this phone, as one user, and says so. Nothing is made up.

**Real users only.** The switch is on by default. The rules that decide who is hidden are all in
`lib/admin/admin_config.dart` (your email, the store review login, robot email endings, the 25 second rule). Edit that file,
not a screen. Tap "Hiding N accounts" on the dashboard to see each hidden account and the reason.

**Screens.** Dashboard, All users, One user (journey, what they told us, activity), Feedback, Hidden accounts, and a day screen
for installs and uninstalls.

**Events the app records for the panel** (`lib/analytics.dart`): onboarding_started, signed_up (apple, google, email or guest),
heard_from, onboarding_answers, notif_allowed, payment_failed (cancelled, failed, store_unavailable), feedback_sent.
The onboarding has a fourth question, "How did you hear about us?", for the "Where people heard about us" block.

### What is NOT built yet (needs a server)

These need Firebase on the Blaze (pay as you go) plan, with Cloud Functions:

1. **Devices.** The app reports itself once a day to a function that writes one record per phone to `devices`:
   a random install id made on first run, the install time Android reports (`PackageInfo.firstInstallTime`), the owner
   account, the push (FCM) token and last seen. Only the function may write it (see `firestore.rules`).
2. **Uninstalls.** A scheduled function (for example 04:00) sends a dry-run FCM message to every token. Only when Google says
   `UNREGISTERED` or `INVALID_ARGUMENT` is the phone marked uninstalled with that day. If the phone reports in again, remove the mark.
   This works on Android. On iPhone, Apple does not tell apps about deletes.
3. **Money.** A function verifies purchases with the Google Play Developer API and the App Store Server API, and writes the
   payments. Purchases the store marks as test (license testers, sandbox) set `testPurchase` so they are hidden.
4. **Events and users** written to `users/{uid}/events` and read by a `FirestoreAdminRepository`.
5. **Rules.** Deploy `firestore.rules`. It lets only `sidharthbabu9@gmail.com` (verified) read, and nobody write money or devices.

## Security (read this)

Hiding the "Admin panel" button in the app is **not security**. Anyone can unpack an app. When real user data is added the
**server must check the caller**: Firestore rules (`firestore.rules`) and, for any Cloud Function or API, reject the call unless the
verified ID token has the admin email and `email_verified`. The panel is read-only.

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
| `monthly` | Auto-renewing subscription | 4.99 | 7 days |
| `yearly` | Auto-renewing subscription | 39.99 | 7 days |
| `lifetime` | Non-consumable (Apple) / One-time product (Google) | 69.99 | none |

- App Store Connect: Monetization > Subscriptions (group `Premium`, add an introductory offer: free, 7 days) and In-App Purchases.
- Google Play Console: Monetize > Subscriptions (one base plan each, plus an offer with a 7-day free trial) and In-app products.

Limits of this setup: the phone asks the store what it owns at every launch. Nothing is verified on our own server, so a rooted phone could fake Premium, and the Admin panel cannot show real revenue. When that matters, add a Cloud Function that verifies receipts with the Apple and Google server APIs.

## Still to do before store release

1. RevenueCat + store products (replace `lib/billing.dart` internals).
2. Firebase project: Auth (Google sign-in), Firestore events, rules that check the admin email.
3. Real app icon and splash. Release signing keys (never commit them).
4. iOS: build with the GitHub Action, then sign and upload with an Apple Developer account.
5. Update the Privacy Policy whenever Firebase, RevenueCat or any server is added.
