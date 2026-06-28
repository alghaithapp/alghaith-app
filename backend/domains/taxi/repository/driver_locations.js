const { assertSupabaseAdmin, getPhoneVariants, nowIso, resolvePhoneKey } = require('../../../supabase_repo/common');
const { normalizeTaxiType } = require('../../../services/taxi_pricing_service');
const { rememberJson, withRedis } = require('../../../lib/redis_client');

function haversineDistance(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const toRad = (deg) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function normalizeDriverLocation(row) {
  if (!row) return null;
  return {
    phone: String(row.phone || '').trim(),
    currentLat: Number(row.lat ?? 0),
    currentLng: Number(row.lng ?? 0),
    name: String(row.driver_name || '').trim(),
    taxiType: normalizeTaxiType(row.taxi_type),
    vehicleModel: String(row.vehicle_model || '').trim(),
    plateNumber: String(row.plate_number || '').trim(),
    color: String(row.color || '').trim(),
    area: String(row.area || row.city || row.governorate || '').trim(),
    governorate: String(row.governorate || '').trim(),
    city: String(row.city || '').trim(),
    rating: Number(row.rating ?? 0),
    totalTrips: Number(row.total_trips ?? 0),
    isAvailable: row.available !== false,
    isOnline: row.is_online !== false,
    isApproved: row.is_approved === true,
    services: { taxi: true },
    locationUpdatedAt: row.location_updated_at || row.updated_at || null,
  };
}

async function hasDriverLocationsTable() {
  const supabase = assertSupabaseAdmin();
  const { error } = await supabase.from('driver_locations').select('phone').limit(1);
  return !error;
}

async function upsertDriverLocation(driverPhone, data = {}) {
  const phone = await resolvePhoneKey(driverPhone);
  if (!phone) return null;
  if (!(await hasDriverLocationsTable())) return null;

  const lat = Number(data.lat ?? data.latitude ?? 0) || null;
  const lng = Number(data.lng ?? data.longitude ?? 0) || null;
  const now = nowIso();
  const payload = {
    phone,
    is_online: data.isOnline === undefined ? true : data.isOnline === true,
    available: data.available === undefined ? true : data.available === true,
    updated_at: now,
  };

  if (lat && lng) {
    payload.lat = lat;
    payload.lng = lng;
    payload.location_updated_at = now;
    const cacheValue = JSON.stringify({ lat, lng, updatedAt: now });
    await withRedis((client) => client.set(`taxi:driver:${phone}:location`, cacheValue, 'EX', 120));
  }

  if (data.taxiType) payload.taxi_type = normalizeTaxiType(data.taxiType);
  if (data.driverName) payload.driver_name = String(data.driverName).trim();
  if (data.vehicleModel) payload.vehicle_model = String(data.vehicleModel).trim();
  if (data.plateNumber) payload.plate_number = String(data.plateNumber).trim();
  if (data.color) payload.color = String(data.color).trim();
  if (data.governorate) payload.governorate = String(data.governorate).trim();
  if (data.city || data.area) payload.city = String(data.city || data.area).trim();
  if (data.rating !== undefined) payload.rating = Number(data.rating) || 0;
  if (data.totalTrips !== undefined) payload.total_trips = Number(data.totalTrips) || 0;
  if (data.isApproved !== undefined) {
    payload.is_approved = data.isApproved === true;
  } else {
    payload.is_approved = true;
  }

  const supabase = assertSupabaseAdmin();
  const { data: row, error } = await supabase
    .from('driver_locations')
    .upsert(payload, { onConflict: 'phone' })
    .select()
    .maybeSingle();
  if (error) throw new Error(error.message);
  return normalizeDriverLocation(row);
}

async function setDriverOnline(driverPhone, isOnline) {
  const phone = await resolvePhoneKey(driverPhone);
  if (!phone || !(await hasDriverLocationsTable())) return null;

  return upsertDriverLocation(phone, {
    isOnline: Boolean(isOnline),
    available: Boolean(isOnline),
  });
}

async function setDriverOnlineLegacy(driverPhone, isOnline) {
  const phone = await resolvePhoneKey(driverPhone);
  const supabase = assertSupabaseAdmin();
  const payload = {
    phone,
    is_online: Boolean(isOnline),
    available: Boolean(isOnline),
    updated_at: nowIso(),
  };
  if (!isOnline) payload.offline_at = nowIso();

  const { data, error } = await supabase
    .from('driver_locations')
    .upsert(payload, { onConflict: 'phone' })
    .select()
    .maybeSingle();
  if (error) throw new Error(error.message);
  return normalizeDriverLocation(data);
}

async function getFreshDriverLocation(driverPhone, maxAgeMs = 120_000) {
  const phone = await resolvePhoneKey(driverPhone);
  if (!phone) return null;

  const cached = await withRedis(async (client) => client.get(`taxi:driver:${phone}:location`), null);
  if (cached) {
    try {
      const parsed = JSON.parse(cached);
      const age = Date.now() - Date.parse(parsed.updatedAt || '');
      if (Number(parsed.lat) && Number(parsed.lng) && age >= 0 && age <= maxAgeMs) {
        return { lat: Number(parsed.lat), lng: Number(parsed.lng), updatedAt: parsed.updatedAt };
      }
    } catch (_) {}
  }

  if (!(await hasDriverLocationsTable())) return null;
  const variants = getPhoneVariants(phone);
  const supabase = assertSupabaseAdmin();
  const { data, error } = await supabase
    .from('driver_locations')
    .select('lat,lng,location_updated_at,updated_at')
    .in('phone', variants)
    .maybeSingle();
  if (error) throw new Error(error.message);
  const updatedAt = data?.location_updated_at || data?.updated_at;
  const age = updatedAt ? Date.now() - Date.parse(updatedAt) : Number.POSITIVE_INFINITY;
  if (Number(data?.lat) && Number(data?.lng) && age >= 0 && age <= maxAgeMs) {
    return { lat: Number(data.lat), lng: Number(data.lng), updatedAt };
  }
  return null;
}

async function findNearbyDrivers({
  pickupLat,
  pickupLng,
  taxiType = 'economic',
  excludeDriverIds = [],
  radiusKm = 5,
  governorate = '',
  city = '',
  limit = 80,
}) {
  if (!(await hasDriverLocationsTable())) return null;

  const lat = Number(pickupLat);
  const lng = Number(pickupLng);
  if (!lat || !lng) return [];

  const normalizedType = normalizeTaxiType(taxiType);
  const excludeSet = new Set(
    (excludeDriverIds || []).flatMap((id) => getPhoneVariants(id)).filter(Boolean)
  );
  const cacheKey = [
    'taxi:nearby',
    normalizedType,
    Math.round(lat * 100),
    Math.round(lng * 100),
    Math.round(Number(radiusKm) || 5),
    governorate || '-',
    city || '-',
  ].join(':');

  const { value } = await rememberJson(cacheKey, 5, async () => {
    const supabase = assertSupabaseAdmin();
    const radius = Math.max(Number(radiusKm) || 5, 1);
    const latDelta = radius / 111;
    const lngDelta = radius / (111 * Math.max(Math.cos((lat * Math.PI) / 180), 0.2));
    let query = supabase
      .from('driver_locations')
      .select('*')
      .eq('is_online', true)
      .eq('available', true)
      .eq('is_approved', true)
      .eq('taxi_type', normalizedType)
      .gte('lat', lat - latDelta)
      .lte('lat', lat + latDelta)
      .gte('lng', lng - lngDelta)
      .lte('lng', lng + lngDelta)
      .order('location_updated_at', { ascending: false })
      .limit(Math.min(Math.max(Number(limit) || 80, 1), 200));

    if (governorate) query = query.eq('governorate', governorate);
    if (city) query = query.eq('city', city);

    const { data, error } = await query;
    if (error) throw new Error(error.message);
    return (data || []).map(normalizeDriverLocation).filter(Boolean);
  });

  return (value || [])
    .filter((driver) => !excludeSet.has(driver.phone))
    .map((driver) => {
      const distance = haversineDistance(lat, lng, driver.currentLat, driver.currentLng);
      return { ...driver, distanceKm: Math.round(distance * 100) / 100 };
    })
    .filter((driver) => driver.distanceKm <= Number(radiusKm || 5))
    .sort((a, b) => a.distanceKm - b.distanceKm);
}

/**
 * قطع الاتصال تلقائياً عن السائقين الخاملين بعد 24 ساعة من آخر تحديث.
 * يُستدعى من taxi_scheduler.js كل 30 دقيقة.
 */
async function expireStaleOnlineDrivers() {
  const supabase = assertSupabaseAdmin();
  const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { error } = await supabase
    .from('driver_locations')
    .update({ is_online: false, available: false, updated_at: nowIso() })
    .eq('is_online', true)
    .lt('updated_at', cutoff);
  if (error) {
    console.error('expireStaleOnlineDrivers error:', error.message);
  }
}

async function getActiveDriverPhonesByTaxiType(taxiType = 'economic') {
  if (!(await hasDriverLocationsTable())) return null;
  const supabase = assertSupabaseAdmin();
  const { data, error } = await supabase
    .from('driver_locations')
    .select('phone')
    .eq('is_online', true)
    .eq('available', true)
    .eq('is_approved', true)
    .eq('taxi_type', normalizeTaxiType(taxiType))
    .order('updated_at', { ascending: false })
    .limit(500);
  if (error) throw new Error(error.message);
  return (data || []).map((row) => String(row.phone || '').trim()).filter(Boolean);
}

module.exports = {
  upsertDriverLocation,
  setDriverOnline,
  getFreshDriverLocation,
  findNearbyDrivers,
  getActiveDriverPhonesByTaxiType,
  expireStaleOnlineDrivers,
};
