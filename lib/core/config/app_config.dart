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

  /// تسعيرة التكسي الحالية: كل 3 كم = 1000 د.ع
  static const double taxiFareStepDistanceKm = 3;
  static const int taxiFareStepPriceIqd = 1000;
  static const int taxiFareOfficialIncrementIqd = 250;
  static const int deliveryFeePerKmIqd = 1000;

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
    final normalizedKm = distanceKm.ceil();
    final fee = normalizedKm * deliveryFeePerKmIqd;
    return fee <= 0 ? deliveryFeePerKmIqd : fee;
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
