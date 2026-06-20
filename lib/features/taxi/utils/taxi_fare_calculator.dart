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

/// حاسبة أجرة التكسي — تعتمد على نفس منطق التسعير في المواصفات
class TaxiFareCalculator {
  static const int firstKmPrice = 1000;
  static const int extraKmPrice = 500;
  static const int roundingStep = 250;
  static const int minEconomic = 1000;
  static const int minSuper = 1500;
  static const int maxFare = 50000;
  static const double superMultiplier = 1.30;

  static FareResult calculateFare(double distanceKm, {TaxiType? taxiType}) {
    final safeDistance =
        distanceKm.isFinite && distanceKm > 0 ? distanceKm : 0.0;

    int rawEconomic;
    if (safeDistance <= 1.0) {
      rawEconomic = firstKmPrice;
    } else {
      rawEconomic = firstKmPrice +
          ((safeDistance - 1.0) * extraKmPrice).round();
    }

    // تقريب للأعلى لأقرب 250
    final fareEconomic = _roundUp(rawEconomic, minEconomic);
    final rawSuper = (rawEconomic * superMultiplier).round();
    final fareSuper = _roundUp(rawSuper, minSuper);

    int fare;
    if (taxiType == TaxiType.superTaxiType) {
      fare = fareSuper;
    } else {
      fare = fareEconomic;
    }
    fare = fare > maxFare ? maxFare : fare;

    return FareResult(
      fareEconomic: fareEconomic,
      fareSuper: fareSuper,
      fare: fare,
    );
  }

  static int _roundUp(int value, int min) {
    final rounded = ((value + roundingStep - 1) ~/ roundingStep) * roundingStep;
    return rounded < min ? min : rounded;
  }
}
