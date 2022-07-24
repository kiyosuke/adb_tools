import 'package:shared_preferences/shared_preferences.dart';

class AdbPreferences {
  static const keyAdbPath = 'key_adb_path';

  Future<String?> getAdbPath() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(keyAdbPath);
  }

  Future<void> setAdbPath(String value) async {
    final pref = await SharedPreferences.getInstance();
    await pref.setString(keyAdbPath, value);
  }
}