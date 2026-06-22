const { calculateFare } = require('../services/taxi_pricing_service');

describe('Taxi Pricing Service', () => {
  describe('calculateFare', () => {
    it('returns minimum fare for very short distances', () => {
      const result = calculateFare(0.5, 'economic');
      expect(result.fareEconomic).toBeGreaterThanOrEqual(1000);
      expect(result.fare).toBe(1000);
    });

    it('calculates economic fare correctly for 1km', () => {
      const result = calculateFare(1.0, 'economic');
      expect(result.fareEconomic).toBe(1000);
      expect(result.fare).toBe(1000);
    });

    it('calculates economic fare correctly for 5km', () => {
      const result = calculateFare(5.0, 'economic');
      expect(result.fareEconomic).toBe(3000);
      expect(result.fare).toBe(3000);
    });

    it('calculates economic fare correctly for 10km', () => {
      const result = calculateFare(10.0, 'economic');
      expect(result.fareEconomic).toBe(5500);
      expect(result.fare).toBe(5500);
    });

    it('super fare is 30% more than economic', () => {
      const result = calculateFare(10.0, 'super');
      expect(result.fareSuper).toBeGreaterThan(result.fareEconomic);
      expect(result.fare).toBe(result.fareSuper);
    });

    it('super fare for 10km rounds to nearest 250: 5500 * 1.3 = 7150, ceil(28.6)*250 = 7250', () => {
      const result = calculateFare(10.0, 'super');
      expect(result.fareSuper).toBe(7250);
      expect(result.fare).toBe(7250);
    });

    it('rounds up to nearest 250', () => {
      const result = calculateFare(1.1, 'economic');
      expect(result.fareEconomic % 250).toBe(0);
    });

    it('caps at 50000 for economic', () => {
      const result = calculateFare(200, 'economic');
      expect(result.fare).toBe(50000);
    });

    it('caps at 50000 for super', () => {
      const result = calculateFare(200, 'super');
      expect(result.fare).toBe(50000);
    });

    it('super minimum fare is 1500', () => {
      const result = calculateFare(0.1, 'super');
      expect(result.fare).toBe(1500);
    });

    it('returns both fareEconomic and fareSuper fields', () => {
      const result = calculateFare(5.0, 'economic');
      expect(result).toHaveProperty('fareEconomic');
      expect(result).toHaveProperty('fareSuper');
      expect(result).toHaveProperty('fare');
    });
  });
});
