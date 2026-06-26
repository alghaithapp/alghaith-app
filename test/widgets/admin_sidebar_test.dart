import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:alghaith_app/providers/app_provider.dart';
import 'package:alghaith_app/modules/admin/screens/widgets/admin_sidebar.dart';

import '../mocks/app_provider.dart';

Widget _buildTestWidget(
  AppProvider mock, {
  AdminNavItem selected = AdminNavItem.overview,
  required ValueChanged<AdminNavItem> onItemSelected,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppProvider>.value(value: mock),
    ],
    child: MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AdminSidebar(
            selectedItem: selected,
            onItemSelected: onItemSelected,
          ),
        ),
      ),
    ),
  );
}

void main() {
  late MockAppProvider mock;

  setUp(() {
    mock = MockAppProvider();
    when(() => mock.lang).thenReturn('ar');
    when(() => mock.hasSelectedLanguage).thenReturn(true);
    when(() => mock.allMerchants).thenReturn([]);
    when(() => mock.allCouriers).thenReturn([]);
    when(() => mock.allDrivers).thenReturn([]);
    when(() => mock.isLoggingIn).thenReturn(false);
    when(() => mock.setGuestMode()).thenReturn(null);
  });

  group('AdminSidebar', () {
    testWidgets('shows all navigation items', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        mock,
        onItemSelected: (_) {},
      ));
      await tester.pumpAndSettle();

      expect(find.text('نظرة عامة'), findsOneWidget);
      expect(find.text('التجار'), findsOneWidget);
      expect(find.text('المندوبين'), findsOneWidget);
      expect(find.text('السائقين'), findsOneWidget);
      expect(find.text('الحسابات'), findsOneWidget);
      expect(find.text('الأقسام الرئيسية'), findsOneWidget);
      expect(find.text('تحديث التطبيق'), findsOneWidget);
      expect(find.text('التقارير'), findsOneWidget);
      expect(find.text('سجل النشاطات'), findsOneWidget);
      expect(find.text('الإعدادات'), findsOneWidget);
    });

    testWidgets('highlights selected item', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        mock,
        selected: AdminNavItem.merchants,
        onItemSelected: (_) {},
      ));
      await tester.pumpAndSettle();

      final merchantsText = tester.widget<Text>(find.text('التجار'));
      expect(merchantsText.style?.fontWeight, FontWeight.w900);
    });

    testWidgets('shows pending badge count for merchants', (tester) async {
      when(() => mock.allMerchants).thenReturn([
        {'isApproved': false, 'approvalStatus': 'pending'},
        {'isApproved': false, 'approvalStatus': 'pending'},
        {'isApproved': true, 'approvalStatus': 'approved'},
      ]);

      await tester.pumpWidget(_buildTestWidget(
        mock,
        onItemSelected: (_) {},
      ));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('calls onItemSelected callback when tapped', (tester) async {
      AdminNavItem? selectedItem;
      await tester.pumpWidget(_buildTestWidget(
        mock,
        onItemSelected: (item) => selectedItem = item,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('السائقين'));
      await tester.pumpAndSettle();

      expect(selectedItem, AdminNavItem.drivers);
    });
  });
}
