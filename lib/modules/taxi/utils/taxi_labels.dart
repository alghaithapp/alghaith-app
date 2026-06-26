/// نصوص واجهة الزبون في خدمة التكسي — مصطلح «كابتن» للسائق.
class TaxiLabels {
  TaxiLabels._();

  static const captain = 'كابتن';
  static const theCaptain = 'الكابتن';

  static String captainName(String? name) {
    final value = name?.trim() ?? '';
    return value.isNotEmpty ? value : theCaptain;
  }
}
