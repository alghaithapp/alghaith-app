import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';

import 'package:alghaith_app/models/app_models.dart';
import 'package:alghaith_app/providers/app_provider.dart';
import 'package:alghaith_app/screens/orders_screen.dart';
import '../mocks/app_provider.dart';

void main() {
  late MockAppProvider mock;

  setUpAll(() {
    registerFallbackValue(ActiveOrder(
      id: '',
      orderNumber: '',
      dateAr: '',
      dateEn: '',
      statusKey: '',
      statusAr: '',
      statusEn: '',
      price: 0,
      itemsCount: 0,
      itemsNameAr: '',
      itemsNameEn: '',
    ));
  });

  setUp(() {
    mock = MockAppProvider();
  });

  Widget buildWidget() {
    return MaterialApp(
      home: ChangeNotifierProvider<AppProvider>.value(
        value: mock,
        child: const OrdersScreen(),
      ),
    );
  }

  group('OrdersScreen', () {
    testWidgets('shows empty orders message when no orders', (tester) async {
      when(() => mock.orders).thenReturn([]);
      when(() => mock.refreshCustomerOrders()).thenAnswer((_) async {});

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('لا توجد طلبات حالية'), findsOneWidget);
    });

    testWidgets('shows order list when orders exist', (tester) async {
      final order = ActiveOrder(
        id: 'order-1',
        orderNumber: '12345',
        dateAr: '15 يناير 2024',
        dateEn: '2024-01-15',
        statusKey: 'accepted',
        statusAr: 'قيد التحضير',
        statusEn: 'Preparing',
        price: 15000,
        itemsCount: 3,
        itemsNameAr: 'عناصر الطلب',
        itemsNameEn: 'Order Items',
      );

      when(() => mock.orders).thenReturn([order]);
      when(() => mock.refreshCustomerOrders()).thenAnswer((_) async {});
      when(() => mock.orderElapsedLabelAr(any())).thenReturn('منذ 5 دقائق');
      when(() => mock.goToCustomerHomeTab()).thenReturn(null);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('قيد التحضير'), findsOneWidget);
      expect(find.text('طلب 1'), findsOneWidget);
    });

    testWidgets('shows order status in each tile', (tester) async {
      final order = ActiveOrder(
        id: 'order-2',
        orderNumber: '67890',
        dateAr: '20 يناير 2024',
        dateEn: '2024-01-20',
        statusKey: 'accepted',
        statusAr: 'قيد التحضير',
        statusEn: 'Preparing',
        price: 25000,
        itemsCount: 2,
        itemsNameAr: 'وجبات',
        itemsNameEn: 'Meals',
      );

      when(() => mock.orders).thenReturn([order]);
      when(() => mock.refreshCustomerOrders()).thenAnswer((_) async {});
      when(() => mock.orderElapsedLabelAr(any())).thenReturn('منذ 10 دقائق');
      when(() => mock.goToCustomerHomeTab()).thenReturn(null);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('قيد التحضير'), findsOneWidget);
    });
  });
}
