import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/home_category_platform_override.dart';

/// تخزين محلي لإعدادات أقسام الرئيسية لتجنب وميض الأقسام عند فتح التطبيق.
class HomeCategoriesCache {
  HomeCategoriesCache._();

  static const String _prefsKey = 'home_category_overrides_cache_v1';

  static Future<Map<String, HomeCategoryPlatformOverride>?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.trim().isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final overrides = <String, HomeCategoryPlatformOverride>{};
      decoded.forEach((key, value) {
        final id = key?.toString().trim() ?? '';
        final parsed = HomeCategoryPlatformOverride.fromDynamic(value);
        if (id.isNotEmpty && parsed != null) {
          overrides[id] = parsed;
        }
      });
      return overrides;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(
    Map<String, HomeCategoryPlatformOverride> overrides,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = <String, dynamic>{
        for (final entry in overrides.entries)
          entry.key: entry.value.toJson(),
      };
      await prefs.setString(_prefsKey, jsonEncode(encoded));
    } catch (_) {
      // تجاهل — التخزين المحلي اختياري
    }
  }
}
