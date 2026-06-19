import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// حي مع إحداثياته في الصويرة
class SuwayraPlace {
  final String name;
  final double latitude;
  final double longitude;

  const SuwayraPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  LatLng get latlng => LatLng(latitude, longitude);

  /// المسافة بالكيلومتر من نقطة [from]
  double distanceKm(LatLng from) {
    const R = 6371.0;
    final dLat = (latitude - from.latitude) * math.pi / 180;
    final dLon = (longitude - from.longitude) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(from.latitude * math.pi / 180) *
            math.cos(latitude * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

/// الأحياء الرئيسية لقضاء الصويرة — محافظة واسط — العراق
class IraqNeighborhoods {
  static const String country = 'العراق';
  static const String governorate = 'واسط';
  static const String district = 'الصويرة';

  /// مركز الصويرة
  static const double centerLat = 32.9256;
  static const double centerLng = 44.7766;

  /// الأحياء الرئيسية في قضاء الصويرة مع إحداثيات تقديرية
  static const List<SuwayraPlace> suwayraPlaces = [
    SuwayraPlace(name: 'حي السراي', latitude: 32.9311, longitude: 44.7844),
    SuwayraPlace(name: 'حي العمال', latitude: 32.9252, longitude: 44.7708),
    SuwayraPlace(name: 'حي العسكري', latitude: 32.9297, longitude: 44.7636),
    SuwayraPlace(name: 'حي المعلمين', latitude: 32.9240, longitude: 44.7650),
    SuwayraPlace(name: 'حي دجلة', latitude: 32.9350, longitude: 44.7780),
    SuwayraPlace(name: 'حي العروبة', latitude: 32.9280, longitude: 44.7820),
    SuwayraPlace(name: 'حي العسكري', latitude: 32.9260, longitude: 44.7680),
    SuwayraPlace(name: 'حي العمال', latitude: 32.9220, longitude: 44.7750),
    SuwayraPlace(name: 'حي الربيع', latitude: 32.9300, longitude: 44.7720),
    SuwayraPlace(name: 'حي الجمهورية', latitude: 32.9300, longitude: 44.7800),
    SuwayraPlace(name: 'حي السلام', latitude: 32.9220, longitude: 44.7820),
    SuwayraPlace(name: 'حي الزهراء', latitude: 32.9280, longitude: 44.7720),
    SuwayraPlace(name: 'حي النصر', latitude: 32.9200, longitude: 44.7700),
    SuwayraPlace(name: 'حي الجمعية', latitude: 32.9320, longitude: 44.7760),
    SuwayraPlace(name: 'حي الوحدة', latitude: 32.9240, longitude: 44.7840),
    SuwayraPlace(name: 'حي الشهداء', latitude: 32.9180, longitude: 44.7740),
    SuwayraPlace(name: 'حي الحسين', latitude: 32.9340, longitude: 44.7780),
    SuwayraPlace(name: 'حي القدس', latitude: 32.9160, longitude: 44.7800),
    SuwayraPlace(name: 'حي الكرامة', latitude: 32.9360, longitude: 44.7740),
    SuwayraPlace(name: 'حي العامل', latitude: 32.9230, longitude: 44.7760),
    SuwayraPlace(name: 'حي الثورة', latitude: 32.9270, longitude: 44.7860),
    SuwayraPlace(name: 'حي الفداء', latitude: 32.9210, longitude: 44.7720),
    SuwayraPlace(name: 'مركز المدينة', latitude: 32.9256, longitude: 44.7766),
    SuwayraPlace(name: 'منطقة الكورنيش', latitude: 32.9380, longitude: 44.7820),
    SuwayraPlace(name: 'منطقة البساتين', latitude: 32.9380, longitude: 44.7680),
    SuwayraPlace(name: 'منطقة الخط السريع', latitude: 32.9280, longitude: 44.7900),
    SuwayraPlace(name: 'منطقة السدة', latitude: 32.9120, longitude: 44.7800),
    SuwayraPlace(name: 'منطقة النهرين', latitude: 32.9400, longitude: 44.7840),
    SuwayraPlace(name: 'شارع بغداد', latitude: 32.9260, longitude: 44.7880),
    SuwayraPlace(name: 'شارع المستشفى', latitude: 32.9250, longitude: 44.7700),
    SuwayraPlace(name: 'سوق الصويرة الكبير', latitude: 32.9260, longitude: 44.7770),
    SuwayraPlace(name: 'ناحية الشحيمية', latitude: 32.7200, longitude: 44.8500),
    SuwayraPlace(name: 'ناحية الزبيدية', latitude: 32.8100, longitude: 44.9800),
    SuwayraPlace(name: 'قرية الرسالة', latitude: 32.9500, longitude: 44.7500),
    SuwayraPlace(name: 'قرية الدواغنة', latitude: 32.9100, longitude: 44.7400),
    SuwayraPlace(name: 'قرية الرحمانية', latitude: 32.9000, longitude: 44.8000),
    SuwayraPlace(name: 'شبه جزيرة ربيضة', latitude: 32.9300, longitude: 44.8200),
    SuwayraPlace(name: 'منطقة تل عقيل', latitude: 32.9600, longitude: 44.7900),
  ];

  /// أسماء الأحياء فقط (للتوارث)
  static const List<String> suwayraNeighborhoods = [
    'حي السراي',
    'حي العمال',
    'حي العسكري',
    'حي المعلمين',
    'حي دجلة',
    'حي العروبة',
    'حي العسكري',
    'حي العمال',
    'حي الربيع',
    'حي الجمهورية',
    'حي السلام',
    'حي الزهراء',
    'حي النصر',
    'حي الجمعية',
    'حي الوحدة',
    'حي الشهداء',
    'حي الحسين',
    'حي القدس',
    'حي الكرامة',
    'حي العامل',
    'حي الثورة',
    'حي الفداء',
    'مركز المدينة',
    'منطقة الكورنيش',
    'منطقة البساتين',
    'منطقة الخط السريع',
    'منطقة السدة',
    'منطقة النهرين',
    'شارع بغداد',
    'شارع المستشفى',
    'سوق الصويرة الكبير',
    'ناحية الشحيمية',
    'ناحية الزبيدية',
    'قرية الرسالة',
    'قرية الدواغنة',
    'قرية الرحمانية',
    'شبه جزيرة ربيضة',
    'منطقة تل عقيل',
  ];


  /// أبرز المعالم في الصويرة مع إحداثيات
  static const List<SuwayraPlace> suwayraLandmarkPlaces = [
    SuwayraPlace(name: 'مستشفى الصويرة العام', latitude: 32.9245, longitude: 44.7695),
    SuwayraPlace(name: 'جامعة واسط - كلية الصويرة', latitude: 32.9310, longitude: 44.7660),
    SuwayraPlace(name: 'مركز شرطة الصويرة', latitude: 32.9265, longitude: 44.7750),
    SuwayraPlace(name: 'دائرة بلدية الصويرة', latitude: 32.9250, longitude: 44.7775),
    SuwayraPlace(name: 'جسر الصويرة القديم', latitude: 32.9230, longitude: 44.7730),
    SuwayraPlace(name: 'ملعب الصويرة الرياضي', latitude: 32.9225, longitude: 44.7680),
    SuwayraPlace(name: 'محطة وقود الصويرة المركزية', latitude: 32.9270, longitude: 44.7780),
    SuwayraPlace(name: 'مكتب بريد الصويرة', latitude: 32.9260, longitude: 44.7760),
    SuwayraPlace(name: 'مجمع العبدالله التجاري', latitude: 32.9275, longitude: 44.7785),
    SuwayraPlace(name: 'أسواق العروبة', latitude: 32.9285, longitude: 44.7815),
    SuwayraPlace(name: 'منتزه الصويرة الترفيهي', latitude: 32.9320, longitude: 44.7850),
    SuwayraPlace(name: 'مطعم طربوش الحلبي', latitude: 32.9262, longitude: 44.7765),
    SuwayraPlace(name: 'كوزمتك الرمال', latitude: 32.9258, longitude: 44.7772),
  ];

  /// أسماء المعالم فقط (للتوارث)
  static const List<String> suwayraLandmarks = [
    'مستشفى الصويرة العام',
    'جامعة واسط - كلية الصويرة',
    'مركز شرطة الصويرة',
    'دائرة بلدية الصويرة',
    'جسر الصويرة القديم',
    'ملعب الصويرة الرياضي',
    'محطة وقود الصويرة المركزية',
    'مكتب بريد الصويرة',
    'مجمع العبدالله التجاري',
    'أسواق العروبة',
    'منتزه الصويرة الترفيهي',
    'مطعم طربوش الحلبي',
    'كوزمتك الرمال',
  ];

  /// جميع الأماكن مع إحداثياتها
  static List<SuwayraPlace> get allPlaces => [
        ...suwayraPlaces,
        ...suwayraLandmarkPlaces,
      ];

  /// جميع خيارات العناوين (للاقتراحات السريعة)
  static List<String> get allSuggestions => [
        ...suwayraNeighborhoods,
        ...suwayraLandmarks,
      ];

  /// البحث عن أقرب الأماكن المطابقة للنص مع ترتيب حسب المسافة
  /// [query] النص الذي يبحث عنه المستخدم
  /// [from] موقع المستخدم (إن وجد) لحساب المسافة
  /// [maxResults] أقصى عدد من النتائج
  static List<_SearchResult> search(String query, {LatLng? from, int maxResults = 8}) {
    final q = query.trim();
    if (q.isEmpty) return [];

    // تقسيم الاستعلام إلى كلمات
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return [];

    // تقييم درجة المطابقة لكل مكان
    final List<_Scored> scored = [];
    for (final place in allPlaces) {
      int score = 0;

      // 1. المطابقة التامة (البادئة)
      if (place.name.startsWith(q)) {
        score += 100;
      } else if (place.name.contains(q)) {
        score += 60;
      } else {
        // 2. المطابقة الجزئية (كل كلمة من البحث توجد في الاسم)
        int matchCount = 0;
        for (final word in words) {
          if (place.name.contains(word)) {
            matchCount++;
          }
        }
        if (matchCount == 0) continue; // لا يوجد تطابق → نتخطى
        score += matchCount * 25;
      }

      // 3. أفضلية للكلمات الأقصر (الأحياء الأساسية أولاً)
      score += math.max(0, 10 - place.name.length);

      // حساب المسافة
      final dist = from != null ? place.distanceKm(from) : 0.0;

      scored.add(_Scored(place: place, score: score, distanceKm: dist));
    }

    // ترتيب: الأعلى درجة أولاً، ثم الأقرب مسافة
    scored.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return a.distanceKm.compareTo(b.distanceKm);
    });

    return scored
        .take(maxResults)
        .map((s) => _SearchResult(
              place: s.place,
              distanceKm: s.distanceKm,
              score: s.score,
            ))
        .toList();
  }
}

/// نتيجة داخلية للتقييم
class _Scored {
  final SuwayraPlace place;
  final int score;
  final double distanceKm;
  const _Scored({
    required this.place,
    required this.score,
    required this.distanceKm,
  });
}

/// نتيجة بحث مع المسافة
class _SearchResult {
  final SuwayraPlace place;
  final double distanceKm;
  final int score;
  const _SearchResult({
    required this.place,
    required this.distanceKm,
    required this.score,
  });
}
