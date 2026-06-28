import 'package:shared_preferences/shared_preferences.dart';

/// يحفظ اختيار السائق: يبقى «متصل» حتى يُطفئه يدوياً (لا يُلغى عند إغلاق التطبيق).
abstract final class DriverPresenceStore {
  static String _key(String phone) => 'driver_wants_online_${phone.trim()}';

  static Future<bool> getWantsOnline(String phone) async {
    final normalized = phone.trim();
    if (normalized.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(normalized)) ?? false;
  }

  static Future<void> setWantsOnline(String phone, bool wants) async {
    final normalized = phone.trim();
    if (normalized.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(normalized), wants);
  }
}
