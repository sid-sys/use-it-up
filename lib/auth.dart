import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'firebase_options.dart';

enum AuthProvider { apple, google, email, guest }

/// Sign-in. A MOCK build keeps everything on this phone and makes clearly fake demo
/// accounts, so the whole flow can be tried. A real build uses Firebase Auth for Google
/// and email + password. Apple sign-in is not connected yet. Guest never leaves the phone.
///
/// The screens only call [signIn], [signOut] and [resetPassword].
class Auth extends ChangeNotifier {
  static final Auth instance = Auth._();
  Auth._();

  static String? get email => instance._email;
  static String get displayName => instance._name ?? (instance._email == null ? 'Guest' : instance._email!.split('@').first);
  static bool get signedIn => instance._email != null;

  /// "john.doe42@gmail.com" becomes "John Doe". Used for Google and Apple sign-in.
  static String nameFromEmail(String email) {
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

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _email = p.getString('auth_email');
    _name = p.getString('auth_name');
    final pv = p.getString('auth_provider');
    provider = AuthProvider.values.where((e) => e.name == pv).firstOrNull;
    if (!AppConfig.mock) {
      // Firebase remembers a signed-in person between launches.
      final u = fb.FirebaseAuth.instance.currentUser;
      if (u?.email != null) {
        _email = u!.email;
        _name = _niceName(u);
      } else if (provider != AuthProvider.guest) {
        _email = null;
        _name = null;
      }
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
        if (AppConfig.mock) {
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
        if (!AppConfig.mock) return 'Sign in with Apple is coming soon. Please use Google, email, or continue without an account.';
        final demo = 'demo.apple@example.com';
        return _set(demo, nameFromEmail(demo), p);
      case AuthProvider.google:
        if (AppConfig.mock) {
          final demo = 'demo.google@example.com';
          return _set(demo, nameFromEmail(demo), p);
        }
        return _firebase(() async {
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
          if (token == null) return 'Google did not return a sign-in token. Please try again.';
          final c = await fb.FirebaseAuth.instance.signInWithCredential(fb.GoogleAuthProvider.credential(idToken: token));
          final u = c.user;
          if (u?.email == null) return 'Google did not share an email address.';
          return _set(u!.email, _niceName(u), p);
        });
    }
  }

  /// Sends a password reset email. Returns null on success, or a message.
  Future<String?> resetPassword(String emailAddress) async {
    final e = emailAddress.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) return 'Please enter a valid email address.';
    if (AppConfig.mock) return null;
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
      return switch (e.code) {
        'email-already-in-use' => 'This email already has an account. Choose "I already have an account".',
        'invalid-email' => 'Please enter a valid email address.',
        'weak-password' => 'Password needs at least 6 characters.',
        'wrong-password' || 'invalid-credential' || 'user-not-found' => 'Wrong email or password.',
        'user-disabled' => 'This account has been turned off.',
        'too-many-requests' => 'Too many tries. Please wait a few minutes.',
        'network-request-failed' => 'No internet connection.',
        _ => 'Sign-in failed (${e.code}). Please try again.',
      };
    } catch (_) {
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
    if (!AppConfig.mock) {
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
