import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';

import 'package:alghaith_app/providers/app_provider.dart';
import 'package:alghaith_app/screens/account_screen.dart';
import 'package:alghaith_app/screens/guest_account_view.dart';
import 'package:alghaith_app/screens/customer_account_view.dart';
import 'package:alghaith_app/utils/merchant_service_labels.dart';
import '../mocks/app_provider.dart';

void main() {
  late MockAppProvider mock;

  setUp(() {
    mock = MockAppProvider();
  });

  Widget buildWidget() {
    return MaterialApp(
      home: Material(
        child: ChangeNotifierProvider<AppProvider>.value(
          value: mock,
          child: const AccountScreen(),
        ),
      ),
    );
  }

  group('AccountScreen', () {
    testWidgets('shows login prompt for guest users', (tester) async {
      when(() => mock.isGuestMode).thenReturn(true);
      when(() => mock.unreadNotificationCount).thenReturn(0);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(GuestAccountView), findsOneWidget);
      expect(find.text('سجل دخولك الآن'), findsOneWidget);
    });

    testWidgets('shows account info for logged in customer', (tester) async {
      when(() => mock.isGuestMode).thenReturn(false);
      when(() => mock.isMerchant).thenReturn(false);
      when(() => mock.unreadNotificationCount).thenReturn(0);
      when(() => mock.customerName).thenReturn('مستخدم الغيث');
      when(() => mock.customerPhone).thenReturn('07700000000');
      when(() => mock.authPhone).thenReturn('07700000000');
      when(() => mock.customerAvatarBase64).thenReturn(null);
      when(() => mock.hasAdminAccess).thenReturn(false);
      when(() => mock.resetAll()).thenReturn(null);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(CustomerAccountView), findsOneWidget);
      expect(find.text('تبديل الحساب (الدور)'), findsOneWidget);
    });

    testWidgets('shows role switch button', (tester) async {
      final labels = merchantServiceLabels('product');

      when(() => mock.isGuestMode).thenReturn(false);
      when(() => mock.isMerchant).thenReturn(true);
      when(() => mock.merchantStoreName).thenReturn('متجر الغيث');
      when(() => mock.isMerchantStoreOpen).thenReturn(true);
      when(() => mock.merchantActiveLabels).thenReturn(labels);
      when(() => mock.merchantActiveServiceId).thenReturn('product');
      when(() => mock.merchantProfileImageBase64).thenReturn(null);
      when(() => mock.merchantWorkSampleImagesBase64).thenReturn([]);
      when(() => mock.merchantDescription).thenReturn('');
      when(() => mock.hasAdminAccess).thenReturn(false);
      when(() => mock.totalSales).thenReturn(0);
      when(() => mock.merchantOrdersCount).thenReturn(0);
      when(() => mock.merchantProductCount).thenReturn(0);
      when(() => mock.merchantPhone).thenReturn('');
      when(() => mock.merchantWhatsApp).thenReturn('');
      when(() => mock.merchantAddress).thenReturn('');
      when(() => mock.merchantOpenTime).thenReturn('');
      when(() => mock.merchantCloseTime).thenReturn('');
      when(() => mock.merchantDeliveryFee).thenReturn(0);
      when(() => mock.merchantServiceIds).thenReturn([]);
      when(() => mock.merchantLabels).thenReturn(labels);
      when(() => mock.resetAll()).thenReturn(null);
      when(() => mock.toggleMerchantOpenStatus()).thenAnswer((_) async {});

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('تبديل الحساب (الدور)'), findsOneWidget);
    });
  });
}
