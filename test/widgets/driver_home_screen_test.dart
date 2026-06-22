import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:alghaith_app/providers/app_provider.dart';
import 'package:alghaith_app/features/taxi/models/taxi_request.dart';
import 'package:alghaith_app/features/taxi/screens/driver/driver_home_screen.dart';
import 'package:alghaith_app/features/taxi/widgets/taxi_map_widget.dart';

import '../mocks/app_provider.dart';

// Platform channel mock for google_maps_flutter
final _mockGoogleMapsChannel = MethodChannel('plugins.flutter.io/google_maps_android');

Widget _buildTestWidget(AppProvider mock) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppProvider>.value(value: mock),
    ],
    child: MaterialApp(
      home: const DriverHomeScreen(),
    ),
  );
}

TaxiRequest _sampleRequest({int fare = 5000, String statusKey = 'pending'}) {
  return TaxiRequest(
    id: 'req-1',
    requestNumber: 'TX-000001',
    customerName: 'أحمد',
    customerPhone: '07701234567',
    pickupAddress: 'شارع الربيع',
    dropoffAddress: 'شارع النخيل',
    pickupLat: 33.3,
    pickupLng: 44.4,
    dropoffLat: 33.4,
    dropoffLng: 44.5,
    distanceKm: 5.0,
    taxiType: TaxiType.economic,
    fareEconomic: fare,
    fareSuper: fare + 2000,
    fare: fare,
    statusKey: statusKey,
    statusAr: 'قيد الانتظار',
  );
}

void main() {
  late MockAppProvider mock;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_mockGoogleMapsChannel, (call) async {
      // Return an empty map for any Google Maps platform call
      return <dynamic, dynamic>{};
    });
  });

  setUp(() {
    mock = MockAppProvider();
    when(() => mock.lang).thenReturn('ar');
    when(() => mock.hasSelectedLanguage).thenReturn(true);
    when(() => mock.isLoggingIn).thenReturn(false);
    when(() => mock.setGuestMode()).thenReturn(null);
    when(() => mock.visibleTaxiIncomingRequests).thenReturn([]);
    when(() => mock.visibleTaxiCompletedRequests).thenReturn([]);
    when(() => mock.driverProfile).thenReturn(const {'name': 'علي'});
    when(() => mock.rejectTaxiRequest(any())).thenAnswer((_) async {});
    when(() => mock.acceptTaxiRequest(any())).thenAnswer((_) async {});
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_mockGoogleMapsChannel, null);
  });

  group('DriverHomeScreen', () {
    testWidgets('shows driver name in app bar', (tester) async {
      await tester.pumpWidget(_buildTestWidget(mock));
      await tester.pumpAndSettle();

      expect(find.text('مرحباً، علي'), findsOneWidget);
    });

    testWidgets('shows stats card (trips + earnings)', (tester) async {
      await tester.pumpWidget(_buildTestWidget(mock));
      await tester.pumpAndSettle();

      expect(find.text('رحلات اليوم'), findsOneWidget);
      expect(find.text('أرباح اليوم'), findsOneWidget);
    });

    testWidgets('shows map widget', (tester) async {
      await tester.pumpWidget(_buildTestWidget(mock));
      await tester.pumpAndSettle();

      expect(find.byType(TaxiMapWidget), findsOneWidget);
    });

    testWidgets(
        'shows incoming request card when pending requests exist',
        (tester) async {
      when(() => mock.visibleTaxiIncomingRequests)
          .thenReturn([_sampleRequest()]);

      await tester.pumpWidget(_buildTestWidget(mock));
      await tester.pumpAndSettle();

      expect(find.text('طلب جديد'), findsOneWidget);
    });

    testWidgets(
        'does NOT show request card when no pending requests',
        (tester) async {
      when(() => mock.visibleTaxiIncomingRequests).thenReturn([]);

      await tester.pumpWidget(_buildTestWidget(mock));
      await tester.pumpAndSettle();

      expect(find.text('طلب جديد'), findsNothing);
    });
  });
}
