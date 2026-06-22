import 'package:flutter_test/flutter_test.dart';
import 'package:alghaith_app/features/taxi/utils/taxi_fare_calculator.dart';
import 'package:alghaith_app/features/taxi/models/taxi_request.dart';

void main() {
  group('TaxiFareCalculator.calculateFare', () {
    test('economic fare for 1km returns minimum 1000', () {
      final result = TaxiFareCalculator.calculateFare(1.0,
          taxiType: TaxiType.economic);
      expect(result.fare, 1000);
      expect(result.fareEconomic, 1000);
    });

    test('economic fare for 0km returns minimum 1000', () {
      final result = TaxiFareCalculator.calculateFare(0.0,
          taxiType: TaxiType.economic);
      expect(result.fare, 1000);
    });

    test('economic fare for negative distance returns minimum 1000', () {
      final result = TaxiFareCalculator.calculateFare(-5.0,
          taxiType: TaxiType.economic);
      expect(result.fare, 1000);
    });

    test('economic fare for 5km returns 3000', () {
      final result = TaxiFareCalculator.calculateFare(5.0,
          taxiType: TaxiType.economic);
      expect(result.fare, 3000);
    });

    test('economic fare for 10km', () {
      final result = TaxiFareCalculator.calculateFare(10.0,
          taxiType: TaxiType.economic);
      expect(result.fare, 5500);
    });

    test('super fare for 1km returns minimum 1500', () {
      final result = TaxiFareCalculator.calculateFare(1.0,
          taxiType: TaxiType.superTaxiType);
      expect(result.fare, 1500);
    });

    test('super fare for 10km is ~30% more than economic', () {
      final economic = TaxiFareCalculator.calculateFare(10.0,
          taxiType: TaxiType.economic);
      final superResult = TaxiFareCalculator.calculateFare(10.0,
          taxiType: TaxiType.superTaxiType);
      expect(superResult.fare, greaterThan(economic.fare));
      expect(superResult.fare, 7250);
      expect(economic.fare, 5500);
    });

    test('super fare for 5km', () {
      final result = TaxiFareCalculator.calculateFare(5.0,
          taxiType: TaxiType.superTaxiType);
      expect(result.fare, 4000);
    });

    test('caps at 50000 for long distance', () {
      final result = TaxiFareCalculator.calculateFare(200.0,
          taxiType: TaxiType.economic);
      expect(result.fare, 50000);
    });

    test('super fare also caps at 50000', () {
      final result = TaxiFareCalculator.calculateFare(200.0,
          taxiType: TaxiType.superTaxiType);
      expect(result.fare, 50000);
    });

    test('defaults to economic when taxiType is null', () {
      final result = TaxiFareCalculator.calculateFare(5.0);
      expect(result.fare, 3000);
      expect(result.fare, result.fareEconomic);
    });

    test('FareResult preserves economic and super fares', () {
      final result = TaxiFareCalculator.calculateFare(10.0,
          taxiType: TaxiType.economic);
      expect(result.fareEconomic, 5500);
      expect(result.fareSuper, 7250);
    });

    test('rounding to nearest 250 works', () {
      final result = TaxiFareCalculator.calculateFare(1.5,
          taxiType: TaxiType.economic);
      expect(result.fare % 250, 0);
    });

    test('fractional distances are handled', () {
      final result = TaxiFareCalculator.calculateFare(2.7,
          taxiType: TaxiType.economic);
      expect(result.fare, greaterThan(1000));
      expect(result.fare % 250, 0);
    });
  });
}
