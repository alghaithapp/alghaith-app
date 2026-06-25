/**
 * Taxi Matching Service
 * 
 * يبحث عن سائق بديل بعد رفض السائق الحالي.
 * يوسّع نطاق البحث تدريجياً: 5km → 10km → all
 */

const { getNearbyDrivers } = require('../supabase_repo/taxi');

/**
 * البحث عن أول سائق متاح بعد الرفض
 * 
 * @param {string} requestId - معرف الطلب
 * @param {number} pickupLat - خط عرض موقع الالتقاط
 * @param {number} pickupLng - خط طول موقع الالتقاط
 * @param {string} taxiType - نوع التكسي
 * @param {string[]} rejectedByDrivers - قائمة السائقين الذين رفضوا
 * @returns {Promise<{ driverPhone: string|null, distanceKm: number|null }>}
 */
async function findNextAvailableDriver(requestId, pickupLat, pickupLng, taxiType, rejectedByDrivers = []) {
  const excludeDrivers = rejectedByDrivers.filter(Boolean);

  // توسيع نطاق البحث تدريجياً
  const radiusSteps = [5, 10, 99999]; // 5km → 10km → all

  for (const radiusKm of radiusSteps) {
    const drivers = await getNearbyDrivers(
      pickupLat,
      pickupLng,
      taxiType,
      excludeDrivers,
      radiusKm
    );

    if (Array.isArray(drivers) && drivers.length > 0) {
      const best = drivers[0];
      return {
        driverPhone: best.phone || best.driverPhone,
        distanceKm: best.distanceKm,
      };
    }
  }

  // لا يوجد سائق متاح
  return { driverPhone: null, distanceKm: null };
}

module.exports = { findNextAvailableDriver };
