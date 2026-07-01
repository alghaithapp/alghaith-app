/**
 * Taxi Pricing Service
 *
 * الأسعار تُقرأ من app_configs (قابلة للتعديل بدون تحديث).
 * القيم الافتراضية:
 *   تكتك: حتى 2 كم = 1,000 د.ع، ثم +250 لكل كم إضافي
 *   واز: حتى 2 كم = 1,500 د.ع، ثم +300 لكل كم إضافي
 *   تكسي اقتصادي: حتى 2 كم = 1,500 د.ع، ثم +500 لكل كم إضافي
 *   الحد الأقصى: 50,000 د.ع
 */

const { getTaxiPricing } = require('./app_config_service');

let _cachedPricing = null;
let _cachePromise = null;

async function _loadPricing() {
  const cp = await getTaxiPricing();
  _cachedPricing = cp;
  return cp;
}

async function _pricing() {
  if (_cachedPricing) return _cachedPricing;
  if (!_cachePromise) _cachePromise = _loadPricing();
  return await _cachePromise;
}

function normalizeTaxiType(value) {
  const type = String(value || 'economic').trim().toLowerCase();
  if (type === 'tuktuk' || type === 'tuk_tuk') return 'tuktuk';
  if (type === 'wazz') return 'wazz';
  if (type === 'super') return 'economic';
  return type in { tuktuk:1, wazz:1, economic:1 } ? type : 'economic';
}

async function fareForType(distanceKm, taxiType) {
  const pricing = await _pricing();
  const type = normalizeTaxiType(taxiType);
  const config = pricing[type] || { base: 1500, extraKm: 500, min: 1500 };
  const { base, extraKm, min } = config;
  const maxFare = Number(pricing.maxFare) || 50000;
  const includedKm = Number(pricing.includedKm) || 2.0;
  const roundingStep = Number(pricing.roundingStep) || 250;

  const safeDistance = Number.isFinite(distanceKm) && distanceKm > 0 ? distanceKm : 0;
  const raw = safeDistance <= includedKm
    ? base
    : base + Math.round((safeDistance - includedKm) * extraKm);
  const bounded = Math.min(Math.max(raw, min), maxFare);
  return roundFareToNearestStep(bounded, roundingStep);
}

function roundFareToNearestStep(raw, step = 250) {
  const safe = Math.max(0, Math.round(Number(raw) || 0));
  if (safe <= 0) return step;
  return Math.round(safe / step) * step;
}

async function calculateFare(distanceKm, taxiType = 'economic', tripType = 'one_way') {
  const type = normalizeTaxiType(taxiType);
  const effectiveDistance = tripType === 'round_trip' ? distanceKm * 2 : distanceKm;
  const fare = await fareForType(effectiveDistance, type);
  const fareEconomic = await fareForType(effectiveDistance, 'economic');
  return { fareEconomic, fareSuper: fare, fare };
}

module.exports = {
  calculateFare,
  normalizeTaxiType,
  fareForType,
  roundFareToNearestStep,
};
