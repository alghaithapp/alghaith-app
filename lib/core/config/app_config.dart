import 'package:flutter/foundation.dart';

/// إعدادات التطبيق — مصدر واحد للحقيقة (compile-time + defaults للإنتاج).
class AppConfig {
  const AppConfig._();

  static const String databaseBackendBaseUrl = String.fromEnvironment(
    'DATABASE_BACKEND_BASE_URL',
    defaultValue: 'https://alghaith-app-production.up.railway.app',
  );

  static const String phoneAuthBaseUrl = String.fromEnvironment(
    'PHONE_AUTH_BASE_URL',
    defaultValue: 'https://lively-wind-9d98.alghaithapp.workers.dev',
  );

  static const String mapboxPublicToken = String.fromEnvironment(
    'MAPBOX_PUBLIC_TOKEN',
    defaultValue: 'YOUR_MAPBOX_PUBLIC_TOKEN',
  );

  static const Duration apiTimeout = Duration(seconds: 20);
  static const Duration restoreTimeout = Duration(seconds: 18);
  static const Duration syncDebounce = Duration(seconds: 3);

  static String get normalizedDatabaseUrl =>
      databaseBackendBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  static String get normalizedPhoneAuthUrl =>
      phoneAuthBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  static bool get isBackendConfigured => normalizedDatabaseUrl.isNotEmpty;

  /// مفتاح Mapbox العام الصالح يبدأ بـ pk. ولا يكون النص الافتراضي في الكود.
  static bool get isMapboxConfigured {
    final token = mapboxPublicToken.trim();
    if (token.isEmpty) return false;
    if (token == 'YOUR_MAPBOX_PUBLIC_TOKEN') return false;
    if (token.startsWith('YOUR_')) return false;
    return token.startsWith('pk.');
  }

  /// تسعيرة التكسي الحالية: كل 3 كم = 1000 د.ع
  static const double taxiFareStepDistanceKm = 3;
  static const int taxiFareStepPriceIqd = 1000;
  static const int taxiFareOfficialIncrementIqd = 250;
  static const int deliveryFeePerKmIqd = 1000;

  /// التقريب يتم لأقرب فئة قابلة للدفع (250 د.ع للأعلى): 250, 500, 750, 1000...
  static const int deliveryFeeRoundingStepIqd = 250;

  /// الحد الأدنى لأي توصيل حتى لو كانت المسافة أقل من كيلومتر.
  static const int deliveryFeeMinIqd = 1000;

  /// معامل تصحيح المسافة عند تعذّر مسار Mapbox والرجوع للخط المستقيم.
  /// الطريق الفعلي في المدن أطول من الخط المستقيم بنحو 30%، فنضرب
  /// المسافة المستقيمة بهذا المعامل لتقريبها من المسافة الحقيقية.
  static const double straightLineRoadFactor = 1.3;

  static int calculateTaxiFare(double distanceKm) {
    final safeDistance = distanceKm.isFinite && distanceKm > 0 ? distanceKm : 0;
    final rawFare = (safeDistance / taxiFareStepDistanceKm) * taxiFareStepPriceIqd;
    final roundedFare = (rawFare / taxiFareOfficialIncrementIqd).ceil() *
        taxiFareOfficialIncrementIqd;
    if (roundedFare <= 0) return taxiFareOfficialIncrementIqd;
    return roundedFare;
  }

  static int calculateDeliveryFee(double distanceKm) {
    if (!distanceKm.isFinite || distanceKm <= 0) return 0;
    final rawFee = distanceKm * deliveryFeePerKmIqd;
    // تقريب للأعلى لأقرب فئة 250 د.ع (1200→1250، 1700→1750، 2050→2250).
    final roundedFee =
        (rawFee / deliveryFeeRoundingStepIqd).ceil() * deliveryFeeRoundingStepIqd;
    // حد أدنى 1000 د.ع لأي توصيل (مثل مسافة 500 متر).
    return roundedFee < deliveryFeeMinIqd ? deliveryFeeMinIqd : roundedFee;
  }

  static void validate({bool throwOnError = true}) {
    final issues = <String>[];

    if (normalizedDatabaseUrl.isEmpty) {
      issues.add('DATABASE_BACKEND_BASE_URL is missing.');
    }
    if (normalizedPhoneAuthUrl.isEmpty) {
      issues.add('PHONE_AUTH_BASE_URL is missing.');
    }
    if (kReleaseMode && normalizedDatabaseUrl.isEmpty) {
      issues.add('Release builds must use the Railway backend.');
    }

    if (issues.isNotEmpty) {
      final message = issues.join(' ');
      debugPrint('AppConfig: $message');
      if (throwOnError) {
        throw StateError(message);
      }
    }
  }
}
