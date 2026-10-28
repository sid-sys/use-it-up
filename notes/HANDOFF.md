# Use It Up: handoff and to-do list

Written 28 Oct 2026. This repo is PUBLIC. Never write passwords, keys or tokens in this file.

## State today

| Store | Version | State |
|---|---|---|
| Apple App Store | 1.0.0 (build 17) | Submitted on 23 Oct 2026. Waiting for Review. Items: app, Lifetime, Monthly, Yearly, group "Use it up Premium". |
| Google Play | 1.0.0 (version code 5) | Bundle is built: `release/useitup-1.0.0-5.aab`. NOT uploaded yet. |

Latest code is on `main`. `pubspec.yaml` says `1.0.0+5`.

## Things only the owner can do (not done yet)

1. **Firebase users.** Delete 3 test users by hand (Firebase Console > Authentication > Users): `testuser98721@gmail.com`, `testuser123@gmail.com`, `sidharthbabu96@gmail.com`. Keep the admin (`sidharthbabu9@gmail.com`) and `review@gmail.com`. The Firebase CLI cannot delete users.
2. **Review login.** `review@gmail.com` exists in Firebase. Its password is only in Firebase, App Store Connect (App Review Information) and Play Console (App content > App access). Check all three match. Never delete this user.
3. **Google Play upload.** Upload `release/useitup-1.0.0-5.aab` to a testing track, then production. Fill: store listing (icon, feature graphic, screenshots, descriptions), App access, Data safety, Content rating, Target audience.
4. **Play products.** Subscription `use_it_up_pro` has base plans `monthly-plan` (US$4.99) and `yearly-plan-2` (US$39.99, yearly). Each has a `trial` offer (7 days). The old `yearly-plan` was monthly by mistake: deactivate it. In-app product `lifetime` (US$69.99) is done. The app finds each plan by billing period (P1M, P1Y), so plan names do not matter (see `lib/billing.dart`, `_pick`).
5. **Play license testing.** Setup > License testing: add the tester Gmail so test purchases are free.
6. **Play App Signing SHA-1 and SHA-256** were added to Firebase on 23 Oct 2026. Google sign-in for Play installs may need a few hours to start working. Retest after installing from Play.

## Tests still to do (nothing below has been proven)

- **Real purchases.** Buy monthly, yearly and lifetime on Android (license tester) and on iPhone (TestFlight sandbox). Check: price shows in local currency, 7-day trial starts, Premium turns on, Restore purchases works, trial reminder arrives.
- **Google sign-in from a Play install.** First tries gave "Sign-in did not finish". Likely timing (see item 6). The app now logs `AUTH google error` in `adb logcat` with the real code.
- **Apple sign-in on iPhone.** Works in TestFlight? Apple on Android is hidden on purpose.
- **Email sign-in and the review login** on both platforms. Review login must give Premium without paying.
- **Notifications** on a real iPhone (tested on Android only).
- **Admin panel data is this phone only.** `LocalAdminRepository` is the only one. A server (Firestore) is needed for real user and revenue numbers. `firestore.rules` exists but is NOT deployed.
- **Install source tracking** (Play Install Referrer): test with a link that has a `referrer=` value.

## Known gaps and ideas

- Privacy page (`docs/privacy.html`) was updated 23 Oct 2026 for ML Kit and no guests. Re-check it against the Data safety form and Apple App Privacy.
- Account deletion page: `docs/delete-account.html`. The app also has "Delete my account".
- Old copy of the project at `C:\Users\sidha\.gemini\antigravity\scratch\useitup` can be deleted.
- Unity CLI note from the tool: not related to this project.

## How to work on another computer or account

1. Clone: `git clone https://github.com/sid-sys/use-it-up.git`, then `flutter pub get`.
2. **Not in git (by design). Copy them by hand from `D:\SCRATCH\useitup`:**
   - `signing/` (Android upload keystore `upload-keystore.jks`, Apple certificate and profile, helper scripts)
   - `android/key.properties` (points at the keystore; fix the path on the new machine)
   - `release/` (finished `.aab` files)
   - `store_screenshots/` can be rebuilt: `flutter test tool/store_shots/make_store_shots_test.dart`
3. Without `key.properties`, release builds fall back to the debug key. Google Play will reject those. Do not lose the upload keystore.
4. GitHub secrets (already set, owner `sid-sys`): the Apple signing certificate, profile and App Store Connect API key used by `.github/workflows/ios-testflight.yml`. The workflow number is the iOS build number (last: 17).
5. Firebase project: `use-it-up-app`. Android app id `1:204898958721:android:371673207b10576ef83c80`. Sign in with the Google account that owns it.
6. Admin email is in `lib/config.dart` (`adminEmail`). Review emails: `reviewEmails`.

## Commands

```
flutter test                                              # 55 tests
flutter build appbundle --release                         # Play bundle (raise version code in pubspec.yaml first)
gh workflow run ios-testflight.yml                        # iOS build to TestFlight (about 15 minutes)
flutter test tool/store_shots/make_store_shots_test.dart  # store screenshots
```

Every Play upload needs a higher version code than before. Next is `+6`.

See also: `README.md` (payments, review login, admin, iOS signing, install source) and `notes/ADMIN_PANEL_PROMPT.md`.
