import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تخزين مؤقت لبيانات الكاتالوج والمتاجر (Hive CE) لتسريع العرض عند فتح التطبيق.
class CatalogCache {
  CatalogCache._();

  static const String _boxName = 'catalog_cache_v1';
  static const String _catalogKey = 'cached_catalog_data_v1';
  static const String _storesKey = 'cached_stores_data_v1';

  static Box<String>? _box;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    await _migrateFromSharedPreferences();
    _initialized = true;
  }

  static Future<void> _ensureReady() async {
    if (!_initialized) await init();
  }

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
    String bucket,
  ) async {
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
      await _ensureReady();
      final raw = _box?.get(key);
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
    String key,
    List<Map<String, dynamic>> data,
  ) async {
    try {
      await _ensureReady();
      await _box?.put(key, jsonEncode(data));
    } catch (_) {}
  }

  static Future<void> _migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = <String>[
        _catalogKey,
        _storesKey,
        ...prefs
            .getKeys()
            .where((key) => key.startsWith('${_storesKey}_')),
      ];
      for (final key in keys) {
        if ((_box?.containsKey(key) ?? false) == true) continue;
        final legacy = prefs.getString(key);
        if (legacy == null || legacy.trim().isEmpty) continue;
        await _box?.put(key, legacy);
        await prefs.remove(key);
      }
    } catch (_) {}
  }
}
