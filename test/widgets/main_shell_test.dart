import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:alghaith_app/providers/app_provider.dart';
import 'package:alghaith_app/widgets/main_shell.dart';

import '../mocks/app_provider.dart';

Widget _buildTestWidget(AppProvider mock) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppProvider>.value(value: mock),
    ],
    child: MaterialApp(
      home: const MainShell(),
    ),
  );
}

void main() {
  late MockAppProvider mock;

  setUp(() {
    mock = MockAppProvider();

    // Core provider stubs
    when(() => mock.cartCount).thenReturn(0);
    when(() => mock.cartTotal).thenReturn(0);
    when(() => mock.cartPromoDiscountIqd).thenReturn(0);
    when(() => mock.customerActiveOrdersCount).thenReturn(0);
    when(() => mock.orders).thenReturn([]);
    when(() => mock.authPhone).thenReturn(null);
    when(() => mock.inAppAlertsEnabled).thenReturn(false);
    when(() => mock.lang).thenReturn('ar');
    when(() => mock.hasSelectedLanguage).thenReturn(true);
    when(() => mock.isLoggingIn).thenReturn(false);
    when(() => mock.isGuestMode).thenReturn(true);
    when(() => mock.isCustomer).thenReturn(true);
    when(() => mock.items).thenReturn([]);
    when(() => mock.cart).thenReturn([]);
    when(() => mock.addresses).thenReturn([]);
    when(() => mock.notifications).thenReturn([]);
    when(() => mock.visibleHomeCategories).thenReturn([]);
    when(() => mock.hasPhoneSession).thenReturn(false);
    when(() => mock.unreadNotificationCount).thenReturn(0);


    // Methods
    when(() => mock.takePendingMainTab()).thenReturn(null);
    when(() => mock.takePendingOrderId(any())).thenReturn(null);
    when(() => mock.resetHome()).thenReturn(null);
    when(() => mock.refreshCustomerOrders()).thenAnswer((_) async {});
    when(() => mock.tickCustomerNotificationTimers()).thenReturn(null);
    when(() => mock.markNotificationsReadForOrder(
          any(), any(),
        )).thenReturn(null);
    when(() => mock.handleNotificationOpen(any())).thenReturn(null);
    when(() => mock.setGuestMode()).thenReturn(null);
    when(() => mock.refreshHomeCategoriesConfig())
        .thenAnswer((_) async {});
    when(() => mock.refreshCustomerCatalog()).thenAnswer((_) async {});
    when(() => mock.refreshMarketplaceStats()).thenAnswer((_) async {});
  });

  group('MainShell', () {
    testWidgets('shows 5 bottom navigation tabs', (tester) async {
      await tester.pumpWidget(_buildTestWidget(mock));
      await tester.pumpAndSettle();

      expect(find.text('الرئيسية'), findsOneWidget);
      expect(find.text('المفضلة'), findsOneWidget);
      expect(find.text('طلباتي'), findsOneWidget);
      expect(find.text('حسابي'), findsOneWidget);

      // Cart is the special 5th tab – verify by icon
      expect(find.byIcon(CupertinoIcons.shopping_cart), findsAny);
    });

    testWidgets('highlights home tab by default', (tester) async {
      await tester.pumpWidget(_buildTestWidget(mock));
      await tester.pumpAndSettle();

      final homeText = tester.widget<Text>(find.text('الرئيسية'));
      expect(homeText.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('switches content on tab tap', (tester) async {
      await tester.pumpWidget(_buildTestWidget(mock));
      await tester.pumpAndSettle();

      // Home tab is initially bold
      final homeText = tester.widget<Text>(find.text('الرئيسية'));
      expect(homeText.style?.fontWeight, FontWeight.bold);

      // Tap the favourites tab
      await tester.tap(find.text('المفضلة'));
      await tester.pumpAndSettle();

      // Home tab is no longer bold (tab switched)
      final homeTextAfter = tester.widget<Text>(find.text('الرئيسية'));
      expect(homeTextAfter.style?.fontWeight, equals(FontWeight.normal));
    });

    testWidgets('shows cart badge when cart has items', (tester) async {
      when(() => mock.cartCount).thenReturn(3);

      await tester.pumpWidget(_buildTestWidget(mock));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows orders badge when there are active orders',
        (tester) async {
      when(() => mock.customerActiveOrdersCount).thenReturn(2);

      await tester.pumpWidget(_buildTestWidget(mock));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
    });
  });
}
