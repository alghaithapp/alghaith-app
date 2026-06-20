/**
 * Taxi Pricing Service
 * 
 * 🟢 اقتصادي: أول 1 كم = 1,000 د.ع، كل كم إضافي = 500 د.ع
 * 🔵 سوبر: اقتصادي + 30%
 * 
 * التقريب: لأقرب 250 د.ع للأعلى
 * الحد الأدنى: اقتصادي 1,000 / سوبر 1,500
 * الحد الأقصى: 50,000 د.ع لأي رحلة
 */

const ROUNDING_STEP = 250;
const MIN_FARE_ECONOMIC = 1000;
const MIN_FARE_SUPER = 1500;
const MAX_FARE = 50000;
const SUPER_MULTIPLIER = 1.30;

/**
 * حساب الأجرة بناءً على المسافة ونوع التكسي
 * 
 * @param {number} distanceKm - المسافة بالكيلومتر
 * @param {string} taxiType - نوع التكسي ('economic' | 'super')
 * @returns {{ fareEconomic: number, fareSuper: number, fare: number }}
 */
function calculateFare(distanceKm, taxiType = 'economic') {
  // 🟢 اقتصادي
  const rawEconomic = distanceKm <= 1.0
    ? 1000
    : 1000 + ((distanceKm - 1.0) * 500);

  // تقريب لأقرب 250 للأعلى
  const fareEconomic = Math.max(
    Math.ceil(rawEconomic / ROUNDING_STEP) * ROUNDING_STEP,
    MIN_FARE_ECONOMIC
  );

  // 🔵 سوبر = اقتصادي + 30%
  const rawSuper = rawEconomic * SUPER_MULTIPLIER;
  const fareSuper = Math.max(
    Math.ceil(rawSuper / ROUNDING_STEP) * ROUNDING_STEP,
    MIN_FARE_SUPER
  );

  // السعر النهائي
  const fare = Math.min(
    taxiType === 'economic' ? fareEconomic : fareSuper,
    MAX_FARE
  );

  return { fareEconomic, fareSuper, fare };
}

module.exports = { calculateFare };
