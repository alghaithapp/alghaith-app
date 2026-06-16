import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// تخزين مؤقت لبيانات الكاتالوج والمتاجر لتسريع عرضها عند فتح التطبيق.
class CatalogCache {
  CatalogCache._();

  static const String _catalogKey = 'cached_catalog_data_v1';
  static const String _storesKey = 'cached_stores_data_v1';

  static Future<List<Map<String, dynamic>>?> readCatalog() async {
    return _read(_catalogKey);
  }

  static Future<void> writeCatalog(List<Map<String, dynamic>> data) async {
    await _write(_catalogKey, data);
  }

  static Future<List<Map<String, dynamic>>?> readStores() async {
    return _read(_storesKey);
  }

  static Future<void> writeStores(List<Map<String, dynamic>> data) async {
    await _write(_storesKey, data);
  }

  static Future<List<Map<String, dynamic>>?> readStoresBucket(
      String bucket) async {
    return _read('${_storesKey}_$bucket');
  }

  static Future<void> writeStoresBucket(
    String bucket,
    List<Map<String, dynamic>> data,
  ) async {
    await _write('${_storesKey}_$bucket', data);
  }

  static Future<List<Map<String, dynamic>>?> _read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _write(
      String key, List<Map<String, dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(data));
    } catch (_) {}
  }
}
