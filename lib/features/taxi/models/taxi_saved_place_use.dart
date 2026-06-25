import 'taxi_favorite_place.dart';

/// هل يُستخدم العنوان المحفوظ كنقطة انطلاق أم وجهة؟
enum TaxiSavedPlaceField {
  pickup,
  dropoff,
}

/// طلب معلّق لتطبيق عنوان محفوظ على شاشة الطلب.
class TaxiPendingSavedPlace {
  final TaxiFavoritePlace place;
  final TaxiSavedPlaceField field;

  const TaxiPendingSavedPlace({
    required this.place,
    required this.field,
  });
}
