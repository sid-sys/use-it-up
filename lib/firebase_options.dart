import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Settings for the Firebase project "use-it-up-app". These values are public by design:
/// they only say which project to talk to. Access is controlled by Firebase rules.
class FirebaseConfig {
  FirebaseConfig._();

  /// Web client id. Android needs it to get a Google ID token.
  static const webClientId = '204898958721-bjebq5st4la25hh89l8gsmbidichkkrv.apps.googleusercontent.com';

  /// iOS client id. iOS needs it to start Google sign-in.
  static const iosClientId = '204898958721-atn5pot83tprnhn3vbilj8rhi4k5nlep.apps.googleusercontent.com';

  static FirebaseOptions get current =>
      defaultTargetPlatform == TargetPlatform.iOS ? _ios : _android;

  static const _android = FirebaseOptions(
    apiKey: 'AIzaSyDt0QLHJtOxKpVxQrIKcvLTXG25uuZaet8',
    appId: '1:204898958721:android:371673207b10576ef83c80',
    messagingSenderId: '204898958721',
    projectId: 'use-it-up-app',
    storageBucket: 'use-it-up-app.firebasestorage.app',
  );

  static const _ios = FirebaseOptions(
    apiKey: 'AIzaSyCmCYYeL6_uThiEYPAgpM8c-b3EScD24yk',
    appId: '1:204898958721:ios:66816a1789047513f83c80',
    messagingSenderId: '204898958721',
    projectId: 'use-it-up-app',
    storageBucket: 'use-it-up-app.firebasestorage.app',
    iosBundleId: 'com.useitup.useItUp',
    iosClientId: iosClientId,
  );
}
