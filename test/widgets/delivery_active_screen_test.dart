import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';

import 'package:alghaith_app/models/app_models.dart';
import 'package:alghaith_app/providers/app_provider.dart';
import 'package:alghaith_app/modules/courier/screens/delivery_active_screen.dart';
import 'package:alghaith_app/modules/courier/screens/delivery_shared_widgets.dart';
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
        child: const DeliveryActiveScreen(),
      ),
    );
  }

  group('DeliveryActiveScreen', () {
    testWidgets('shows empty state when no active orders', (tester) async {
      when(() => mock.deliveryActiveOrders).thenReturn([]);
      when(() => mock.refreshCourierOrders()).thenAnswer((_) async {});

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryEmptyCard), findsOneWidget);
      expect(find.text('لا توجد طلبات نشطة حالياً'), findsOneWidget);
    });

    testWidgets('shows active delivery card when order exists',
        (tester) async {
      final order = ActiveOrder(
        id: 'del-order-1',
        orderNumber: '99999',
        dateAr: '2024-06-22',
        dateEn: '2024-06-22',
        statusKey: 'accepted',
        statusAr: 'مقبول',
        statusEn: 'Accepted',
        price: 20000,
        itemsCount: 2,
        itemsNameAr: 'وجبات غداء',
        itemsNameEn: 'Lunch Meals',
        deliveryStatusKey: 'pending',
        deliveryStatusAr: 'بانتظار الاستلام',
        merchantStoreName: 'مطعم الغيث',
        merchantLatitude: 33.3,
        merchantLongitude: 44.4,
      );

      when(() => mock.deliveryActiveOrders).thenReturn([order]);
      when(() => mock.refreshCourierOrders()).thenAnswer((_) async {});

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryActiveGroupCard), findsOneWidget);
      expect(find.text('جاري تجميع الطلبات'), findsOneWidget);
    });

    testWidgets('shows merchant name in delivery card', (tester) async {
      final order = ActiveOrder(
        id: 'del-order-2',
        orderNumber: '88888',
        dateAr: '2024-06-22',
        dateEn: '2024-06-22',
        statusKey: 'accepted',
        statusAr: 'مقبول',
        statusEn: 'Accepted',
        price: 15000,
        itemsCount: 1,
        itemsNameAr: 'بيتزا',
        itemsNameEn: 'Pizza',
        deliveryStatusKey: 'pending',
        deliveryStatusAr: 'بانتظار الاستلام',
        merchantStoreName: 'مطعم البيتزا',
        merchantLatitude: 33.3,
        merchantLongitude: 44.4,
      );

      when(() => mock.deliveryActiveOrders).thenReturn([order]);
      when(() => mock.refreshCourierOrders()).thenAnswer((_) async {});

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('مطعم البيتزا'), findsOneWidget);
    });

    testWidgets('shows action buttons (picked up, completed)',
        (tester) async {
      final order = ActiveOrder(
        id: 'del-order-3',
        orderNumber: '77777',
        dateAr: '2024-06-22',
        dateEn: '2024-06-22',
        statusKey: 'accepted',
        statusAr: 'مقبول',
        statusEn: 'Accepted',
        price: 30000,
        itemsCount: 3,
        itemsNameAr: 'مشويات',
        itemsNameEn: 'Grill',
        deliveryStatusKey: 'pending',
        deliveryStatusAr: 'بانتظار الاستلام',
        merchantStoreName: 'مطعم المشويات',
        merchantLatitude: 33.3,
        merchantLongitude: 44.4,
      );

      when(() => mock.deliveryActiveOrders).thenReturn([order]);
      when(() => mock.refreshCourierOrders()).thenAnswer((_) async {});

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('تم الاستلام'), findsOneWidget);
      expect(find.text('موقع المتجر'), findsOneWidget);
    });
  });
}
