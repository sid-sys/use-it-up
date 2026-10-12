import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

enum AuthProvider { apple, google, email, guest }

/// Sign-in. Today this is LOCAL ONLY: it remembers who tapped what on this phone.
/// Real Apple / Google / email sign-in needs Firebase Auth. When that is added, replace
/// the bodies of [signIn] and [signOut]; the screens only call these two methods.
///
/// In a MOCK build, Apple and Google create a clearly fake demo account so the whole
/// flow can be tried. In a real build they refuse, so nobody is told they are signed in
/// when they are not.
class Auth extends ChangeNotifier {
  static final Auth instance = Auth._();
  Auth._();

  static String? get email => instance._email;
  static String get displayName => instance._name ?? (instance._email == null ? 'Guest' : instance._email!.split('@').first);
  static bool get signedIn => instance._email != null;

  String? _email;
  String? _name;
  AuthProvider? provider;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _email = p.getString('auth_email');
    _name = p.getString('auth_name');
    final pv = p.getString('auth_provider');
    provider = AuthProvider.values.where((e) => e.name == pv).firstOrNull;
    notifyListeners();
  }

  /// Returns null on success, or a short message to show the user.
  Future<String?> signIn(AuthProvider p, {String? emailAddress}) async {
    switch (p) {
      case AuthProvider.guest:
        return _set(null, null, p);
      case AuthProvider.email:
        final e = (emailAddress ?? '').trim();
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) return 'Please enter a valid email address.';
        // Real build: send a one-time code or link here, and sign in only after it is confirmed.
        if (!AppConfig.mock) return 'Email sign-in is not connected yet. You can continue without an account.';
        return _set(e, null, p);
      case AuthProvider.apple:
      case AuthProvider.google:
        if (!AppConfig.mock) return 'Sign-in with ${p == AuthProvider.apple ? 'Apple' : 'Google'} is not connected yet. You can continue without an account.';
        return _set('demo.${p.name}@example.com', 'Demo user', p);
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
