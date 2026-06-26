import '../models/taxi_request.dart';

/// نتيجة حساب الأجرة
class FareResult {
  final int fareEconomic;
  final int fareSuper;
  final int fare;

  FareResult({
    required this.fareEconomic,
    required this.fareSuper,
    required this.fare,
  });
}

/// حاسبة أجرة التنقل
///
/// تكتك: حتى 2 كم = 1,000 د.ع، ثم +250 لكل كم إضافي
/// واز: حتى 2 كم = 1,500 د.ع، ثم +300 لكل كم إضافي
/// تكسي اقتصادي: حتى 2 كم = 1,500 د.ع (حتى لو 1 كم)، ثم +500 لكل كم إضافي
class TaxiFareCalculator {
  static const int maxFare = 50000;
  static const double includedKm = 2.0;

  static const int tuktukBase = 1000;
  static const int tuktukExtraKm = 250;
  static const int tuktukMin = 1000;

  static const int wazzBase = 1500;
  static const int wazzExtraKm = 300;
  static const int wazzMin = 1500;

  static const int economicBase = 1500;
  static const int economicExtraKm = 500;
  static const int economicMin = 1500;

  static const int fareRoundingStep = 250;

  /// تقريب لأقرب 250 د.ع (1430→1500، 1700→1700)
  static int roundFareToNearestStep(int raw) {
    final safe = raw < 0 ? 0 : raw;
    if (safe <= 0) return fareRoundingStep;
    return ((safe / fareRoundingStep).round()) * fareRoundingStep;
  }

  static FareResult calculateFare(double distanceKm, {TaxiType? taxiType}) {
    final type = taxiType ?? TaxiType.economic;
    final fare = fareForType(distanceKm, type);
    final economicFare = fareForType(distanceKm, TaxiType.economic);

    return FareResult(
      fareEconomic: economicFare,
      fareSuper: fare,
      fare: fare,
    );
  }

  static int fareForType(double distanceKm, TaxiType type) {
    final safeDistance =
        distanceKm.isFinite && distanceKm > 0 ? distanceKm : 0.0;

    late final int raw;
    late final int minFare;

    switch (type) {
      case TaxiType.tuktuk:
        raw = safeDistance <= includedKm
            ? tuktukBase
            : tuktukBase + ((safeDistance - includedKm) * tuktukExtraKm).round();
        minFare = tuktukMin;
        break;
      case TaxiType.wazz:
        raw = safeDistance <= includedKm
            ? wazzBase
            : wazzBase + ((safeDistance - includedKm) * wazzExtraKm).round();
        minFare = wazzMin;
        break;
      case TaxiType.economic:
        raw = safeDistance <= includedKm
            ? economicBase
            : economicBase +
                ((safeDistance - includedKm) * economicExtraKm).round();
        minFare = economicMin;
        break;
    }

    final bounded = raw < minFare ? minFare : raw;
    final capped = bounded > maxFare ? maxFare : bounded;
    return roundFareToNearestStep(capped);
  }
}
