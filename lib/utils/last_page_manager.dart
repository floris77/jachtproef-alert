import 'package:shared_preferences/shared_preferences.dart';

class LastPageManager {
  static const String _key = 'last_critical_page';

  static Future<void> setLastPage(String page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, page);
  }

  static Future<String?> getLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> clearLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
} 