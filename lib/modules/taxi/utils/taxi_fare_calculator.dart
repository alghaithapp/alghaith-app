import '../../../services/app_config_service.dart';
import '../models/taxi_request.dart';

/// نتيجة حساب الأجرة
class FareResult {
  final int fareEconomic;
  final int fareSuper;
  final int fare;

  const FareResult({
    required this.fareEconomic,
    required this.fareSuper,
    required this.fare,
  });
}

/// حاسبة أجرة التنقل
///
/// الأسعار تُقرأ من AppConfigService (قابلة للتعديل بدون تحديث).
/// القيم الافتراضية:
///   تكتك: حتى 2 كم = 1,000 د.ع، ثم +250 لكل كم إضافي
///   واز: حتى 2 كم = 1,500 د.ع، ثم +300 لكل كم إضافي
///   تكسي اقتصادي: حتى 2 كم = 1,500 د.ع (حتى لو 1 كم)، ثم +500 لكل كم إضافي
class TaxiFareCalculator {
  static int _getInt(Map<String, dynamic> pricing, String key, int fallback) {
    final v = pricing[key];
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static double _getDouble(Map<String, dynamic> pricing, String key, double fallback) {
    final v = pricing[key];
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  static Map<String, dynamic> _pricingForType(TaxiType type) {
    final config = AppConfigService.instance.taxiPricing;
    final key = type == TaxiType.tuktuk ? 'tuktuk' : type == TaxiType.wazz ? 'wazz' : 'economic';
    return (config[key] as Map<String, dynamic>?) ?? {};
  }

  static int get maxFare => _getInt(AppConfigService.instance.taxiPricing, 'maxFare', 50000);
  static double get includedKm => _getDouble(AppConfigService.instance.taxiPricing, 'includedKm', 2.0);
  static int get fareRoundingStep => _getInt(AppConfigService.instance.taxiPricing, 'roundingStep', 250);

  static int get tuktukBase => _getInt(_pricingForType(TaxiType.tuktuk), 'base', 1000);
  static int get tuktukExtraKm => _getInt(_pricingForType(TaxiType.tuktuk), 'extraKm', 250);
  static int get tuktukMin => _getInt(_pricingForType(TaxiType.tuktuk), 'min', 1000);

  static int get wazzBase => _getInt(_pricingForType(TaxiType.wazz), 'base', 1500);
  static int get wazzExtraKm => _getInt(_pricingForType(TaxiType.wazz), 'extraKm', 300);
  static int get wazzMin => _getInt(_pricingForType(TaxiType.wazz), 'min', 1500);

  static int get economicBase => _getInt(_pricingForType(TaxiType.economic), 'base', 1500);
  static int get economicExtraKm => _getInt(_pricingForType(TaxiType.economic), 'extraKm', 500);
  static int get economicMin => _getInt(_pricingForType(TaxiType.economic), 'min', 1500);

  static int roundFareToNearestStep(int raw) {
    final safe = raw < 0 ? 0 : raw;
    final step = fareRoundingStep;
    if (safe <= 0) return step;
    return ((safe / step).round()) * step;
  }

  static FareResult calculateFare(double distanceKm, {TaxiType? taxiType, bool isRoundTrip = false}) {
    final type = taxiType ?? TaxiType.economic;
    final effectiveDistance = isRoundTrip ? distanceKm * 2 : distanceKm;
    final fare = fareForType(effectiveDistance, type);
    final economicFare = fareForType(effectiveDistance, TaxiType.economic);
    return FareResult(fareEconomic: economicFare, fareSuper: fare, fare: fare);
  }

  static int fareForTypeWithRoundTrip(double distanceKm, TaxiType type, bool isRoundTrip) {
    final effectiveDistance = isRoundTrip ? distanceKm * 2 : distanceKm;
    return fareForType(effectiveDistance, type);
  }

  static int fareForType(double distanceKm, TaxiType type) {
    final safeDistance = distanceKm.isFinite && distanceKm > 0 ? distanceKm : 0.0;
    final incKm = includedKm;
    final max = maxFare;

    late final int raw;
    late final int minFare;

    switch (type) {
      case TaxiType.tuktuk:
        raw = safeDistance <= incKm ? tuktukBase : tuktukBase + ((safeDistance - incKm) * tuktukExtraKm).round();
        minFare = tuktukMin;
      case TaxiType.wazz:
        raw = safeDistance <= incKm ? wazzBase : wazzBase + ((safeDistance - incKm) * wazzExtraKm).round();
        minFare = wazzMin;
      case TaxiType.economic:
        raw = safeDistance <= incKm ? economicBase : economicBase + ((safeDistance - incKm) * economicExtraKm).round();
        minFare = economicMin;
    }

    final bounded = raw < minFare ? minFare : raw;
    final capped = bounded > max ? max : bounded;
    return roundFareToNearestStep(capped);
  }
}
