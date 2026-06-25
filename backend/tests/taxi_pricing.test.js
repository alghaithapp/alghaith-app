const { calculateFare, fareForType } = require('../services/taxi_pricing_service');

describe('Taxi Pricing Service', () => {
  describe('fareForType', () => {
    it('tuktuk up to 2km is 1000', () => {
      expect(fareForType(1.0, 'tuktuk')).toBe(1000);
      expect(fareForType(2.0, 'tuktuk')).toBe(1000);
    });

    it('tuktuk 3km is 1250', () => {
      expect(fareForType(3.0, 'tuktuk')).toBe(1250);
    });

    it('wazz up to 2km is 1500', () => {
      expect(fareForType(1.5, 'wazz')).toBe(1500);
      expect(fareForType(2.0, 'wazz')).toBe(1500);
    });

    it('wazz 3km is 1800', () => {
      expect(fareForType(3.0, 'wazz')).toBe(1800);
    });

    it('economic minimum 1500 for 1km', () => {
      expect(fareForType(1.0, 'economic')).toBe(1500);
      expect(fareForType(2.0, 'economic')).toBe(1500);
    });

    it('economic 3km is 2000', () => {
      expect(fareForType(3.0, 'economic')).toBe(2000);
    });

    it('economic 5km is 3000', () => {
      expect(fareForType(5.0, 'economic')).toBe(3000);
    });

    it('rounds to nearest 250 IQD', () => {
      const { roundFareToNearestStep } = require('../services/taxi_pricing_service');
      expect(roundFareToNearestStep(1430)).toBe(1500);
      expect(roundFareToNearestStep(1700)).toBe(1700);
      expect(roundFareToNearestStep(1370)).toBe(1250);
    });
      expect(fareForType(1.0, 'super')).toBe(1500);
    });

    it('caps at 50000', () => {
      expect(fareForType(200, 'economic')).toBe(50000);
    });
  });

  describe('calculateFare', () => {
    it('returns fare for selected type', () => {
      const result = calculateFare(3.0, 'tuktuk');
      expect(result.fare).toBe(1250);
      expect(result.fareEconomic).toBe(2000);
    });
  });
});
