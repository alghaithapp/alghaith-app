import 'package:flutter_test/flutter_test.dart';
import 'package:alghaith_app/core/checkout/cart_promo.dart';

void main() {
  group('CartPromoDefinition', () {
    group('fromMap', () {
      test('parses all fields correctly', () {
        final map = <String, dynamic>{
          'code': 'SAVE10',
          'labelAr': 'خصم 10%',
          'labelEn': '10% Off',
          'discountType': 'percent',
          'discountValue': 10,
          'minSubtotalIqd': 5000,
          'maxDiscountIqd': 2000,
        };
        final promo = CartPromoDefinition.fromMap(map);
        expect(promo.code, 'SAVE10');
        expect(promo.labelAr, 'خصم 10%');
        expect(promo.labelEn, '10% Off');
        expect(promo.discountType, 'percent');
        expect(promo.discountValue, 10);
        expect(promo.minSubtotalIqd, 5000);
        expect(promo.maxDiscountIqd, 2000);
      });

      test('defaults when fields are missing', () {
        final promo = CartPromoDefinition.fromMap({'code': 'FREE'});
        expect(promo.code, 'FREE');
        expect(promo.labelAr, '');
        expect(promo.discountType, 'percent');
        expect(promo.discountValue, 0);
        expect(promo.minSubtotalIqd, 0);
        expect(promo.maxDiscountIqd, null);
      });

      test('handles numeric discountValue as num', () {
        final promo = CartPromoDefinition.fromMap({
          'code': 'FIXED50',
          'discountType': 'fixed',
          'discountValue': 50.0,
        });
        expect(promo.discountValue, 50);
        expect(promo.discountType, 'fixed');
      });
    });

    group('discountForSubtotal', () {
      test('percent discount', () {
        final promo = CartPromoDefinition(
          code: 'PERCENT10',
          labelAr: 'خصم 10%',
          labelEn: '10% Off',
          discountType: 'percent',
          discountValue: 10,
          minSubtotalIqd: 0,
        );
        expect(promo.discountForSubtotal(10000), 1000);
        expect(promo.discountForSubtotal(5000), 500);
        expect(promo.discountForSubtotal(250), 25);
      });

      test('fixed discount', () {
        final promo = CartPromoDefinition(
          code: 'FIXED50',
          labelAr: 'خصم 50',
          labelEn: '50 IQD Off',
          discountType: 'fixed',
          discountValue: 50,
          minSubtotalIqd: 0,
        );
        expect(promo.discountForSubtotal(10000), 50);
      });

      test('respects minSubtotalIqd', () {
        final promo = CartPromoDefinition(
          code: 'MIN5000',
          labelAr: 'خصم',
          labelEn: 'Discount',
          discountType: 'percent',
          discountValue: 10,
          minSubtotalIqd: 5000,
        );
        expect(promo.discountForSubtotal(3000), 0);
        expect(promo.discountForSubtotal(5000), 500);
        expect(promo.discountForSubtotal(10000), 1000);
      });

      test('respects maxDiscountIqd', () {
        final promo = CartPromoDefinition(
          code: 'MAX1000',
          labelAr: 'خصم',
          labelEn: 'Discount',
          discountType: 'percent',
          discountValue: 50,
          minSubtotalIqd: 0,
          maxDiscountIqd: 1000,
        );
        expect(promo.discountForSubtotal(5000), 1000);
        expect(promo.discountForSubtotal(10000), 1000);
      });

      test('discount does not exceed subtotal', () {
        final promo = CartPromoDefinition(
          code: 'BIGOFF',
          labelAr: 'خصم',
          labelEn: 'Discount',
          discountType: 'fixed',
          discountValue: 10000,
          minSubtotalIqd: 0,
        );
        expect(promo.discountForSubtotal(500), 500);
        expect(promo.discountForSubtotal(0), 0);
      });

      test('negative subtotal is treated as zero', () {
        final promo = CartPromoDefinition(
          code: 'NEG',
          labelAr: 'خصم',
          labelEn: 'Discount',
          discountType: 'percent',
          discountValue: 10,
          minSubtotalIqd: 0,
        );
        expect(promo.discountForSubtotal(-100), 0);
      });

      test('discountForSubtotal returns 0 when value is 0', () {
        final promo = CartPromoDefinition(
          code: 'ZERO',
          labelAr: 'لا خصم',
          labelEn: 'No Discount',
          discountType: 'percent',
          discountValue: 0,
          minSubtotalIqd: 0,
        );
        expect(promo.discountForSubtotal(5000), 0);
      });
    });
  });

  group('CartPromoApplyResult', () {
    test('constructs with success', () {
      final result = CartPromoApplyResult(success: true, messageAr: 'تم');
      expect(result.success, true);
      expect(result.messageAr, 'تم');
      expect(result.promo, null);
      expect(result.discountAmountIqd, 0);
    });

    test('constructs with promo and discount', () {
      final promo = CartPromoDefinition(
        code: 'TEST',
        labelAr: 'اختبار',
        labelEn: 'Test',
        discountType: 'fixed',
        discountValue: 100,
        minSubtotalIqd: 0,
      );
      final result = CartPromoApplyResult(
        success: true,
        messageAr: 'تم التطبيق',
        promo: promo,
        discountAmountIqd: 100,
      );
      expect(result.success, true);
      expect(result.promo?.code, 'TEST');
      expect(result.discountAmountIqd, 100);
    });
  });
}
