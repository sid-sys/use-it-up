/// Placeholder for sign-in. Firebase Auth (Google sign-in) will fill [email] later.
/// Until then nobody is signed in, so only MOCK builds can open the admin panel.
class Auth {
  static String? email;
  static String get displayName => email == null ? 'Guest' : email!.split('@').first;
}
