# Use It Up: Food Expiry Tracker

Flutter app for Android and iOS. Track food expiry dates by typing or by photo, get reminders,
7-day free trial paywall, and an in-app admin panel.

Made by Tetra Developers. Contact: tetraheaddevelopers@gmail.com.
License: proprietary, all rights reserved (see [LICENSE](LICENSE)).

## Run

```bash
flutter pub get
flutter run                      # real sign-in and real payments. There is no demo mode.
flutter test
flutter analyze
```

Every build is real: sign-in goes to Firebase and payments go to the stores. The Admin panel and the
testing buttons show only for the owner (`AppConfig.adminEmail`). The automatic tests get pretend payments and a
pretend sign-in from `test/flutter_test_config.dart`; the app never turns those on by itself.

```bash
flutter build apk --release
flutter build appbundle --release
```

## Review login (App Store and Google Play)

Reviewers must be able to open the whole app without paying. `AppConfig.reviewEmails` lists the review login(s).
A person who signs in with one of them gets Premium for free, with no food limit and no Cancel button.

1. Firebase console > Authentication > Users > **Add user**. Email: the one in `AppConfig.reviewEmails`
   (today `tetraheaddevelopers+review@gmail.com`). Choose a strong password.
2. Keep that account: if it is deleted, anyone could register the same email and get free Premium.
3. App Store Connect > App Review Information: tick **Sign-in required**, enter the email and password.
   Google Play Console > App content > **App access**: add the same login and instructions.
4. The review login is also left out of the Admin panel numbers (`AdminConfig.reviewTeamEmails`).
5. Reviewers still see the paywall during onboarding and can test a purchase with the store's sandbox.

## Where things are

| Path | What |
| --- | --- |
| `lib/config.dart` | Admin email, store prices, store cut, cost numbers, legal URLs, free limits. Edit here. |
| `lib/billing.dart` | Plan state. Local stand-in for RevenueCat. |
| `lib/analytics.dart` | `Analytics.log(type, detail)`. Events are stored on the device. |
| `lib/notifications.dart`, `lib/notification_log.dart` | Local reminders and the log shown in the admin panel. |
| `lib/scan/` | Photo reading (Google ML Kit, on device) and the date parser. |
| `lib/admin/` | Admin panel: rules (`admin_config.dart`), models, repository, dashboard, users, feedback. |
| `firestore.rules` | Server rules for the admin data. Not deployed yet. |
| `docs/` | Public pages for GitHub Pages: privacy, terms, data deletion. |

## Admin panel

Open it from Profile > Admin panel. In a real build only `AppConfig.adminEmail` sees the button.

**What is real today.** The panel reads data only through `AdminRepository` (`lib/admin/repository.dart`).
- The app contains no made-up data. The tests carry their own made-up accounts (`test/support/mock_admin_repository.dart`).
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

## Where installs come from (Android)

The app reads the **Google Play Install Referrer** the first time it opens (`lib/install_info.dart`, `MainActivity.kt`, library
`com.android.installreferrer:installreferrer`). The method in the old Medium article (a broadcast receiver for
`com.android.vending.INSTALL_REFERRER`) was switched off by Google on 1 March 2020, so it is not used.

- A link with a referrer: `https://play.google.com/store/apps/details?id=com.useitup.use_it_up&referrer=utm_source%3Dinstagram%26utm_medium%3Dbio%26utm_campaign%3Dlaunch`
- A search inside Google Play gives `utm_source=google-play&utm_medium=organic`.
- The result is saved on the phone, logged as the event `install_source`, and shown in the Admin panel under "Came from".
- Google answers once per install and keeps the answer 90 days. The same call also gives the real install time
  (`firstInstallTime`) that the Admin panel uses for the Installs chart.
- **How to test:** it only works for an app installed from Google Play. Upload a build to Internal testing, add yourself as a tester,
  open the link above on a phone that does not have the app, install, open it, then look at Profile > Admin panel > your user.
  A file installed with adb has no Play link, so it shows nothing. The old `adb shell am broadcast` test no longer works.
- iPhone: Apple gives no install link to apps, so nothing is recorded there.

## iOS signing (permanent)

The TestFlight build uses one fixed Apple Distribution certificate and one App Store profile, so it never creates new
certificates (Apple limits them). They live as GitHub secrets: `IOS_CERT_P12_BASE64`, `IOS_CERT_PASSWORD`, `IOS_PROFILE_BASE64`,
plus `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `APPLE_TEAM_ID`.

1. Make a certificate request: `openssl req -new -newkey rsa:2048 -nodes -keyout distribution.key -out distribution.csr`.
2. developer.apple.com > Certificates > + > **Apple Distribution** > upload the .csr > download `distribution.cer`.
3. Profiles > + > **App Store Connect** > App ID `com.useitup.useItUp` > the new certificate > download the .mobileprovision.
4. Put both files next to the key and run a script that builds the .p12 and the three base64 secrets.
5. Keep `distribution.key` safe (it cannot be recreated). The certificate lasts one year: renew it before it ends.

## Public pages (GitHub Pages)

The `docs/` folder is published at `https://sid-sys.github.io/use-it-up/`:

- Privacy Policy: `/privacy.html`
- Terms of Use: `/terms.html`
- Data deletion URL (for Google Play "Data safety"): `/delete-account.html`

## Payments (App Store and Google Play)

The app uses the stores directly through `in_app_purchase`. There is no RevenueCat.

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
