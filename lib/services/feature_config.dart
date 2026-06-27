import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';

/// قراءة feature flags من الباكند عند التشغيل والتحكم بالميزات عن بُعد.
///
/// الميزة: أي flag هنا تقدر تغير قيمته في [backend/routes/features.js]
/// بدون ما تحتاج بناء `.abb` جديد.
class FeatureConfig {
  FeatureConfig._();
  static final FeatureConfig _instance = FeatureConfig._();
  factory FeatureConfig() => _instance;

  static const _cacheKey = 'feature_flags_cache';
  static const _cacheTimeKey = 'feature_flags_cached_at';
  static const _cacheTtl = Duration(minutes: 30);

  Map<String, dynamic> _flags = {};
  DateTime _lastFetched = DateTime(2000);

  // ── Chat ──────────────────────────────────────────────────────────
  bool get chatV2 => _flag('chat_v2', true);
  bool get chatTimestamps => _flag('chat_timestamps', true);
  bool get chatDateSeparators => _flag('chat_date_separators', true);

  // ── Taxi ──────────────────────────────────────────────────────────
  bool get taxiCancelDirect => _flag('taxi_cancel_direct', true);
  bool get taxiShowBanner => _flag('taxi_show_banner', true);

  // ── Calls ─────────────────────────────────────────────────────────
  bool get callCancelledNotify => _flag('call_cancelled_notify', true);

  // ── General ───────────────────────────────────────────────────────
  bool get useVpsSocket => _flag('use_vps_socket', true);
  bool get inboxFilter => _flag('inbox_filter', true);

  bool _flag(String key, bool defaultValue) {
    final value = _flags[key];
    if (value is bool) return value;
    return defaultValue;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final cachedJson = prefs.getString(_cacheKey);
    final cachedAtMs = prefs.getInt(_cacheTimeKey);
    if (cachedJson != null && cachedAtMs != null) {
      try {
        final decoded = Map<String, dynamic>.from(
          (cachedJson as dynamic) is Map ? cachedJson as Map : {},
        );
        _flags = decoded;
        _lastFetched = DateTime.fromMillisecondsSinceEpoch(cachedAtMs, isUtc: true);
      } catch (_) {}
    }

    if (_flags.isEmpty || DateTime.now().toUtc().difference(_lastFetched) > _cacheTtl) {
      await _refresh();
    }
  }

  Future<void> _refresh() async {
    try {
      final data = await ApiClient.instance.get('/app/features');
      if (data is! Map) return;
      _flags = Map<String, dynamic>.from(data);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, data.toString());
      await prefs.setInt(_cacheTimeKey, DateTime.now().toUtc().millisecondsSinceEpoch);
    } catch (_) {}
  }
}
