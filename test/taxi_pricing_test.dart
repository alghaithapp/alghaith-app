import 'package:flutter_test/flutter_test.dart';
import 'package:alghaith_app/features/taxi/utils/taxi_fare_calculator.dart';
import 'package:alghaith_app/features/taxi/models/taxi_request.dart';

void main() {
  group('TaxiFareCalculator', () {
    test('tuktuk: up to 2km is 1000', () {
      expect(TaxiFareCalculator.fareForType(1.0, TaxiType.tuktuk), 1000);
      expect(TaxiFareCalculator.fareForType(2.0, TaxiType.tuktuk), 1000);
    });

    test('tuktuk: 3km is 1250', () {
      expect(TaxiFareCalculator.fareForType(3.0, TaxiType.tuktuk), 1250);
    });

    test('wazz: up to 2km is 1500', () {
      expect(TaxiFareCalculator.fareForType(1.0, TaxiType.wazz), 1500);
      expect(TaxiFareCalculator.fareForType(2.0, TaxiType.wazz), 1500);
    });

    test('wazz: 3km is 1800', () {
      expect(TaxiFareCalculator.fareForType(3.0, TaxiType.wazz), 1800);
    });

    test('economic: minimum 1500 even for 1km', () {
      expect(TaxiFareCalculator.fareForType(1.0, TaxiType.economic), 1500);
      expect(TaxiFareCalculator.fareForType(2.0, TaxiType.economic), 1500);
    });

    test('economic: 3km is 2000', () {
      expect(TaxiFareCalculator.fareForType(3.0, TaxiType.economic), 2000);
    });

    test('economic: 5km is 3000', () {
      expect(TaxiFareCalculator.fareForType(5.0, TaxiType.economic), 3000);
    });

    test('caps at 50000 for long distance', () {
      expect(TaxiFareCalculator.fareForType(200.0, TaxiType.economic), 50000);
    });

    test('rounds to nearest 250 IQD', () {
      expect(TaxiFareCalculator.roundFareToNearestStep(1430), 1500);
      expect(TaxiFareCalculator.roundFareToNearestStep(1700), 1700);
      expect(TaxiFareCalculator.roundFareToNearestStep(1370), 1250);
    });

    test('TaxiType API mapping', () {
      expect(TaxiTypeX.fromApiName('tuktuk'), TaxiType.tuktuk);
      expect(TaxiTypeX.fromApiName('wazz'), TaxiType.wazz);
      expect(TaxiTypeX.fromApiName('super'), TaxiType.economic);
      expect(TaxiType.tuktuk.toApiName, 'tuktuk');
    });
  });
}
