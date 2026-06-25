import 'dart:math' as math;

/// حاسبة المسافة بين نقطتين (Haversine formula)
class TaxiDistanceCalculator {
  static const double earthRadiusKm = 6371.0;

  /// حساب المسافة بالكيلومتر بين إحداثيتين باستخدام Haversine formula
  static double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRadians(double degree) => degree * math.pi / 180;

  /// تقدير مدة القيادة عند غياب بيانات Directions (متوسط ~28 كم/س في المدينة).
  static int estimateDrivingDurationSeconds(double distanceKm) {
    if (!distanceKm.isFinite || distanceKm <= 0) return 60;
    const avgSpeedKmh = 28.0;
    return ((distanceKm / avgSpeedKmh) * 3600).ceil().clamp(60, 6 * 3600);
  }

  static String formatDrivingDurationAr(int totalSeconds) {
    final minutes = (totalSeconds / 60).ceil().clamp(1, 999);
    if (minutes == 1) return 'دقيقة واحدة';
    if (minutes == 2) return 'دقيقتان';
    if (minutes <= 10) return '$minutes دقائق';
    return '$minutes دقيقة';
  }
}
