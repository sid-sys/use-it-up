import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'notifications.dart';

enum AuthProvider { apple, google, email, guest }

/// Sign-in. A MOCK build keeps everything on this phone and makes clearly fake demo
/// accounts, so the whole flow can be tried. A real build uses Firebase Auth for Google
/// and email + password. Apple sign-in is not connected yet. Guest never leaves the phone.
///
/// The screens only call [signIn], [signOut] and [resetPassword].
class Auth extends ChangeNotifier {
  static final Auth instance = Auth._();
  Auth._();

  /// Only the automatic tests turn this on: they cannot reach Firebase, so they get a pretend account.
  /// A demo build on a phone does NOT use it. Sign-in is always real.
  static bool demoSignIn = const bool.fromEnvironment('DEMO_SIGNIN'); // build with --dart-define=DEMO_SIGNIN=true only to test on a phone

  static String? get email => instance._email;
  static String get displayName => instance._name ?? (instance._email == null ? 'Guest' : instance._email!.split('@').first);
  static bool get signedIn => instance._email != null;

  /// "john.doe42@gmail.com" becomes "John Doe". Used for Google and Apple sign-in.
  static String nameFromEmail(String email) {
    if (email.toLowerCase().endsWith('@privaterelay.appleid.com')) return 'Friend'; // hidden Apple address
    final local = email.split('@').first;
    final words = local
        .replaceAll(RegExp(r'[0-9]'), '')
        .split(RegExp(r'[._\-+]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .toList();
    return words.isEmpty ? 'Friend' : words.join(' ');
  }

  String? _email;
  String? _name;
  AuthProvider? provider;
  bool _googleReady = false;

  bool _listening = false;

  /// Firebase tells us the moment a sign-in finishes, even when the browser page of an Apple sign-in
  /// stays open and never sends the person back. The app then moves on by itself.
  void _listenToFirebase() {
    if (_listening || demoSignIn) return;
    _listening = true;
    fb.FirebaseAuth.instance.authStateChanges().listen((u) async {
      final signed = u != null && !u.isAnonymous;
      debugPrint('AUTH state changed: signed=$signed email=${u?.email} providers=${u?.providerData.map((p) => p.providerId).toList()}');
      if (signed && (_email == null || _email != (u.email ?? 'Apple account'))) {
        final id = u.providerData.map((p) => p.providerId).firstWhere((_) => true, orElse: () => '');
        final p = id == 'apple.com' ? AuthProvider.apple : (id == 'google.com' ? AuthProvider.google : AuthProvider.email);
        await _set(u.email ?? 'Apple account', _niceName(u), p);
        // The browser page of an Apple sign-in can stay in front. Say so, and make it one tap to come back.
        if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
          unawaited(Notifier.showNow('✅ You are signed in. Tap here to go back to the app.'));
        }
      } else if (!signed && _email != null) {
        await signOut();
      }
    });
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _email = p.getString('auth_email');
    _name = p.getString('auth_name');
    final pv = p.getString('auth_provider');
    provider = AuthProvider.values.where((e) => e.name == pv).firstOrNull;
    if (!demoSignIn) {
      // Firebase remembers a signed-in person between launches. No account means signed out:
      // there are no guest accounts any more.
      final u = fb.FirebaseAuth.instance.currentUser;
      if (u != null && !u.isAnonymous) {
        _email = u.email ?? 'Apple account';
        _name = _niceName(u);
      } else {
        _email = null;
        _name = null;
        provider = null;
      }
      _listenToFirebase();
    }
    notifyListeners();
  }

  String _niceName(fb.User u) {
    final n = (u.displayName ?? '').trim();
    return n.isNotEmpty ? n : nameFromEmail(u.email ?? '');
  }

  /// Returns null on success, or a short message to show the user.
  /// [password] and [createAccount] are used by email sign-in in a real build.
  Future<String?> signIn(AuthProvider p, {String? emailAddress, String? name, String? password, bool createAccount = true}) async {
    switch (p) {
      case AuthProvider.guest:
        return _set(null, null, p);
      case AuthProvider.email:
        final e = (emailAddress ?? '').trim();
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) return 'Please enter a valid email address.';
        if (demoSignIn) {
          if ((name ?? '').trim().isEmpty) return 'Please enter your name.';
          return _set(e, name!.trim(), p);
        }
        if (createAccount && (name ?? '').trim().isEmpty) return 'Please enter your name.';
        if ((password ?? '').length < 6) return 'Password needs at least 6 characters.';
        return _firebase(() async {
          final auth = fb.FirebaseAuth.instance;
          if (createAccount) {
            final c = await auth.createUserWithEmailAndPassword(email: e, password: password!);
            await c.user?.updateDisplayName(name!.trim());
            return _set(e, name!.trim(), p);
          }
          final c = await auth.signInWithEmailAndPassword(email: e, password: password!);
          return _set(e, c.user == null ? nameFromEmail(e) : _niceName(c.user!), p);
        });
      case AuthProvider.apple:
        if (demoSignIn) {
          const demo = 'demo.apple@example.com';
          return _set(demo, nameFromEmail(demo), p);
        }
        return _firebase(() async {
          debugPrint('AUTH apple: starting');
          final c = await fb.FirebaseAuth.instance.signInWithProvider(_appleProvider());
          debugPrint('AUTH apple: finished, user=${c.user?.email}');
          final u = c.user;
          if (u == null) return 'Apple did not complete the sign-in. Please try again.';
          return _set(u.email ?? 'Apple account', _niceName(u), p);
        });
      case AuthProvider.google:
        if (demoSignIn) {
          final demo = 'demo.google@example.com';
          return _set(demo, nameFromEmail(demo), p);
        }
        return _firebase(() async {
          final cred = await _googleCredential();
          if (cred == null) return 'Google did not return a sign-in token. Please try again.';
          final c = await fb.FirebaseAuth.instance.signInWithCredential(cred);
          final u = c.user;
          if (u?.email == null) return 'Google did not share an email address.';
          return _set(u!.email, _niceName(u), p);
        });
    }
  }

