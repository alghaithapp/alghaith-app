import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';

import 'package:alghaith_app/models/app_models.dart';
import 'package:alghaith_app/providers/app_provider.dart';
import 'package:alghaith_app/screens/cart_screen.dart';
import 'package:alghaith_app/utils/extensions.dart';
import '../mocks/app_provider.dart';

void main() {
  late MockAppProvider mock;

  setUp(() {
    mock = MockAppProvider();
  });

  Widget buildWidget() {
    return MaterialApp(
      home: ChangeNotifierProvider<AppProvider>.value(
        value: mock,
        child: const CartScreen(),
      ),
    );
  }

  group('CartScreen', () {
    testWidgets('shows empty cart message when no items', (tester) async {
      when(() => mock.cart).thenReturn([]);
      when(() => mock.cartTotal).thenReturn(0);
      when(() => mock.cartPromoDiscountIqd).thenReturn(0);
      when(() => mock.customerAddress).thenReturn('');
      when(() => mock.customerLatitude).thenReturn(null);
      when(() => mock.customerLongitude).thenReturn(null);
      when(() => mock.goToCustomerHomeTab()).thenReturn(null);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('سلتك فارغة حالياً'), findsOneWidget);
    });

    testWidgets('shows cart items when items exist', (tester) async {
      final cartItem = CartItem(
        id: '1',
        nameAr: 'منتج اختبار',
        nameEn: 'Test Item',
        price: 5000,
        count: 2,
        image: '',
        category: 'product',
      );

      when(() => mock.cart).thenReturn([cartItem]);
      when(() => mock.cartTotal).thenReturn(10000);
      when(() => mock.cartPromoDiscountIqd).thenReturn(0);
      when(() => mock.customerAddress).thenReturn('');
      when(() => mock.customerLatitude).thenReturn(null);
      when(() => mock.customerLongitude).thenReturn(null);
      when(() => mock.cartHasMultipleMerchants).thenReturn(false);
      when(() => mock.isFavoriteId(any())).thenReturn(false);
      when(() => mock.goToCustomerHomeTab()).thenReturn(null);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('سلة المشتريات'), findsOneWidget);
      expect(find.text('منتج اختبار'), findsOneWidget);
    });

    testWidgets('shows total price', (tester) async {
      final cartItem = CartItem(
        id: '1',
        nameAr: 'منتج اختبار',
        nameEn: 'Test Item',
        price: 5000,
        count: 2,
        image: '',
        category: 'product',
      );

      when(() => mock.cart).thenReturn([cartItem]);
      when(() => mock.cartTotal).thenReturn(10000);
      when(() => mock.cartPromoDiscountIqd).thenReturn(0);
      when(() => mock.customerAddress).thenReturn('');
      when(() => mock.customerLatitude).thenReturn(null);
      when(() => mock.customerLongitude).thenReturn(null);
      when(() => mock.cartHasMultipleMerchants).thenReturn(false);
      when(() => mock.isFavoriteId(any())).thenReturn(false);
      when(() => mock.goToCustomerHomeTab()).thenReturn(null);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('د.ع'), findsWidgets);
    });

    testWidgets('shows checkout button', (tester) async {
      final cartItem = CartItem(
        id: '1',
        nameAr: 'منتج اختبار',
        nameEn: 'Test Item',
        price: 5000,
        count: 2,
        image: '',
        category: 'product',
      );

      when(() => mock.cart).thenReturn([cartItem]);
      when(() => mock.cartTotal).thenReturn(10000);
      when(() => mock.cartPromoDiscountIqd).thenReturn(0);
      when(() => mock.customerAddress).thenReturn('');
      when(() => mock.customerLatitude).thenReturn(null);
      when(() => mock.customerLongitude).thenReturn(null);
      when(() => mock.cartHasMultipleMerchants).thenReturn(false);
      when(() => mock.isFavoriteId(any())).thenReturn(false);
      when(() => mock.goToCustomerHomeTab()).thenReturn(null);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('إتمام الطلب'), findsOneWidget);
    });
  });
}
