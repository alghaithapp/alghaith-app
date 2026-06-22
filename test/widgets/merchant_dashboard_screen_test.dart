import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:alghaith_app/providers/app_provider.dart';
import 'package:alghaith_app/screens/merchant/merchant_dashboard_screen.dart';
import 'package:alghaith_app/screens/merchant/widgets/shared_dashboard_widgets.dart';
import 'package:alghaith_app/utils/merchant_service_labels.dart';
import 'package:alghaith_app/models/app_notification.dart';
import 'package:alghaith_app/models/app_models.dart';

import '../mocks/app_provider.dart';

Widget _buildTestWidget(AppProvider mock) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppProvider>.value(value: mock),
    ],
    child: MaterialApp(
      home: const MerchantDashboardScreen(),
    ),
  );
}

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
      noteAr: '',
      noteEn: '',
    ));
  });

  setUp(() {
    mock = MockAppProvider();
    when(() => mock.lang).thenReturn('ar');
    when(() => mock.hasSelectedLanguage).thenReturn(true);
    when(() => mock.isLoggingIn).thenReturn(false);
    when(() => mock.setGuestMode()).thenReturn(null);

    // Merchant store details
    when(() => mock.merchantStoreName).thenReturn('متجر الغيث');
    when(() => mock.merchantDescription).thenReturn('أفضل المنتجات');
    when(() => mock.merchantAddress).thenReturn('بغداد');
    when(() => mock.merchantRating).thenReturn(4.5);
    when(() => mock.isMerchantStoreOpen).thenReturn(true);
    when(() => mock.toggleMerchantOpenStatus()).thenAnswer((_) async {});
    when(() => mock.merchantProfileImageBase64).thenReturn(null);
    when(() => mock.merchantCoverImage).thenReturn('');

    // Merchant stats
    when(() => mock.merchantProductCount).thenReturn(15);
    when(() => mock.merchantOrdersCount).thenReturn(8);
    when(() => mock.merchantPendingOrdersCount).thenReturn(3);
    when(() => mock.merchantCompletedOrdersCount).thenReturn(5);

    // Orders
    when(() => mock.merchantIncomingOrders).thenReturn([]);
    when(() => mock.displayOrderNumber(any())).thenReturn('ORD-001');

    // Labels
    when(() => mock.merchantActiveLabels).thenReturn(
      MerchantServiceLabels(
        storeLabelAr: 'متجر',
        storeLabelEn: 'Store',
        accountTitleAr: 'حساب المتجر',
        accountTitleEn: 'Store Account',
        dashboardGreetingAr: 'هذا متجرك على الغيث',
        dashboardGreetingEn: 'Your store on Al-Ghaith',
        dashboardIntroAr: 'أدر المنتجات والطلبات والعروض بطريقة سهلة وسريعة.',
        dashboardIntroEn: 'Manage products, orders and offers with ease.',
        productsTitleAr: 'المنتجات',
        productsTitleEn: 'Products',
        addItemAr: 'إضافة إعلان',
        addItemEn: 'Add Advertisement',
        editItemAr: 'تعديل إعلان',
        editItemEn: 'Edit Product',
        itemSingularAr: 'منتج',
        itemSingularEn: 'Product',
        itemPluralAr: 'منتجات',
        itemPluralEn: 'Products',
        actionLabelAr: 'أضف للسلة',
        actionLabelEn: 'Add to Cart',
        searchPlaceholderAr: 'ابحث عن منتج',
        searchPlaceholderEn: 'Search product',
        storeSettingsTitleAr: 'إعدادات المتجر',
        storeSettingsTitleEn: 'Store Settings',
        storeNameLabelAr: 'اسم المتجر',
        storeNameLabelEn: 'Store name',
        descriptionLabelAr: 'وصف المتجر',
        descriptionLabelEn: 'Store description',
        coverLabelAr: 'صورة المتجر',
        coverLabelEn: 'Store cover',
        logoLabelAr: 'شعار المتجر',
        logoLabelEn: 'Store logo',
        workingHoursLabelAr: 'أوقات العمل',
        workingHoursLabelEn: 'Working hours',
        deliveryAreasLabelAr: 'مناطق التوصيل',
        deliveryAreasLabelEn: 'Delivery areas',
        deliveryFeeLabelAr: 'رسوم التوصيل',
        deliveryFeeLabelEn: 'Delivery fee',
        businessDescriptionAr: 'متجر',
        businessDescriptionEn: 'Store',
      ),
    );

    // Notifications
    when(() => mock.notifications).thenReturn([]);
  });

  group('MerchantDashboardScreen', () {
    testWidgets('shows merchant store name', (tester) async {
      await tester.pumpWidget(_buildTestWidget(mock));
      await tester.pumpAndSettle();

      expect(find.text('متجر الغيث'), findsOneWidget);
    });

    testWidgets('shows merchant open/close status toggle', (tester) async {
      await tester.pumpWidget(_buildTestWidget(mock));
      await tester.pumpAndSettle();

      expect(find.byType(MerchantStoreStatusSwitch), findsOneWidget);
    });

    testWidgets('shows stat cards (sales, orders, products)', (tester) async {
      await tester.pumpWidget(_buildTestWidget(mock));
      await tester.pumpAndSettle();

      expect(find.text('إجمالي منتجات'), findsOneWidget);
      expect(find.text('طلبات جديدة'), findsOneWidget);
      expect(find.text('طلبات مكتملة'), findsOneWidget);
    });

    testWidgets('shows recent orders section', (tester) async {
      await tester.pumpWidget(_buildTestWidget(mock));
      await tester.pumpAndSettle();

      expect(find.text('آخر الطلبات'), findsOneWidget);
    });

    testWidgets('shows logout button at bottom', (tester) async {
      await tester.pumpWidget(_buildTestWidget(mock));
      await tester.pumpAndSettle();

      expect(find.text('عرض الكل'), findsAtLeast(1));
    });
  });
}
