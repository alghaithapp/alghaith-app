import 'dart:convert';

import '../core/network/api_client.dart';

/// خدمة الإعدادات الديناميكية — تُقرأ من Backend وتُخزّن مؤقتاً.
class AppConfigService {
  AppConfigService._();
  static final AppConfigService instance = AppConfigService._();

  Map<String, dynamic> _configs = {};
  bool _loaded = false;

  Future<void> init() async {
    try {
      _configs = {};
      final results = await Future.wait([
        _fetch('taxi-pricing'),
        _fetch('taxi-config'),
        _fetch('map-defaults'),
        _fetch('home-categories'),
        _fetch('sub-categories'),
        _fetch('neighborhoods'),
        _fetch('notification-texts'),
        _fetch('app-theme'),
      ]);
      final keys = ['taxiPricing', 'taxiConfig', 'mapDefaults', 'homeCategories', 'subCategories', 'neighborhoods', 'notificationTexts', 'appTheme'];
      for (var i = 0; i < results.length; i++) {
        if (results[i] != null) _configs[keys[i]] = results[i];
      }
      _loaded = true;
    } catch (_) {
      _loaded = true;
    }
  }

  Future<Map<String, dynamic>?> _fetch(String path) async {
    try {
      final result = await ApiClient.instance.get('/app/config/$path');
      if (result is Map) return Map<String, dynamic>.from(result);
      return null;
    } catch (_) {
      return null;
    }
  }

  bool get isLoaded => _loaded;

  // ── Taxi Pricing ──────────────────────────────────────────────────
  Map<String, dynamic> get taxiPricing => _configs['taxiPricing'] as Map<String, dynamic>? ?? {};
  int get maxFare => (taxiPricing['maxFare'] as num?)?.toInt() ?? 50000;
  double get includedKm => (taxiPricing['includedKm'] as num?)?.toDouble() ?? 2.0;
  int get roundingStep => (taxiPricing['roundingStep'] as num?)?.toInt() ?? 250;

  Map<String, dynamic> pricingForType(String type) {
    return taxiPricing[type] as Map<String, dynamic>? ?? {};
  }

  // ── Taxi Config ───────────────────────────────────────────────────
  Map<String, dynamic> get taxiConfig => _configs['taxiConfig'] as Map<String, dynamic>? ?? {};
  int get searchTimeoutSeconds => (taxiConfig['searchTimeoutSeconds'] as num?)?.toInt() ?? 300;
  int get maxStops => (taxiConfig['maxStops'] as num?)?.toInt() ?? 3;

  // ── Map Defaults ──────────────────────────────────────────────────
  Map<String, dynamic> get mapDefaults => _configs['mapDefaults'] as Map<String, dynamic>? ?? {};
  double get defaultCenterLat => (mapDefaults['centerLat'] as num?)?.toDouble() ?? 32.9256;
  double get defaultCenterLng => (mapDefaults['centerLng'] as num?)?.toDouble() ?? 44.7766;

  // ── Home Categories ───────────────────────────────────────────────
  Map<String, dynamic> get homeCategories => _configs['homeCategories'] as Map<String, dynamic>? ?? {};
  List<String> get homeCategoryOrder => (homeCategories['order'] as List?)?.cast<String>() ?? [];
  Map<String, dynamic> get homeCategoryMap => (homeCategories['categories'] as Map<String, dynamic>?) ?? {};

  // ── Sub Categories ────────────────────────────────────────────────
  Map<String, dynamic> get subCategories => _configs['subCategories'] as Map<String, dynamic>? ?? {};

  // ── Neighborhoods ─────────────────────────────────────────────────
  Map<String, dynamic> get neighborhoods => _configs['neighborhoods'] as Map<String, dynamic>? ?? {};

  // ── Notification Texts ────────────────────────────────────────────
  Map<String, dynamic> get notificationTexts => _configs['notificationTexts'] as Map<String, dynamic>? ?? {};

  // ── App Theme ─────────────────────────────────────────────────────
  Map<String, dynamic> get appTheme => _configs['appTheme'] as Map<String, dynamic>? ?? {};

  // ── Force refresh ─────────────────────────────────────────────────
  Future<void> refresh() async {
    _loaded = false;
    _configs.clear();
    await init();
  }
}
