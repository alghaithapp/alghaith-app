import 'package:flutter_test/flutter_test.dart';
import 'package:alghaith_app/models/app_models.dart';
import 'package:alghaith_app/models/merchant_models.dart';
import 'package:alghaith_app/core/checkout/cart_promo.dart';

ActiveOrder _order({
  required String id,
  required String statusKey,
  String noteAr = '',
  String noteEn = '',
  int price = 10000,
  int itemsCount = 3,
  String? merchantDecisionAt,
}) {
  return ActiveOrder(
    id: id,
    orderNumber: 'ORD-$id',
    dateAr: '2024-01-15',
    dateEn: '2024-01-15',
    statusKey: statusKey,
    statusAr: '',
    statusEn: '',
    price: price,
    itemsCount: itemsCount,
    itemsNameAr: 'منتج أ, منتج ب',
    itemsNameEn: 'Product A, Product B',
    noteAr: noteAr,
    noteEn: noteEn,
    merchantDecisionAt: merchantDecisionAt,
  );
}

void main() {
  group('ActiveOrder status helpers', () {
    test('pending order statusKey is pending', () {
      final order = _order(id: '1', statusKey: 'pending');
      expect(order.statusKey, 'pending');
    });

    test('accepted order statusKey is accepted', () {
      final order = _order(id: '2', statusKey: 'accepted');
      expect(order.statusKey, 'accepted');
    });

    test('completed order statusKey is completed', () {
      final order = _order(id: '3', statusKey: 'completed');
      expect(order.statusKey, 'completed');
    });

    test('cancelled order statusKey is cancelled', () {
      final order = _order(id: '4', statusKey: 'cancelled');
      expect(order.statusKey, 'cancelled');
    });

    test('copyWith changes statusKey', () {
      final order = _order(id: '5', statusKey: 'pending');
      final updated = order.copyWith(
        statusKey: 'accepted',
        statusAr: 'تم القبول',
        statusEn: 'Accepted',
      );
      expect(updated.statusKey, 'accepted');
      expect(updated.statusAr, 'تم القبول');
      expect(updated.statusEn, 'Accepted');
      expect(updated.id, order.id);
    });

    test('copyWith preserves unchanged fields', () {
      final order = _order(id: '6', statusKey: 'pending', price: 25000);
      final updated = order.copyWith(statusKey: 'accepted');
      expect(updated.id, '6');
      expect(updated.price, 25000);
      expect(updated.itemsCount, 3);
    });
  });

  group('Merchant order filtering', () {
    test('filters pending orders', () {
      final orders = [
        _order(id: '1', statusKey: 'pending'),
        _order(id: '2', statusKey: 'accepted'),
        _order(id: '3', statusKey: 'completed'),
      ];
      final pending = orders.where((o) => o.statusKey == 'pending').toList();
      expect(pending.length, 1);
      expect(pending.first.id, '1');
    });

    test('filters active orders (accepted/delivering/preparing)', () {
      final orders = [
        _order(id: '1', statusKey: 'pending'),
        _order(id: '2', statusKey: 'accepted'),
        _order(id: '3', statusKey: 'preparing'),
        _order(id: '4', statusKey: 'delivering'),
        _order(id: '5', statusKey: 'completed'),
      ];
      final active = orders.where((o) =>
          o.statusKey == 'accepted' ||
          o.statusKey == 'preparing' ||
          o.statusKey == 'delivering').toList();
      expect(active.length, 3);
      expect(active.map((o) => o.id), containsAll(['2', '3', '4']));
    });

    test('filters completed orders', () {
      final orders = [
        _order(id: '1', statusKey: 'pending'),
        _order(id: '2', statusKey: 'completed'),
        _order(id: '3', statusKey: 'completed'),
      ];
      final completed = orders.where((o) => o.statusKey == 'completed').toList();
      expect(completed.length, 2);
    });

    test('filters cancelled orders', () {
      final orders = [
        _order(id: '1', statusKey: 'pending'),
        _order(id: '2', statusKey: 'cancelled'),
        _order(id: '3', statusKey: 'completed'),
      ];
      final cancelled = orders.where((o) => o.statusKey == 'cancelled').toList();
      expect(cancelled.length, 1);
    });

    test('status transition: pending -> accepted', () {
      final order = _order(id: '1', statusKey: 'pending');
      expect(order.statusKey, 'pending');

      final accepted = order.copyWith(
        statusKey: 'accepted',
        statusAr: 'تم القبول',
        statusEn: 'Accepted',
      );
      expect(accepted.statusKey, 'accepted');
    });

    test('status transition: accepted -> delivering', () {
      final order = _order(id: '2', statusKey: 'accepted');
      final delivering = order.copyWith(
        statusKey: 'delivering',
        statusAr: 'جاري التوصيل',
        statusEn: 'Delivering',
      );
      expect(delivering.statusKey, 'delivering');
    });

    test('status transition: delivering -> completed', () {
      final order = _order(id: '3', statusKey: 'delivering');
      final completed = order.copyWith(
        statusKey: 'completed',
        statusAr: 'مكتمل',
        statusEn: 'Completed',
      );
      expect(completed.statusKey, 'completed');
    });

    test('status transition: pending -> cancelled', () {
      final order = _order(id: '4', statusKey: 'pending');
      final cancelled = order.copyWith(
        statusKey: 'cancelled',
        statusAr: 'ملغي',
        statusEn: 'Cancelled',
      );
      expect(cancelled.statusKey, 'cancelled');
    });

    test('merchant rejected order detection by note prefix', () {
      final rejected = _order(
        id: '5',
        statusKey: 'cancelled',
        noteAr: 'سبب الرفض: المنتج غير متوفر',
      );
      final isRejected = rejected.statusKey == 'cancelled' &&
          rejected.noteAr.startsWith('سبب الرفض:');
      expect(isRejected, isTrue);

      final cancelledByCustomer = _order(
        id: '6',
        statusKey: 'cancelled',
        noteAr: 'ألغى الزبون الطلب',
      );
      final isNotRejected = cancelledByCustomer.statusKey == 'cancelled' &&
          cancelledByCustomer.noteAr.startsWith('سبب الرفض:');
      expect(isNotRejected, isFalse);
    });

    test('merchant rejected order detection by English note prefix', () {
      final rejected = _order(
        id: '7',
        statusKey: 'cancelled',
        noteEn: 'Rejected reason: Out of stock',
      );
      final isRejected = rejected.statusKey == 'cancelled' &&
          rejected.noteEn.startsWith('Rejected reason:');
      expect(isRejected, isTrue);
    });

    test('acceptance rate calculation', () {
      final accepted = 4;
      final rejected = 1;
      final decided = accepted + rejected;
      final rate = decided == 0 ? 0 : (accepted / decided) * 100;
      expect(rate, 80.0);
    });

    test('acceptance rate is 0 when no decisions', () {
      final accepted = 0;
      final rejected = 0;
      final decided = accepted + rejected;
      final rate = decided == 0 ? 0 : (accepted / decided) * 100;
      expect(rate, 0.0);
    });
  });

  group('MerchantOffer', () {
    test('fromMap parses correctly', () {
      final map = <String, dynamic>{
        'id': 'offer1',
        'titleAr': 'عرض خاص',
        'titleEn': 'Special Offer',
        'discountPercent': 20,
        'startDate': '2024-01-01',
        'endDate': '2024-01-31',
        'productNamesAr': ['منتج أ', 'منتج ب'],
        'isActive': true,
      };
      final offer = MerchantOffer.fromMap(map);
      expect(offer.id, 'offer1');
      expect(offer.titleAr, 'عرض خاص');
      expect(offer.discountPercent, 20);
      expect(offer.productNamesAr, ['منتج أ', 'منتج ب']);
      expect(offer.isActive, isTrue);
    });

    test('copyWith allows status toggle', () {
      final offer = MerchantOffer(
        id: 'offer1',
        titleAr: 'عرض',
        titleEn: 'Offer',
        discountPercent: 15,
        startDate: '2024-01-01',
        endDate: '2024-01-15',
        productNamesAr: ['منتج'],
        isActive: true,
      );
      final deactivated = offer.copyWith(isActive: false);
      expect(deactivated.isActive, isFalse);
      expect(deactivated.id, 'offer1');
    });

    test('toMap roundtrip', () {
      final offer = MerchantOffer(
        id: 'offer2',
        titleAr: 'تخفيضات',
        titleEn: 'Sales',
        discountPercent: 30,
        startDate: '2024-02-01',
        endDate: '2024-02-28',
        productNamesAr: ['منتج 1', 'منتج 2'],
        isActive: true,
      );
      final map = offer.toMap();
      final restored = MerchantOffer.fromMap(map);
      expect(restored.id, offer.id);
      expect(restored.discountPercent, offer.discountPercent);
      expect(restored.isActive, offer.isActive);
    });
  });

  group('MerchantReview', () {
    test('fromMap parses correctly', () {
      final map = <String, dynamic>{
        'id': 'rev1',
        'customerName': 'أحمد',
        'stars': 5,
        'comment': 'خدمة ممتازة',
        'date': '2024-01-10',
        'reply': 'شكراً لك',
      };
      final review = MerchantReview.fromMap(map);
      expect(review.id, 'rev1');
      expect(review.stars, 5);
      expect(review.reply, 'شكراً لك');
    });

    test('reply is null when not present', () {
      final map = <String, dynamic>{
        'id': 'rev2',
        'customerName': 'محمد',
        'stars': 4,
        'comment': 'جيد',
        'date': '2024-01-11',
      };
      final review = MerchantReview.fromMap(map);
      expect(review.reply, isNull);
    });

    test('copyWith sets reply', () {
      final review = MerchantReview(
        id: 'rev3',
        customerName: 'سارة',
        stars: 3,
        comment: 'متوسط',
        date: '2024-01-12',
      );
      final replied = review.copyWith(reply: 'نعتذر عن الإزعاج');
      expect(replied.reply, 'نعتذر عن الإزعاج');
    });
  });
}
