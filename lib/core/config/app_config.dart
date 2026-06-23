import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project-ref.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key',
  );

  static String? _resolvedMapboxToken;

  /// مفتاح Google Maps (Places + Geocoding + Directions) — نفس مفتاح الخريطة.
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyBX720zCrccLT6ZKrc_o7r9tr0TAHDsy8c',
  );

  static bool get isGoogleMapsConfigured {
    final key = googleMapsApiKey.trim();
    return key.isNotEmpty && !key.startsWith('YOUR_');
  }

  // مهلة أطول لتحمّل بدء تشغيل خادم Railway البارد (cold start) عند أول طلب.
  static const Duration apiTimeout = Duration(seconds: 45);
  static const Duration restoreTimeout = Duration(seconds: 60);
  static const Duration syncDebounce = Duration(seconds: 3);

  static String get normalizedDatabaseUrl =>
      databaseBackendBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  static String get normalizedPhoneAuthUrl =>
      phoneAuthBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  static bool get isBackendConfigured => normalizedDatabaseUrl.isNotEmpty;

  static bool _isValidMapboxPublicToken(String token) {
    final value = token.trim();
    if (value.isEmpty) return false;
    if (value == 'YOUR_MAPBOX_PUBLIC_TOKEN') return false;
    if (value.startsWith('YOUR_')) return false;
    return value.startsWith('pk.');
  }

  /// مفتاح Mapbox الفعلي: من --dart-define أولاً، ثم من الخادم عند التشغيل.
  static String get effectiveMapboxPublicToken {
    if (_isValidMapboxPublicToken(mapboxPublicToken)) {
      return mapboxPublicToken.trim();
    }
    final runtime = (_resolvedMapboxToken ?? '').trim();
    if (_isValidMapboxPublicToken(runtime)) return runtime;
    return mapboxPublicToken.trim();
  }

  /// هل الخرائط جاهزة (مفتاح compile-time أو مُحمّل من الخادم).
  static bool get isMapboxConfigured =>
      _isValidMapboxPublicToken(effectiveMapboxPublicToken);

  /// يحمّل مفتاح pk. من الخادم إذا لم يُمرَّر عند البناء (مثل TestFlight بدون dart-define).
  static Future<void> ensureMapboxToken() async {
    if (_isValidMapboxPublicToken(mapboxPublicToken)) {
      _resolvedMapboxToken = mapboxPublicToken.trim();
      return;
    }
    if (_isValidMapboxPublicToken(_resolvedMapboxToken ?? '')) return;
    if (!isBackendConfigured) return;

    try {
      final uri = Uri.parse('$normalizedDatabaseUrl/maps/public-token');
      final response = await http.get(uri).timeout(apiTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return;

      final payload = jsonDecode(response.body);
      if (payload is! Map) return;

      final token = (payload['publicToken'] ?? payload['token'] ?? '')
          .toString()
          .trim();
      if (_isValidMapboxPublicToken(token)) {
        _resolvedMapboxToken = token;
        debugPrint('AppConfig: Mapbox public token loaded from backend.');
      }
    } catch (error) {
      debugPrint('AppConfig: failed to fetch Mapbox public token: $error');
    }
  }

  /// تسعيرة التكسي: أول 1 كم = 1,000 د.ع، كل كم إضافي = 500 د.ع
  static const int taxiFareFirstKmIqd = 1000;
  static const int taxiFareExtraKmPriceIqd = 500;
  static const int taxiFareRoundingStepIqd = 250;

  /// التقريب للأعلى لأقرب 250 (1,100→1,250 / 1,300→1,500)
  static int roundFareToNearestStep(int raw) =>
      (raw / taxiFareRoundingStepIqd).ceil() * taxiFareRoundingStepIqd;

  static int calculateTaxiFare(double distanceKm, {double multiplier = 1.0}) {
    final safeDistance = distanceKm.isFinite && distanceKm > 0 ? distanceKm : 0;

    int rawFare;
    if (safeDistance <= 1.0) {
      rawFare = taxiFareFirstKmIqd;
    } else {
      rawFare = taxiFareFirstKmIqd +
          ((safeDistance - 1.0) * taxiFareExtraKmPriceIqd).round();
    }

    // تطبيق الـ multiplier (افتراضي 1.0 — تكسي اقتصادي فقط)
    rawFare = (rawFare * multiplier).round();

    // تقريب للأعلى لأقرب 250
    final roundedFare = roundFareToNearestStep(rawFare);

    if (roundedFare <= 0) return taxiFareRoundingStepIqd;
    return roundedFare;
  }

  /// تسعيرة التوصيل: الكيلومتر الأول بـ 1000 د.ع، وكل كيلومتر إضافي بـ 500 د.ع.
  static const int deliveryFeeFirstKmIqd = 1000;
  static const int deliveryFeeExtraKmPriceIqd = 500;

  /// التقريب يتم لأقرب فئة قابلة للدفع (250 د.ع للأعلى): 250, 500, 750, 1000...
  static const int deliveryFeeRoundingStepIqd = 250;

  /// الحد الأدنى لأي توصيل.
  static const int deliveryFeeMinIqd = 1000;

  /// معامل تصحيح المسافة عند تعذّر مسار Mapbox والرجوع للخط المستقيم.
  /// الطريق الفعلي في المدن أطول من الخط المستقيم بنحو 30%، فنضرب
  /// المسافة المستقيمة بهذا المعامل لتقريبها من المسافة الحقيقية.
  static const double straightLineRoadFactor = 1.3;


  static int calculateDeliveryFee(double distanceKm) {
    if (!distanceKm.isFinite || distanceKm <= 0) return 0;

    double rawFee;
    if (distanceKm <= 1.0) {
      rawFee = deliveryFeeFirstKmIqd.toDouble();
    } else {
      rawFee = deliveryFeeFirstKmIqd +
          ((distanceKm - 1.0) * deliveryFeeExtraKmPriceIqd);
    }

    // تقريب للأعلى لأقرب فئة 250 د.ع (1350→1500، 1100→1250).
    final roundedFee =
        (rawFee / deliveryFeeRoundingStepIqd).ceil() *
            deliveryFeeRoundingStepIqd;

    // حد أدنى 1000 د.ع لأي توصيل.
    return roundedFee < deliveryFeeMinIqd ? deliveryFeeMinIqd : roundedFee;
  }

  static int calculateBazarDeliveryFee(double distanceKm) {
    if (!distanceKm.isFinite || distanceKm <= 0) return 0;

    double rawFee;
    if (distanceKm <= 3.0) {
      rawFee = 1000;
    } else {
      rawFee = 1000 + ((distanceKm - 3.0) * 350);
    }

    // تقريب للأعلى لأقرب فئة 250 د.ع
    final roundedFee = (rawFee / 250).ceil() * 250;
    return roundedFee < 1000 ? 1000 : roundedFee;
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
