import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// A random id made the first time the app runs. It stays the same for this phone, however many
/// accounts use it. The server will keep one record per phone under this id (see README).
class InstallId {
  InstallId._();
  static String? _cached;

  static Future<String> get() async {
    if (_cached != null) return _cached!;
    final p = await SharedPreferences.getInstance();
    var id = p.getString('install_id');
    if (id == null) {
      final r = Random.secure();
      id = List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
      await p.setString('install_id', id);
    }
    return _cached = id;
  }
}
