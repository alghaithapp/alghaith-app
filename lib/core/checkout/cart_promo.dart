class CartPromoDefinition {
  final String code;
  final String labelAr;
  final String labelEn;
  final String discountType;
  final int discountValue;
  final int minSubtotalIqd;
  final int? maxDiscountIqd;

  const CartPromoDefinition({
    required this.code,
    required this.labelAr,
    required this.labelEn,
    required this.discountType,
    required this.discountValue,
    required this.minSubtotalIqd,
    this.maxDiscountIqd,
  });

  factory CartPromoDefinition.fromMap(Map<String, dynamic> map) {
    return CartPromoDefinition(
      code: map['code']?.toString() ?? '',
      labelAr: map['labelAr']?.toString() ?? '',
      labelEn: map['labelEn']?.toString() ?? '',
      discountType: map['discountType']?.toString() ?? 'percent',
      discountValue: (map['discountValue'] as num?)?.toInt() ?? 0,
      minSubtotalIqd: (map['minSubtotalIqd'] as num?)?.toInt() ?? 0,
      maxDiscountIqd: (map['maxDiscountIqd'] as num?)?.toInt(),
    );
  }

  int discountForSubtotal(int subtotalIqd) {
    final subtotal = subtotalIqd > 0 ? subtotalIqd : 0;
    if (subtotal < minSubtotalIqd) return 0;

    var discount = discountType == 'fixed'
        ? discountValue
        : ((subtotal * discountValue) / 100).round();
    final maxDiscount = maxDiscountIqd;
    if (maxDiscount != null && maxDiscount > 0) {
      discount = discount > maxDiscount ? maxDiscount : discount;
    }
    if (discount > subtotal) return subtotal;
    return discount > 0 ? discount : 0;
  }
}

class CartPromoApplyResult {
  final bool success;
  final String messageAr;
  final CartPromoDefinition? promo;
  final int discountAmountIqd;

  const CartPromoApplyResult({
    required this.success,
    required this.messageAr,
    this.promo,
    this.discountAmountIqd = 0,
  });
}
