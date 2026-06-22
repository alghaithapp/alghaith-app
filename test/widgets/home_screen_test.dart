import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';

import 'package:alghaith_app/models/app_models.dart';
import 'package:alghaith_app/providers/app_provider.dart';
import 'package:alghaith_app/screens/home_screen.dart';
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
        child: const HomeScreen(),
      ),
    );
  }

  group('HomeScreen', () {
    testWidgets('shows category grid', (tester) async {
      final categories = [
        ServiceCategory(
          id: 'cat-1',
          titleAr: 'تصنيف 1',
          titleEn: 'Category 1',
          image: '',
        ),
        ServiceCategory(
          id: 'cat-2',
          titleAr: 'تصنيف 2',
          titleEn: 'Category 2',
          image: '',
        ),
      ];

      when(() => mock.visibleHomeCategories).thenReturn(categories);
      when(() => mock.selectedCategory).thenReturn('all');
      when(() => mock.isCustomer).thenReturn(false);
      when(() => mock.refreshHomeCategoriesConfig()).thenAnswer((_) async {});
      when(() => mock.setCategory(any())).thenReturn(null);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsNothing);
      expect(find.byType(SliverGrid), findsOneWidget);
    });

    testWidgets('shows service navigation buttons', (tester) async {
      final categories = [
        ServiceCategory(
          id: 'bazar_ghaith',
          titleAr: 'بازار ومطاعم الغيث',
          titleEn: 'Bazar',
          image: '',
        ),
      ];

      when(() => mock.visibleHomeCategories).thenReturn(categories);
      when(() => mock.selectedCategory).thenReturn('all');
      when(() => mock.isCustomer).thenReturn(false);
      when(() => mock.refreshHomeCategoriesConfig()).thenAnswer((_) async {});
      when(() => mock.setCategory(any())).thenReturn(null);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(SliverGrid), findsOneWidget);
    });

    testWidgets('shows loading state initially', (tester) async {
      when(() => mock.visibleHomeCategories).thenReturn([]);
      when(() => mock.selectedCategory).thenReturn('all');
      when(() => mock.isCustomer).thenReturn(false);
      when(() => mock.refreshHomeCategoriesConfig()).thenAnswer((_) async {});
      when(() => mock.setCategory(any())).thenReturn(null);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(SliverGrid), findsOneWidget);
      expect(find.byType(CustomScrollView), findsOneWidget);
    });
  });
}
