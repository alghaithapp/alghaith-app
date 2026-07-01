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
        _fetch('cart-config'),
        _fetch('category-config'),
        _fetch('delivery-config'),
        _fetch('error-messages'),
      ]);
      final keys = ['taxiPricing', 'taxiConfig', 'mapDefaults', 'homeCategories', 'subCategories', 'neighborhoods', 'notificationTexts', 'appTheme', 'cartConfig', 'categoryConfig', 'deliveryConfig', 'errorMessages'];
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

  static int _i(Map<String, dynamic>? m, String key, int fallback) {
    final v = m?[key];
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static double _d(Map<String, dynamic>? m, String key, double fallback) {
    final v = m?[key];
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  static String _s(Map<String, dynamic>? m, String key, String fallback) {
    final v = m?[key];
    if (v is String && v.isNotEmpty) return v;
    return fallback;
  }

  // ═══════════════ Taxi Pricing ═══════════════
  Map<String, dynamic> get taxiPricing => _configs['taxiPricing'] as Map<String, dynamic>? ?? {};
  int get maxFare => _i(taxiPricing, 'maxFare', 50000);
  double get includedKm => _d(taxiPricing, 'includedKm', 2.0);
  int get fareRoundingStep => _i(taxiPricing, 'roundingStep', 250);
  Map<String, dynamic> pricingForType(String type) => taxiPricing[type] as Map<String, dynamic>? ?? {};

  // ═══════════════ Taxi Config ═══════════════
  Map<String, dynamic> get taxiConfig => _configs['taxiConfig'] as Map<String, dynamic>? ?? {};
  int get searchTimeoutSeconds => _i(taxiConfig, 'searchTimeoutSeconds', 300);
  int get maxStops => _i(taxiConfig, 'maxStops', 3);
  int get pollingIntervalSeconds => _i(taxiConfig, 'pollingIntervalSeconds', 30);

  // ═══════════════ Map Defaults ═══════════════
  Map<String, dynamic> get mapDefaults => _configs['mapDefaults'] as Map<String, dynamic>? ?? {};
  double get defaultCenterLat => _d(mapDefaults, 'centerLat', 32.9256);
  double get defaultCenterLng => _d(mapDefaults, 'centerLng', 44.7766);

  // ═══════════════ Home Categories ═══════════════
  Map<String, dynamic> get homeCategories => _configs['homeCategories'] as Map<String, dynamic>? ?? {};
  List<String> get homeCategoryOrder => (homeCategories['order'] as List?)?.cast<String>() ?? [];
  Map<String, dynamic> get homeCategoryMap => (homeCategories['categories'] as Map<String, dynamic>?) ?? {};

  // ═══════════════ Sub Categories ═══════════════
  Map<String, dynamic> get subCategories => _configs['subCategories'] as Map<String, dynamic>? ?? {};

  // ═══════════════ Neighborhoods ═══════════════
  Map<String, dynamic> get neighborhoods => _configs['neighborhoods'] as Map<String, dynamic>? ?? {};

  // ═══════════════ Notification Texts ═══════════════
  Map<String, dynamic> get notificationTexts => _configs['notificationTexts'] as Map<String, dynamic>? ?? {};

  // ═══════════════ App Theme ═══════════════
  Map<String, dynamic> get appTheme => _configs['appTheme'] as Map<String, dynamic>? ?? {};

  // ═══════════════ Cart Config ═══════════════
  int get cartMinAmount => _i(_configs['cartConfig'], 'minAmount', 1000);
  int get cartMaxAmount => _i(_configs['cartConfig'], 'maxAmount', 500000);
  List<String> get cartEnabledCategoryIds => (_configs['cartConfig']?['enabledCategoryIds'] as List?)?.cast<String>() ?? ['restaurant', 'product', 'bazar_ghaith'];

  // ═══════════════ Category Config ═══════════════
  List<String> get professionalExcludedCategoryIds => (_configs['categoryConfig']?['professionalExcludedIds'] as List?)?.cast<String>() ?? [];

  // ═══════════════ Delivery Config ═══════════════
  double get defaultDeliveryFee => _d(_configs['deliveryConfig'], 'defaultFee', 3000);
  int get processingTimeoutMinutes => _i(_configs['deliveryConfig'], 'processingTimeoutMinutes', 30);

  // ═══════════════ Error Messages ═══════════════
  String get networkErrorMessage => _s(_configs['errorMessages'], 'network', 'خطأ في الاتصال. تحقق من الإنترنت وحاول مجدداً.');
  String get serverErrorMessage => _s(_configs['errorMessages'], 'server', 'الخدمة غير متاحة حالياً. حاول لاحقاً.');
  String get genericErrorMessage => _s(_configs['errorMessages'], 'generic', 'تعذر إكمال الطلب حالياً. حاول مرة أخرى.');

  // ── Force refresh ──
  Future<void> refresh() async {
    _loaded = false;
    _configs.clear();
    await init();
  }
}
