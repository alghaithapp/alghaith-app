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
    // ── مركز المدينة والأحياء الأساسية ──
    SuwayraPlace(name: 'مركز الصويرة', latitude: 32.9256, longitude: 44.7766),
    SuwayraPlace(name: 'حي السراي', latitude: 32.9311, longitude: 44.7844),
    SuwayraPlace(name: 'حي العمال', latitude: 32.9252, longitude: 44.7708),
    SuwayraPlace(name: 'حي العسكري', latitude: 32.9297, longitude: 44.7636),
    SuwayraPlace(name: 'حي المعلمين', latitude: 32.9240, longitude: 44.7650),
    SuwayraPlace(name: 'حي دجلة', latitude: 32.9350, longitude: 44.7780),
    SuwayraPlace(name: 'حي العروبة', latitude: 32.9280, longitude: 44.7820),
    SuwayraPlace(name: 'حي العسكري الثاني', latitude: 32.9260, longitude: 44.7680),
    SuwayraPlace(name: 'حي العمال الجديد', latitude: 32.9220, longitude: 44.7750),
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
    SuwayraPlace(name: 'حي الأندلس', latitude: 32.9330, longitude: 44.7700),
    SuwayraPlace(name: 'حي الفرات', latitude: 32.9370, longitude: 44.7760),
    SuwayraPlace(name: 'حي النخيل', latitude: 32.9200, longitude: 44.7780),
    SuwayraPlace(name: 'حي المشراق', latitude: 32.9350, longitude: 44.7720),
    SuwayraPlace(name: 'حي الصديق', latitude: 32.9170, longitude: 44.7760),
    SuwayraPlace(name: 'حي المختار', latitude: 32.9340, longitude: 44.7820),
    SuwayraPlace(name: 'حي القادسية', latitude: 32.9190, longitude: 44.7820),
    SuwayraPlace(name: 'حي الزيتون', latitude: 32.9360, longitude: 44.7800),
    SuwayraPlace(name: 'حي الياسمين', latitude: 32.9220, longitude: 44.7680),
    SuwayraPlace(name: 'حي الغدير', latitude: 32.9380, longitude: 44.7760),
    SuwayraPlace(name: 'حي النور', latitude: 32.9240, longitude: 44.7720),
    SuwayraPlace(name: 'حي الأمل', latitude: 32.9260, longitude: 44.7740),
    SuwayraPlace(name: 'حي الصباح', latitude: 32.9280, longitude: 44.7780),
    SuwayraPlace(name: 'حي الكوفة', latitude: 32.9325, longitude: 44.7745),

    // ── مناطق وشوارع رئيسية ──
    SuwayraPlace(name: 'مركز المدينة', latitude: 32.9256, longitude: 44.7766),
    SuwayraPlace(name: 'منطقة الكورنيش', latitude: 32.9380, longitude: 44.7820),
    SuwayraPlace(name: 'منطقة البساتين', latitude: 32.9380, longitude: 44.7680),
    SuwayraPlace(name: 'منطقة الخط السريع', latitude: 32.9280, longitude: 44.7900),
    SuwayraPlace(name: 'منطقة السدة', latitude: 32.9120, longitude: 44.7800),
    SuwayraPlace(name: 'منطقة النهرين', latitude: 32.9400, longitude: 44.7840),
    SuwayraPlace(name: 'منطقة الكاطون', latitude: 32.9150, longitude: 44.7700),
    SuwayraPlace(name: 'منطقة البو عيسى', latitude: 32.9100, longitude: 44.7850),
    SuwayraPlace(name: 'منطقة المطامير', latitude: 32.9420, longitude: 44.7700),
    SuwayraPlace(name: 'منطقة أبو حريج', latitude: 32.9080, longitude: 44.7750),
    SuwayraPlace(name: 'منطقة العباسية', latitude: 32.9440, longitude: 44.7860),
    SuwayraPlace(name: 'منطقة الحسينية', latitude: 32.9400, longitude: 44.7600),
    SuwayraPlace(name: 'منطقة الجدولة', latitude: 32.9140, longitude: 44.7900),
    SuwayraPlace(name: 'منطقة الشاكرية', latitude: 32.9300, longitude: 44.7920),
    SuwayraPlace(name: 'منطقة المغيرات', latitude: 32.9460, longitude: 44.7740),
    SuwayraPlace(name: 'شارع بغداد', latitude: 32.9260, longitude: 44.7880),
    SuwayraPlace(name: 'شارع المستشفى', latitude: 32.9250, longitude: 44.7700),
    SuwayraPlace(name: 'شارع الكوت', latitude: 32.9270, longitude: 44.7800),
    SuwayraPlace(name: 'شارع الناصرية', latitude: 32.9240, longitude: 44.7740),
    SuwayraPlace(name: 'شارع المدارس', latitude: 32.9230, longitude: 44.7660),
    SuwayraPlace(name: 'شارع المحكمة', latitude: 32.9260, longitude: 44.7780),
    SuwayraPlace(name: 'شارع البلدية', latitude: 32.9255, longitude: 44.7775),
    SuwayraPlace(name: 'شارع الأطباء', latitude: 32.9245, longitude: 44.7690),
    SuwayraPlace(name: 'شارع المصارف', latitude: 32.9265, longitude: 44.7790),
    SuwayraPlace(name: 'طريق الصويرة - الكوت', latitude: 32.9300, longitude: 44.8000),
    SuwayraPlace(name: 'طريق الصويرة - واسط', latitude: 32.9200, longitude: 44.7600),
    SuwayraPlace(name: 'طريق الصويرة - بغداد', latitude: 32.9300, longitude: 44.8100),

    // ── أسواق ومحلات تجارية ──
    SuwayraPlace(name: 'سوق الصويرة الكبير', latitude: 32.9260, longitude: 44.7770),
    SuwayraPlace(name: 'سوق الخضار المركزي', latitude: 32.9270, longitude: 44.7765),
    SuwayraPlace(name: 'سوق المواد الغذائية', latitude: 32.9265, longitude: 44.7775),
    SuwayraPlace(name: 'سوق الذهب', latitude: 32.9262, longitude: 44.7772),
    SuwayraPlace(name: 'سوق الملابس', latitude: 32.9268, longitude: 44.7778),
    SuwayraPlace(name: 'مجمع العبدالله التجاري', latitude: 32.9275, longitude: 44.7785),
    SuwayraPlace(name: 'أسواق العروبة', latitude: 32.9285, longitude: 44.7815),
    SuwayraPlace(name: 'أسواق آل حسوني', latitude: 32.9482, longitude: 44.7775),
    SuwayraPlace(name: 'بازار ومطاعم الغيث', latitude: 32.9489, longitude: 44.7767),
    SuwayraPlace(name: 'مجمع الجوهرة التجاري', latitude: 32.9270, longitude: 44.7790),
    SuwayraPlace(name: 'سوق الحرفيين', latitude: 32.9280, longitude: 44.7760),

    // ── مدارس ومؤسسات تعليمية ──
    SuwayraPlace(name: 'جامعة واسط - كلية الصويرة', latitude: 32.9310, longitude: 44.7660),
    SuwayraPlace(name: 'مدرسة الصويرة الابتدائية', latitude: 32.9245, longitude: 44.7680),
    SuwayraPlace(name: 'مدرسة الصويرة المتوسطة', latitude: 32.9235, longitude: 44.7670),
    SuwayraPlace(name: 'مدرسة الصويرة الإعدادية', latitude: 32.9240, longitude: 44.7665),
    SuwayraPlace(name: 'ثانوية الصويرة للبنين', latitude: 32.9255, longitude: 44.7655),
    SuwayraPlace(name: 'ثانوية الصويرة للبنات', latitude: 32.9260, longitude: 44.7660),
    SuwayraPlace(name: 'معهد الصويرة التقني', latitude: 32.9300, longitude: 44.7650),
    SuwayraPlace(name: 'روضة الصويرة', latitude: 32.9250, longitude: 44.7690),

    // ── مؤسسات حكومية ──
    SuwayraPlace(name: 'قائمقامية قضاء الصويرة', latitude: 32.9258, longitude: 44.7770),
    SuwayraPlace(name: 'دائرة بلدية الصويرة', latitude: 32.9250, longitude: 44.7775),
    SuwayraPlace(name: 'مركز شرطة الصويرة', latitude: 32.9265, longitude: 44.7750),
    SuwayraPlace(name: 'مكتب بريد الصويرة', latitude: 32.9260, longitude: 44.7760),
    SuwayraPlace(name: 'محكمة الصويرة', latitude: 32.9262, longitude: 44.7785),
    SuwayraPlace(name: 'دائرة تسجيل العقارات', latitude: 32.9255, longitude: 44.7770),
    SuwayraPlace(name: 'دائرة الكهرباء', latitude: 32.9270, longitude: 44.7755),
    SuwayraPlace(name: 'دائرة الماء', latitude: 32.9275, longitude: 44.7745),
    SuwayraPlace(name: 'دائرة الزراعة', latitude: 32.9268, longitude: 44.7765),
    SuwayraPlace(name: 'مركز صحي الصويرة', latitude: 32.9248, longitude: 44.7705),

    // ── مساجد ودور عبادة ──
    SuwayraPlace(name: 'جامع الصويرة الكبير', latitude: 32.9263, longitude: 44.7768),
    SuwayraPlace(name: 'جامع الأبرار', latitude: 32.9285, longitude: 44.7740),
    SuwayraPlace(name: 'جامع الفرقان', latitude: 32.9240, longitude: 44.7730),
    SuwayraPlace(name: 'جامع الرحمن', latitude: 32.9300, longitude: 44.7750),
    SuwayraPlace(name: 'جامع النور', latitude: 32.9220, longitude: 44.7780),
    SuwayraPlace(name: 'جامع التقوى', latitude: 32.9260, longitude: 44.7720),
    SuwayraPlace(name: 'جامع الهدى', latitude: 32.9340, longitude: 44.7760),
    SuwayraPlace(name: 'جامع السلام', latitude: 32.9200, longitude: 44.7760),
    SuwayraPlace(name: 'حسينية الصويرة', latitude: 32.9270, longitude: 44.7780),
    SuwayraPlace(name: 'مزار سيد أحمد', latitude: 32.9280, longitude: 44.7840),

    // ── القرى التابعة للصويرة ──
    SuwayraPlace(name: 'قرية الرسالة', latitude: 32.9500, longitude: 44.7500),
    SuwayraPlace(name: 'قرية الدواغنة', latitude: 32.9100, longitude: 44.7400),
    SuwayraPlace(name: 'قرية الرحمانية', latitude: 32.9000, longitude: 44.8000),
    SuwayraPlace(name: 'قرية البو شمخي', latitude: 32.8950, longitude: 44.7700),
    SuwayraPlace(name: 'قرية السيد عويد', latitude: 32.8800, longitude: 44.7900),
    SuwayraPlace(name: 'قرية البو ناصر', latitude: 32.8850, longitude: 44.7600),
    SuwayraPlace(name: 'قرية البو حيدر', latitude: 32.8700, longitude: 44.7850),
    SuwayraPlace(name: 'قرية البو جاسم', latitude: 32.8900, longitude: 44.7750),
    SuwayraPlace(name: 'قرية البو علوان', latitude: 32.9050, longitude: 44.7650),
    SuwayraPlace(name: 'قرية الرشيد', latitude: 32.8950, longitude: 44.8100),
    SuwayraPlace(name: 'قرية الفلاحات', latitude: 32.9150, longitude: 44.7950),
    SuwayraPlace(name: 'قرية الكريعات', latitude: 32.9200, longitude: 44.7300),
    SuwayraPlace(name: 'قرية البو سلطان', latitude: 32.9080, longitude: 44.7550),
    SuwayraPlace(name: 'قرية الحمزة', latitude: 32.8980, longitude: 44.7850),
    SuwayraPlace(name: 'قرية الصالحية', latitude: 32.9120, longitude: 44.7450),
    SuwayraPlace(name: 'قرية المحمودية', latitude: 32.9020, longitude: 44.7950),
    SuwayraPlace(name: 'قرية الحسن', latitude: 32.8880, longitude: 44.7800),
    SuwayraPlace(name: 'قرية الحيدرية', latitude: 32.8920, longitude: 44.7650),
    SuwayraPlace(name: 'قرية الكرامة الشمالية', latitude: 32.9520, longitude: 44.7600),

    // ── مناطق زراعية وصناعية ──
    SuwayraPlace(name: 'شبه جزيرة ربيضة', latitude: 32.9300, longitude: 44.8200),
    SuwayraPlace(name: 'منطقة تل عقيل', latitude: 32.9600, longitude: 44.7900),
    SuwayraPlace(name: 'منطقة أبو صخير', latitude: 32.9400, longitude: 44.8000),
    SuwayraPlace(name: 'منطقة البو جابر', latitude: 32.9500, longitude: 44.7700),
    SuwayraPlace(name: 'منطقة السواعدة', latitude: 32.9600, longitude: 44.7600),
    SuwayraPlace(name: 'منطقة الدغارة', latitude: 32.9700, longitude: 44.7800),
    SuwayraPlace(name: 'منطقة الشوملي', latitude: 32.9550, longitude: 44.7850),
    SuwayraPlace(name: 'منطقة الحفر', latitude: 32.9450, longitude: 44.7950),
    SuwayraPlace(name: 'منطقة البو عاصي', latitude: 32.9350, longitude: 44.8100),
    SuwayraPlace(name: 'منطقة السلمان', latitude: 32.9250, longitude: 44.8200),
    SuwayraPlace(name: 'منطقة البحيرات', latitude: 32.9480, longitude: 44.7900),
    SuwayraPlace(name: 'منطقة أبو طويرق', latitude: 32.9650, longitude: 44.7700),
    SuwayraPlace(name: 'منطقة حوض دجلة', latitude: 32.9420, longitude: 44.8080),

    // ── منتزهات وترفيه ──
    SuwayraPlace(name: 'منتزه الصويرة الترفيهي', latitude: 32.9320, longitude: 44.7850),
    SuwayraPlace(name: 'حديقة الصويرة العامة', latitude: 32.9250, longitude: 44.7750),
    SuwayraPlace(name: 'حديقة الأهوار', latitude: 32.9230, longitude: 44.7800),
    SuwayraPlace(name: 'ملعب الصويرة الرياضي', latitude: 32.9225, longitude: 44.7680),
    SuwayraPlace(name: 'النادي الرياضي', latitude: 32.9230, longitude: 44.7690),
    SuwayraPlace(name: 'صالة الألعاب الرياضية', latitude: 32.9220, longitude: 44.7670),

    // ── فنادق واستراحات ──
    SuwayraPlace(name: 'فندق الصويرة', latitude: 32.9265, longitude: 44.7775),
    SuwayraPlace(name: 'فندق الأبرار', latitude: 32.9280, longitude: 44.7790),
    SuwayraPlace(name: 'استراحة الكورنيش', latitude: 32.9385, longitude: 44.7825),
    SuwayraPlace(name: 'استراحة البساتين', latitude: 32.9370, longitude: 44.7670),

    // ── مطاعم ومقاهي ──
    SuwayraPlace(name: 'مطعم طربوش الحلبي', latitude: 32.9262, longitude: 44.7765),
    SuwayraPlace(name: 'مطعم أكالو', latitude: 32.9475, longitude: 44.7764),
    SuwayraPlace(name: 'مطعم الركن العراقي', latitude: 32.9270, longitude: 44.7770),
    SuwayraPlace(name: 'مطعم البغدادي', latitude: 32.9268, longitude: 44.7780),
    SuwayraPlace(name: 'مطعم الأندلس', latitude: 32.9285, longitude: 44.7800),
    SuwayraPlace(name: 'مطعم الفرات', latitude: 32.9250, longitude: 44.7760),
    SuwayraPlace(name: 'مقهى الصويرة الشعبي', latitude: 32.9265, longitude: 44.7760),
    SuwayraPlace(name: 'مقهى الكورنيش', latitude: 32.9382, longitude: 44.7822),
    SuwayraPlace(name: 'كافيه الأبرار', latitude: 32.9275, longitude: 44.7785),
    SuwayraPlace(name: 'معجنات الصويرة', latitude: 32.9263, longitude: 44.7773),

    // ── محطات وقود وخدمات ──
    SuwayraPlace(name: 'محطة وقود الصويرة المركزية', latitude: 32.9270, longitude: 44.7780),
    SuwayraPlace(name: 'محطة وقود الشهداء', latitude: 32.9185, longitude: 44.7745),
    SuwayraPlace(name: 'محطة وقود الكورنيش', latitude: 32.9385, longitude: 44.7830),
    SuwayraPlace(name: 'محطة وقود الخط السريع', latitude: 32.9285, longitude: 44.7905),
    SuwayraPlace(name: 'مركز خدمة السيارات', latitude: 32.9280, longitude: 44.7795),
    SuwayraPlace(name: 'مغيسل سيارات', latitude: 32.9275, longitude: 44.7800),
    SuwayraPlace(name: 'كوزمتك الرمال', latitude: 32.9258, longitude: 44.7772),

    // ── مواقع Google Maps ──
    SuwayraPlace(name: 'فلكة عبدالكريم قاسم الصويرة', latitude: 32.9469, longitude: 44.7768),
    SuwayraPlace(name: 'جامع العابد', latitude: 32.9471, longitude: 44.7752),
    SuwayraPlace(name: 'ثانوية سعيد بن جبير', latitude: 32.9475, longitude: 44.7755),
    SuwayraPlace(name: 'مضيف الشيخ محمود نواف العجرش', latitude: 32.9464, longitude: 44.7759),
    SuwayraPlace(name: 'شركة الاصدقاء لتجارة السيارات العامة', latitude: 32.9448, longitude: 44.7770),
    SuwayraPlace(name: 'مشروع دجلة التجاري الاستثماري', latitude: 32.9445, longitude: 44.7767),
    SuwayraPlace(name: 'مضيف الشيخ أبو عباس البديري', latitude: 32.9432, longitude: 44.7771),
    SuwayraPlace(name: 'أسواق بركات الحسين', latitude: 32.9424, longitude: 44.7768),
    SuwayraPlace(name: 'مطعم دجلة الخير', latitude: 32.9424, longitude: 44.7751),
    SuwayraPlace(name: 'هايبر ماركت العطاء', latitude: 32.9413, longitude: 44.7747),
    SuwayraPlace(name: 'نادي الزعيم الرياضي', latitude: 32.9403, longitude: 44.7771),
    SuwayraPlace(name: 'محطة الحاج حمزة دعيل', latitude: 32.9399, longitude: 44.7740),
    SuwayraPlace(name: 'معرض الحرة لتجارة السيارات', latitude: 32.9396, longitude: 44.7754),
    SuwayraPlace(name: 'معرض النجوم لتجارة السيارات الحديثة', latitude: 32.9404, longitude: 44.7744),
    SuwayraPlace(name: 'معرض الزعيم لتجارة واستيراد السيارات الحديثة', latitude: 32.9395, longitude: 44.7743),
    SuwayraPlace(name: 'مصلى وحسينية أمير المؤمنين (عليه السلام)', latitude: 32.9390, longitude: 44.7761),
    SuwayraPlace(name: 'معرض دبي لتجارة السيارات الحديثة في الصويرة', latitude: 32.9380, longitude: 44.7744),
    SuwayraPlace(name: 'معرض الحاج كامل الكلابي لتجارة السيارات الحديثة', latitude: 32.9364, longitude: 44.7731),
    SuwayraPlace(name: 'معرض أنوار البشير', latitude: 32.9362, longitude: 44.7732),
    SuwayraPlace(name: 'معرض الكريم بإدارة محمد الشمري', latitude: 32.9370, longitude: 44.7736),
    SuwayraPlace(name: 'صيدلية ضرغام سعد', latitude: 32.9356, longitude: 44.7723),
    SuwayraPlace(name: 'سوق التقاطع', latitude: 32.9340, longitude: 44.7723),
    SuwayraPlace(name: 'مندي تعز اليمن', latitude: 32.9333, longitude: 44.7720),
    SuwayraPlace(name: 'المركز التخصصي لطب الأسنان في الصويرة', latitude: 32.9328, longitude: 44.7742),
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
    SuwayraPlace(name: 'أسواق آل حسوني', latitude: 32.9482, longitude: 44.7775),
    SuwayraPlace(name: 'بازار ومطاعم الغيث', latitude: 32.9489, longitude: 44.7767),
    SuwayraPlace(name: 'مطعم أكالو', latitude: 32.9475, longitude: 44.7764),
    SuwayraPlace(name: 'فلكة عبدالكريم قاسم الصويرة', latitude: 32.9469, longitude: 44.7768),
    SuwayraPlace(name: 'جامع العابد', latitude: 32.9471, longitude: 44.7752),
    SuwayraPlace(name: 'ثانوية سعيد بن جبير', latitude: 32.9475, longitude: 44.7755),
    SuwayraPlace(name: 'مضيف الشيخ محمود نواف العجرش', latitude: 32.9464, longitude: 44.7759),
    SuwayraPlace(name: 'شركة الاصدقاء لتجارة السيارات العامة', latitude: 32.9448, longitude: 44.7770),
    SuwayraPlace(name: 'مشروع دجلة التجاري الاستثماري', latitude: 32.9445, longitude: 44.7767),
    SuwayraPlace(name: 'مضيف الشيخ أبو عباس البديري', latitude: 32.9432, longitude: 44.7771),
    SuwayraPlace(name: 'أسواق بركات الحسين', latitude: 32.9424, longitude: 44.7768),
    SuwayraPlace(name: 'مطعم دجلة الخير', latitude: 32.9424, longitude: 44.7751),
    SuwayraPlace(name: 'هايبر ماركت العطاء', latitude: 32.9413, longitude: 44.7747),
    SuwayraPlace(name: 'نادي الزعيم الرياضي', latitude: 32.9403, longitude: 44.7771),
    SuwayraPlace(name: 'محطة الحاج حمزة دعيل', latitude: 32.9399, longitude: 44.7740),
    SuwayraPlace(name: 'معرض الحرة لتجارة السيارات', latitude: 32.9396, longitude: 44.7754),
    SuwayraPlace(name: 'معرض النجوم لتجارة السيارات الحديثة', latitude: 32.9404, longitude: 44.7744),
    SuwayraPlace(name: 'معرض الزعيم لتجارة واستيراد السيارات الحديثة', latitude: 32.9395, longitude: 44.7743),
    SuwayraPlace(name: 'مصلى وحسينية أمير المؤمنين (عليه السلام)', latitude: 32.9390, longitude: 44.7761),
    SuwayraPlace(name: 'معرض دبي لتجارة السيارات الحديثة في الصويرة', latitude: 32.9380, longitude: 44.7744),
    SuwayraPlace(name: 'معرض الحاج كامل الكلابي لتجارة السيارات الحديثة', latitude: 32.9364, longitude: 44.7731),
    SuwayraPlace(name: 'معرض أنوار البشير', latitude: 32.9362, longitude: 44.7732),
    SuwayraPlace(name: 'معرض الكريم بإدارة محمد الشمري', latitude: 32.9370, longitude: 44.7736),
    SuwayraPlace(name: 'صيدلية ضرغام سعد', latitude: 32.9356, longitude: 44.7723),
    SuwayraPlace(name: 'سوق التقاطع', latitude: 32.9340, longitude: 44.7723),
    SuwayraPlace(name: 'مندي تعز اليمن', latitude: 32.9333, longitude: 44.7720),
    SuwayraPlace(name: 'المركز التخصصي لطب الأسنان في الصويرة', latitude: 32.9328, longitude: 44.7742),
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
    'أسواق آل حسوني',
    'بازار ومطاعم الغيث',
    'مطعم أكالو',
    'فلكة عبدالكريم قاسم الصويرة',
    'جامع العابد',
    'ثانوية سعيد بن جبير',
    'مضيف الشيخ محمود نواف العجرش',
    'شركة الاصدقاء لتجارة السيارات العامة',
    'مشروع دجلة التجاري الاستثماري',
    'مضيف الشيخ أبو عباس البديري',
    'أسواق بركات الحسين',
    'مطعم دجلة الخير',
    'هايبر ماركت العطاء',
    'نادي الزعيم الرياضي',
    'محطة الحاج حمزة دعيل',
    'معرض الحرة لتجارة السيارات',
    'معرض النجوم لتجارة السيارات الحديثة',
    'معرض الزعيم لتجارة واستيراد السيارات الحديثة',
    'مصلى وحسينية أمير المؤمنين (عليه السلام)',
    'معرض دبي لتجارة السيارات الحديثة في الصويرة',
    'معرض الحاج كامل الكلابي لتجارة السيارات الحديثة',
    'معرض أنوار البشير',
    'معرض الكريم بإدارة محمد الشمري',
    'صيدلية ضرغام سعد',
    'سوق التقاطع',
    'مندي تعز اليمن',
    'المركز التخصصي لطب الأسنان في الصويرة',
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