  fb.AppleAuthProvider _appleProvider() => fb.AppleAuthProvider()
    ..addScope('email')
    ..addScope('name');

  Future<fb.AuthCredential?> _googleCredential() async {
    final g = GoogleSignIn.instance;
    if (!_googleReady) {
      await g.initialize(
        clientId: defaultTargetPlatform == TargetPlatform.iOS ? FirebaseConfig.iosClientId : null,
        serverClientId: FirebaseConfig.webClientId,
      );
      _googleReady = true;
    }
    final account = await g.authenticate();
    final token = account.authentication.idToken;
    return token == null ? null : fb.GoogleAuthProvider.credential(idToken: token);
  }

  /// True when the signed-in account uses an email and password. The delete screen then
  /// asks for the password again, which is the safe way to confirm.
  static bool get usesPassword {
    if (demoSignIn) return false;
    final u = fb.FirebaseAuth.instance.currentUser;
    return u != null && u.providerData.any((p) => p.providerId == 'password');
  }

  /// Deletes the account from Firebase, then signs out on this phone.
  /// The person is asked to confirm again (password, Google or Apple) because Firebase
  /// only deletes an account after a fresh sign-in. Returns null on success, or a message.
  /// Guests and demo builds have no cloud account, so this just signs out.
  Future<String?> deleteAccount({String? password}) async {
    if (demoSignIn) {
      await signOut();
      return null;
    }
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) {
      await signOut();
      return null;
    }
    final result = await _firebase(() async {
      final ids = user.providerData.map((p) => p.providerId).toSet();
      String? appleCode;
      if (ids.contains('password')) {
        if ((password ?? '').isEmpty) return 'Please enter your password to confirm.';
        await user.reauthenticateWithCredential(fb.EmailAuthProvider.credential(email: user.email!, password: password!));
      } else if (ids.contains('google.com')) {
        final cred = await _googleCredential();
        if (cred == null) return 'Google did not confirm it is you. Please try again.';
        await user.reauthenticateWithCredential(cred);
      } else if (ids.contains('apple.com')) {
        final r = await user.reauthenticateWithProvider(_appleProvider());
        appleCode = r.additionalUserInfo?.authorizationCode;
      }
      if (appleCode != null) {
        // Apple asks apps to cancel the Apple sign-in link when the account is deleted.
        try {
          await fb.FirebaseAuth.instance.revokeTokenWithAuthorizationCode(appleCode);
        } catch (_) {}
      }
      await user.delete();
      return null;
    });
    if (result == null) await signOut();
    return result;
  }

  /// Sends a password reset email. Returns null on success, or a message.
  Future<String?> resetPassword(String emailAddress) async {
    final e = emailAddress.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) return 'Please enter a valid email address.';
    if (demoSignIn) return null;
    return _firebase(() async {
      await fb.FirebaseAuth.instance.sendPasswordResetEmail(email: e);
      return null;
    });
  }

  Future<String?> _firebase(Future<String?> Function() run) async {
    try {
      return await run();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return 'Sign-in was cancelled.';
      return 'Google sign-in failed. Please try again.';
    } on fb.FirebaseAuthException catch (e) {
      debugPrint('AUTH error: code=${e.code} message=${e.message}');
      return switch (e.code) {
        'email-already-in-use' => 'This email already has an account. Choose "I already have an account".',
        'invalid-email' => 'Please enter a valid email address.',
        'weak-password' => 'Password needs at least 6 characters.',
        'wrong-password' || 'invalid-credential' || 'user-not-found' => 'Wrong email or password.',
        'canceled' || 'web-context-canceled' => 'Sign-in was cancelled.',
        'user-disabled' => 'This account has been turned off.',
        'too-many-requests' => 'Too many tries. Please wait a few minutes.',
        'network-request-failed' => 'No internet connection.',
        _ => 'Sign-in failed (${e.code}). Please try again.',
      };
    } catch (e) {
      debugPrint('AUTH unexpected error: $e');
      return 'Something went wrong. Please try again.';
    }
  }

  Future<String?> _set(String? email, String? name, AuthProvider p) async {
    _email = email;
    _name = name;
    provider = p;
    final prefs = await SharedPreferences.getInstance();
    if (email == null) {
      await prefs.remove('auth_email');
    } else {
      await prefs.setString('auth_email', email);
    }
    if (name == null) {
      await prefs.remove('auth_name');
    } else {
      await prefs.setString('auth_name', name);
    }
    await prefs.setString('auth_provider', p.name);
    notifyListeners();
    return null;
  }

  Future<void> signOut() async {
    if (!demoSignIn) {
      try {
        await fb.FirebaseAuth.instance.signOut();
        if (_googleReady) await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    _email = null;
    _name = null;
    provider = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_email');
    await prefs.remove('auth_name');
    await prefs.remove('auth_provider');
    notifyListeners();
  }
}
