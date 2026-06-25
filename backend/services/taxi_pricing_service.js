/**
 * Taxi Pricing Service
 *
 * تكتك: حتى 2 كم = 1,000 د.ع، ثم +250 لكل كم إضافي
 * واز: حتى 2 كم = 1,500 د.ع، ثم +300 لكل كم إضافي
 * تكسي اقتصادي: حتى 2 كم = 1,500 د.ع، ثم +500 لكل كم إضافي
 * الحد الأقصى: 50,000 د.ع
 */

const MAX_FARE = 50000;
const INCLUDED_KM = 2.0;
const FARE_ROUNDING_STEP = 250;

/** تقريب لأقرب 250 د.ع (1430→1500، 1700→1700، 1680→1750) */
function roundFareToNearestStep(raw) {
  const safe = Math.max(0, Math.round(Number(raw) || 0));
  if (safe <= 0) return FARE_ROUNDING_STEP;
  return Math.round(safe / FARE_ROUNDING_STEP) * FARE_ROUNDING_STEP;
}

const PRICING = {
  tuktuk: { base: 1000, extraKm: 250, min: 1000 },
  wazz: { base: 1500, extraKm: 300, min: 1500 },
  economic: { base: 1500, extraKm: 500, min: 1500 },
};

function normalizeTaxiType(value) {
  const type = String(value || 'economic').trim().toLowerCase();
  if (type === 'tuktuk' || type === 'tuk_tuk') return 'tuktuk';
  if (type === 'wazz') return 'wazz';
  if (type === 'super') return 'economic';
  if (PRICING[type]) return type;
  return 'economic';
}

function fareForType(distanceKm, taxiType) {
  const type = normalizeTaxiType(taxiType);
  const { base, extraKm, min } = PRICING[type];
  const safeDistance = Number.isFinite(distanceKm) && distanceKm > 0 ? distanceKm : 0;

  const raw = safeDistance <= INCLUDED_KM
    ? base
    : base + Math.round((safeDistance - INCLUDED_KM) * extraKm);

  const bounded = Math.min(Math.max(raw, min), MAX_FARE);
  return roundFareToNearestStep(bounded);
}

/**
 * @param {number} distanceKm
 * @param {string} [taxiType]
 * @returns {{ fareEconomic: number, fareSuper: number, fare: number }}
 */
function calculateFare(distanceKm, taxiType = 'economic') {
  const type = normalizeTaxiType(taxiType);
  const fare = fareForType(distanceKm, type);
  const fareEconomic = fareForType(distanceKm, 'economic');

  return { fareEconomic, fareSuper: fare, fare };
}

module.exports = {
  calculateFare,
  normalizeTaxiType,
  fareForType,
  roundFareToNearestStep,
  FARE_ROUNDING_STEP,
};
