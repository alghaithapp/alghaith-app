const { v4: uuidv4 } = require('uuid');
const {
  nowIso,
  normalizeObject,
  getPhoneVariants,
  phonesOverlap,
  resolvePhoneKey,
  selectSingle,
  selectMany,
  hasColumn,
  saveRow,
  updateRow,
  assertSupabaseAdmin,
} = require('./common');
const { ensureAppUser, getUserState } = require('./users');
const { calculateFare, normalizeTaxiType } = require('../services/taxi_pricing_service');

// ── دوال مساعدة ──────────────────────────────────────────────────

/**
 * قراءة البيانات من request_payload
 */
function readTaxiMeta(row) {
  const payload = normalizeObject(row.request_payload);
  return {
    row,
    payload,
    id: String(row.id ?? payload.id ?? '').trim(),
    customerPhone: String(row.phone ?? payload.customerPhone ?? '').trim(),
    driverPhone: String(row.driver_phone ?? payload.driverPhone ?? '').trim(),
    statusKey: String(row.status_key ?? payload.statusKey ?? 'pending').trim(),
    taxiType: String(payload.taxiType ?? 'economic').trim(),
    pickupAddress: String(payload.pickupAddress ?? '').trim(),
    dropoffAddress: String(payload.dropoffAddress ?? '').trim(),
    pickupLat: Number(payload.pickupLat ?? 0),
    pickupLng: Number(payload.pickupLng ?? 0),
    dropoffLat: Number(payload.dropoffLat ?? 0),
    dropoffLng: Number(payload.dropoffLng ?? 0),
    distanceKm: Number(payload.distanceKm ?? 0),
    fare: Number(payload.fare ?? 0),
    fareEconomic: Number(payload.fareEconomic ?? 0),
    fareSuper: Number(payload.fareSuper ?? 0),
  };
}

function formatTaxiRequestForClient(row) {
  if (!row) return null;
  const meta = readTaxiMeta(row);
  const payload = meta.payload;
  const vehicleInfo = String(row.vehicle_info ?? payload.driverVehicleInfo ?? '').trim();
  let vehicleModel = String(payload.vehicleModel ?? '').trim();
  let plateNumber = String(payload.plateNumber ?? '').trim();
  if ((!vehicleModel || !plateNumber) && vehicleInfo.includes(' / ')) {
    const parts = vehicleInfo.split(' / ').map((p) => p.trim()).filter(Boolean);
    if (!vehicleModel && parts.length > 0) vehicleModel = parts[0];
    if (!plateNumber && parts.length > 1) plateNumber = parts[parts.length - 1];
  } else if (!vehicleModel && vehicleInfo) {
    vehicleModel = vehicleInfo;
  }

  return {
    ...payload,
    id: meta.id,
    statusKey: meta.statusKey,
    statusAr: payload.statusAr || 'بانتظار سائق',
    customerPhone: meta.customerPhone || payload.customerPhone || '',
    driverPhone: meta.driverPhone || payload.driverPhone || '',
    driverName: String(row.driver_name ?? payload.driverName ?? '').trim(),
    driverVehicleInfo: vehicleInfo || null,
    vehicleModel: vehicleModel || null,
    plateNumber: plateNumber || null,
    taxiType: meta.taxiType || payload.taxiType || 'economic',
    fare: meta.fare || payload.fare || 0,
    fareEconomic: meta.fareEconomic || payload.fareEconomic || 0,
    fareSuper: meta.fareSuper || payload.fareSuper || 0,
    pickupAddress: meta.pickupAddress || payload.pickupAddress || '',
    dropoffAddress: meta.dropoffAddress || payload.dropoffAddress || '',
    pickupLat: meta.pickupLat || payload.pickupLat || 0,
    pickupLng: meta.pickupLng || payload.pickupLng || 0,
    dropoffLat: meta.dropoffLat || payload.dropoffLat || 0,
    dropoffLng: meta.dropoffLng || payload.dropoffLng || 0,
    distanceKm: meta.distanceKm || payload.distanceKm || 0,
    driverLat: Number(payload.driverLat ?? 0) || null,
    driverLng: Number(payload.driverLng ?? 0) || null,
    requestNumber: String(row.request_number ?? payload.requestNumber ?? '').trim(),
    driverRating: Number(row.driver_rating ?? payload.driverRating ?? 0) || 0,
    cashCollected: Boolean(row.cash_collected ?? payload.cashCollected ?? false),
    acceptedAt: row.accepted_at ?? payload.acceptedAt ?? null,
    completedAt: row.completed_at ?? payload.completedAt ?? null,
    cancellationReason: row.cancellation_reason ?? payload.cancellationReason ?? null,
    isPaid: Boolean(row.is_paid ?? payload.isPaid ?? false),
    ratingComment: String(payload.ratingComment ?? '').trim() || null,
    waypoints: Array.isArray(payload.waypoints) ? payload.waypoints : [],
    liveEtaSeconds: Number(payload.liveEtaSeconds ?? 0) || null,
    liveEtaDistanceKm: Number(payload.liveEtaDistanceKm ?? 0) || null,
    adminReviewRequired: Boolean(payload.adminReviewRequired ?? false),
    cancelRequestReason: payload.cancelRequestReason ?? null,
  };
}

/** إخفاء رقم الزبون عن واجهة السائق — التواصل عبر التطبيق فقط */
function hideCustomerPhoneFromTaxiRequest(request) {
  if (!request) return null;
  return {
    ...request,
    customerPhone: '',
    phone: '',
  };
}

function formatTaxiRequestForDriver(row) {
  return hideCustomerPhoneFromTaxiRequest(formatTaxiRequestForClient(row));
}

async function enrichTaxiRequestForClient(row) {
  const base = formatTaxiRequestForClient(row);
  if (!base) return null;

  const payload = readTaxiMeta(row).payload;
  const payloadDriverLat = Number(payload.driverLat ?? 0);
  const payloadDriverLng = Number(payload.driverLng ?? 0);
  const locationUpdatedAt = payload.driverLocationUpdatedAt;
  const locationFresh = locationUpdatedAt
    ? Date.now() - Date.parse(locationUpdatedAt) < 90 * 1000
    : false;

  if (payloadDriverLat && payloadDriverLng && locationFresh) {
    base.driverLat = payloadDriverLat;
    base.driverLng = payloadDriverLng;
  } else {
    const driverPhone = String(base.driverPhone || '').trim();
    if (driverPhone) {
      try {
        const state = await getUserState(driverPhone);
        const profile = state?.driverProfile || {};
        const lat = Number(profile.latitude ?? profile.lat ?? 0);
        const lng = Number(profile.longitude ?? profile.lng ?? 0);
        if (lat && lng) {
          base.driverLat = lat;
          base.driverLng = lng;
        }
        if (!base.plateNumber) {
          base.plateNumber = String(profile.plateNumber ?? profile.plate ?? '').trim() || null;
        }
        if (!base.vehicleModel) {
          base.vehicleModel = String(
            profile.vehicleModel ?? profile.vehicle ?? profile.carModel ?? ''
          ).trim() || null;
        }
      } catch (e) {
        console.error('taxi enrich driver profile error:', e?.message || e);
      }
    }
  }

  const { attachLiveEtaToClientRequest } = require('../services/taxi_trip_service');
  return attachLiveEtaToClientRequest(base);
}

/**
 * توليد رقم طلب TX-XXXXXX
 */
function generateRequestNumber() {
  const chars = '0123456789';
  let result = 'TX-';
  for (let i = 0; i < 6; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

// ── حساب المسافة (Haversine) ─────────────────────────────────────

function haversineDistance(lat1, lng1, lat2, lng2) {
  const R = 6371; // نصف قطر الأرض بالكيلومتر
  const toRad = (deg) => (deg * Math.PI) / 180;

  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// ── إنشاء طلب جديد ───────────────────────────────────────────────

/**
 * @typedef {Object} TaxiRequest
 * @property {string} id
 * @property {string} requestNumber
 * @property {string} customerPhone
 * @property {string} pickupAddress
 * @property {string} dropoffAddress
 * @property {number} pickupLat
 * @property {number} pickupLng
 * @property {number} dropoffLat
 * @property {number} dropoffLng
 * @property {number} distanceKm
 * @property {string} taxiType
 * @property {number} fare
 * @property {number} fareEconomic
 * @property {number} fareSuper
 * @property {string} statusKey
 * @property {string} statusAr
 */

/**
 * @param {string} customerPhone
 * @param {Object} data
 * @param {string} [data.pickupAddress]
 * @param {string} [data.dropoffAddress]
 * @param {number} [data.pickupLat]
 * @param {number} [data.pickupLng]
 * @param {number} [data.dropoffLat]
 * @param {number} [data.dropoffLng]
 * @param {number} [data.distanceKm]
 * @param {string} [data.taxiType]
 * @returns {Promise<TaxiRequest>}
 */
async function createTaxiRequest(customerPhone, data = {}) {
  const normalizedPhone = await resolvePhoneKey(customerPhone);
  await ensureAppUser(normalizedPhone, data);

  const existingActive = await getCustomerActiveRequest(normalizedPhone);
  if (existingActive) {
    throw new Error('لديك طلب تكسي نشط بالفعل. أكمله أو ألغِه أولاً.');
  }

  const requestId = uuidv4();
  const requestNumber = generateRequestNumber();
  const taxiType = normalizeTaxiType(data.taxiType);
  const waypoints = Array.isArray(data.waypoints)
    ? data.waypoints
        .map((wp) => ({
          address: String(wp?.address ?? wp?.addressAr ?? '').trim(),
          lat: Number(wp?.lat ?? wp?.latitude ?? 0),
          lng: Number(wp?.lng ?? wp?.longitude ?? 0),
        }))
        .filter((wp) => wp.address && wp.lat && wp.lng)
        .slice(0, 3)
    : [];

  const { sumWaypointDistanceKm } = require('../services/taxi_trip_service');
  const routeDistanceKm = sumWaypointDistanceKm([
    {
      lat: Number(data.pickupLat) || 0,
      lng: Number(data.pickupLng) || 0,
    },
    ...waypoints.map((wp) => ({ lat: wp.lat, lng: wp.lng })),
    {
      lat: Number(data.dropoffLat) || 0,
      lng: Number(data.dropoffLng) || 0,
    },
  ]);
  const distanceKm = Math.max(
    routeDistanceKm > 0 ? routeDistanceKm : Number(data.distanceKm) || 0,
    0
  );

  // حساب السعر تلقائياً
  const { fareEconomic, fareSuper, fare } = calculateFare(distanceKm, taxiType);

  const requestPayload = {
    id: requestId,
    requestNumber,
    customerPhone: normalizedPhone,
    pickupAddress: String(data.pickupAddress || '').trim(),
    dropoffAddress: String(data.dropoffAddress || '').trim(),
    pickupLat: Number(data.pickupLat) || 0,
    pickupLng: Number(data.pickupLng) || 0,
    dropoffLat: Number(data.dropoffLat) || 0,
    dropoffLng: Number(data.dropoffLng) || 0,
    distanceKm,
    taxiType,
    fareEconomic,
    fareSuper,
    fare,
    statusKey: 'pending',
    statusAr: 'بانتظار سائق',
    rejectedByDriverIds: [],
    waypoints,
    createdAt: nowIso(),
    updatedAt: nowIso(),
  };

  const payload = {
    id: requestId,
    phone: normalizedPhone,
    request_number: requestNumber,
    status_key: 'pending',
    request_payload: requestPayload,
    pickup_lat: requestPayload.pickupLat,
    pickup_lng: requestPayload.pickupLng,
    dropoff_lat: requestPayload.dropoffLat,
    dropoff_lng: requestPayload.dropoffLng,
    distance_km: distanceKm,
    taxi_type: taxiType,
    fare_economic: fareEconomic,
    fare_super: fareSuper,
    fare,
    created_at: nowIso(),
    updated_at: nowIso(),
  };

  const savedRow = await saveRow('taxi_requests', payload, 'id');
  const saved = readTaxiMeta(savedRow);

  // إرسال إشعارات
  try {
    const { notifyNewTaxiRequest } = require('../push/taxi_push_events');
    let nearbyDrivers = await getNearbyDrivers(
      requestPayload.pickupLat,
      requestPayload.pickupLng,
      taxiType,
      [],
      10
    );
    if (!nearbyDrivers.length) {
      nearbyDrivers = await getNearbyDrivers(
        requestPayload.pickupLat,
        requestPayload.pickupLng,
        taxiType,
        [],
        25
      );
    }
    await notifyNewTaxiRequest(
      { ...saved, taxiType },
      nearbyDrivers
    );
  } catch (e) {
    console.error('taxi create push error:', e?.message || e);
  }

  return {
    id: requestId,
    requestId,
    requestNumber,
    statusKey: 'pending',
    statusAr: 'بانتظار سائق',
    pickupAddress: requestPayload.pickupAddress,
    dropoffAddress: requestPayload.dropoffAddress,
    pickupLat: requestPayload.pickupLat,
    pickupLng: requestPayload.pickupLng,
    dropoffLat: requestPayload.dropoffLat,
    dropoffLng: requestPayload.dropoffLng,
    distanceKm,
    taxiType,
    fare,
    fareEconomic,
    fareSuper,
    customerPhone: normalizedPhone,
  };
}

// ── قبول السائق ──────────────────────────────────────────────────

async function acceptTaxiRequest(driverPhone, requestId, data = {}) {
  const normalizedDriver = await resolvePhoneKey(driverPhone);
  const id = String(requestId || '').trim();
  if (!id) throw new Error('Request id is required.');

  const row = await selectSingle('taxi_requests', 'id', id);
  if (!row) throw new Error('Request not found.');

  if (row.status_key !== 'pending') {
    throw new Error('Request is not available for acceptance.');
  }

  const driverActive = await getDriverActiveRequest(normalizedDriver);
  if (driverActive && String(driverActive.id) !== id) {
    throw new Error('لديك رحلة نشطة بالفعل. أكملها قبل قبول طلب جديد.');
  }

  const driverName = String(data.driverName || '').trim() || 'سائق';
  const vehicleModel = String(data.vehicleModel || '').trim();
  const plateNumber = String(data.plateNumber || '').trim();
  const vehicleInfo = [vehicleModel, plateNumber].filter(Boolean).join(' / ');

  const meta = readTaxiMeta(row);
  const acceptedAt = nowIso();

  let driverLatAtAccept = 0;
  let driverLngAtAccept = 0;
  let initialPickupEtaSeconds = 0;
  try {
    const state = await getUserState(normalizedDriver);
    const profile = state?.driverProfile || {};
    driverLatAtAccept = Number(profile.latitude ?? profile.lat ?? 0);
    driverLngAtAccept = Number(profile.longitude ?? profile.lng ?? 0);
    if (driverLatAtAccept && driverLngAtAccept && meta.pickupLat && meta.pickupLng) {
      const { computeLiveEta } = require('../services/taxi_trip_service');
      const live = computeLiveEta(
        driverLatAtAccept,
        driverLngAtAccept,
        meta.pickupLat,
        meta.pickupLng
      );
      initialPickupEtaSeconds = Number(live.etaSeconds ?? 0) || 0;
    }
  } catch (_) {}

  const nextPayload = {
    ...meta.payload,
    statusKey: 'accepted',
    statusAr: 'تم القبول',
    driverId: normalizedDriver,
    driverName,
    driverPhone: normalizedDriver,
    driverVehicleInfo: vehicleInfo || null,
    vehicleModel: vehicleModel || null,
    plateNumber: plateNumber || null,
    driverLat: driverLatAtAccept || meta.payload.driverLat || null,
    driverLng: driverLngAtAccept || meta.payload.driverLng || null,
    driverLocationUpdatedAt: acceptedAt,
    driverLatAtAccept: driverLatAtAccept || null,
    driverLngAtAccept: driverLngAtAccept || null,
    initialPickupEtaSeconds,
    acceptedAt,
    updatedAt: acceptedAt,
  };

  const supabase = assertSupabaseAdmin();
  const { data: updated, error } = await supabase
    .from('taxi_requests')
    .update({
      driver_phone: normalizedDriver,
      driver_name: driverName,
      vehicle_info: vehicleInfo || null,
      status_key: 'accepted',
      request_payload: nextPayload,
      accepted_at: acceptedAt,
      updated_at: acceptedAt,
    })
    .eq('id', id)
    .eq('status_key', 'pending')
    .select()
    .maybeSingle();

  if (error) throw new Error(error.message);
  if (!updated) throw new Error('Request is not available for acceptance.');

  // إشعار للزبون
  try {
    const { notifyDriverAccepted } = require('../push/taxi_push_events');
    await notifyDriverAccepted(meta.customerPhone, driverName, vehicleInfo);
  } catch (e) {
    console.error('taxi accept push error:', e?.message || e);
  }

  return formatTaxiRequestForClient(updated);
}

// ── رفض السائق ───────────────────────────────────────────────────

async function rejectTaxiRequest(driverPhone, requestId) {
  const normalizedDriver = await resolvePhoneKey(driverPhone);
  const id = String(requestId || '').trim();
  if (!id) throw new Error('Request id is required.');

  const row = await selectSingle('taxi_requests', 'id', id);
  if (!row) throw new Error('Request not found.');

  if (row.status_key !== 'pending') {
    throw new Error('Request is not available for rejection.');
  }

  const meta = readTaxiMeta(row);
  const rejectedIds = Array.isArray(meta.payload.rejectedByDriverIds)
    ? meta.payload.rejectedByDriverIds
    : [];
  const variants = getPhoneVariants(normalizedDriver);
  const alreadyRejected = variants.some((v) => rejectedIds.includes(v));
  if (!alreadyRejected) {
    rejectedIds.push(normalizedDriver);
  }

  const nextPayload = {
    ...meta.payload,
    rejectedByDriverIds: rejectedIds,
    updatedAt: nowIso(),
  };

  await updateRow('taxi_requests', 'id', id, {
    request_payload: nextPayload,
    updated_at: nowIso(),
  });

  // البحث عن سائق بديل تلقائياً
  try {
    const { findNextAvailableDriver } = require('../services/taxi_matching_service');
    const nextDriver = await findNextAvailableDriver(
      id,
      meta.pickupLat,
      meta.pickupLng,
      meta.taxiType,
      rejectedIds
    );

    if (nextDriver?.driverPhone) {
      const refreshed = await selectSingle('taxi_requests', 'id', id);
      const formatted = formatTaxiRequestForClient(refreshed);
      const { notifyNewTaxiRequest } = require('../push/taxi_push_events');
      await notifyNewTaxiRequest(
        { ...formatted, taxiType: meta.taxiType },
        [{ phone: nextDriver.driverPhone, distanceKm: nextDriver.distanceKm }]
      );
    }
  } catch (e) {
    console.error('taxi auto-match error:', e?.message || e);
  }

  return formatTaxiRequestForClient(await selectSingle('taxi_requests', 'id', id));
}

// ── تحديث حالة الرحلة ────────────────────────────────────────────

async function updateTaxiRequestStatus(actorPhone, requestId, statusKey) {
  const normalizedPhone = await resolvePhoneKey(actorPhone);
  const id = String(requestId || '').trim();
  if (!id) throw new Error('Request id is required.');
  if (!statusKey) throw new Error('Status key is required.');

  const row = await selectSingle('taxi_requests', 'id', id);
  if (!row) throw new Error('Request not found.');

  const meta = readTaxiMeta(row);

  // تحقق من الصلاحية
  const isCustomer = phonesOverlap(normalizedPhone, meta.customerPhone);
  const isDriver = phonesOverlap(normalizedPhone, meta.driverPhone);
  if (!isCustomer && !isDriver) {
    throw new Error('You are not authorized to update this request.');
  }

  // التحقق من التسلسل الصحيح للحالات
  const allowedStatuses = [
    'arrived', 'picked_up', 'completed', 'cancelled', 'accepted', 'cancel_requested',
  ];
  if (!allowedStatuses.includes(statusKey)) {
    throw new Error(`Invalid status key: ${statusKey}.`);
  }

  const currentStatus = meta.statusKey;
  const validTransitions = {
    accepted: ['on_way', 'arrived', 'cancelled', 'cancel_requested'],
    arrived: ['picked_up', 'cancelled', 'cancel_requested'],
    picked_up: ['completed'],
    pending: ['cancelled'],
    cancel_requested: ['cancelled', 'accepted'],
    on_way: ['arrived', 'cancelled', 'cancel_requested'],
  };
  const allowedNext = validTransitions[currentStatus] || [];

  if (!allowedNext.includes(statusKey)) {
    throw new Error(`Cannot transition from ${currentStatus} to ${statusKey}.`);
  }

  const nextPayload = {
    ...meta.payload,
    statusKey,
    updatedAt: nowIso(),
  };

  const dbUpdate = {
    status_key: statusKey,
    request_payload: nextPayload,
    updated_at: nowIso(),
  };

  if (statusKey === 'completed') {
    const completedAt = nowIso();
    nextPayload.completedAt = completedAt;
    nextPayload.cashCollected = true;
    dbUpdate.completed_at = completedAt;
    dbUpdate.cash_collected = true;
  }

  if (statusKey === 'arrived') {
    nextPayload.arrivedAt = nowIso();
  }

  if (statusKey === 'picked_up') {
    nextPayload.pickedUpAt = nowIso();
  }

  if (statusKey === 'cancelled') {
    nextPayload.cancellationReason = row.status_key === 'pending'
      ? 'ألغى الزبون الطلب'
      : nextPayload.cancellationReason || 'ملغي';
    dbUpdate.cancellation_reason = nextPayload.cancellationReason;
  }

  if (statusKey === 'cancel_requested') {
    nextPayload.statusAr = 'بانتظار موافقة السائق على الإلغاء';
    nextPayload.cancelRequestedAt = nowIso();
  }

  dbUpdate.request_payload = nextPayload;

  await updateRow('taxi_requests', 'id', id, dbUpdate);

  // إشعارات
  try {
    const push = require('../push/taxi_push_events');
    if (statusKey === 'arrived') {
      await push.notifyDriverArrived(meta.customerPhone);
    } else if (statusKey === 'completed') {
      await push.notifyTripCompleted(meta.customerPhone, meta.driverPhone, meta.fare);
    } else if (statusKey === 'cancel_requested' && isCustomer) {
      await push.notifyCancelRequested(meta.driverPhone, meta.customerPhone);
    } else if (statusKey === 'cancelled') {
      if (row.status_key === 'cancel_requested') {
        await push.notifyCancellationApproved(meta.customerPhone);
      } else {
        await push.notifyTripCancelled(meta.customerPhone, meta.driverPhone);
      }
    } else if (statusKey === 'accepted' && row.status_key === 'cancel_requested') {
      await push.notifyCancellationRejected(meta.customerPhone);
    }
  } catch (e) {
    console.error('taxi status push error:', e?.message || e);
  }

  return formatTaxiRequestForClient(await selectSingle('taxi_requests', 'id', id));
}

// ── إلغاء من الزبون ──────────────────────────────────────────────

async function cancelTaxiRequest(customerPhone, requestId, reason) {
  const normalizedPhone = await resolvePhoneKey(customerPhone);
  const id = String(requestId || '').trim();
  if (!id) throw new Error('Request id is required.');

  const row = await selectSingle('taxi_requests', 'id', id);
  if (!row) throw new Error('Request not found.');

  const meta = readTaxiMeta(row);
  if (!phonesOverlap(normalizedPhone, meta.customerPhone)) {
    throw new Error('You are not authorized to cancel this request.');
  }

  const currentStatus = meta.statusKey;

  if (currentStatus === 'completed' || currentStatus === 'cancelled') {
    throw new Error('لا يمكن إلغاء هذا الطلب.');
  }
  if (currentStatus === 'picked_up') {
    throw new Error('لا يمكن الإلغاء بعد بدء الرحلة.');
  }

  if (currentStatus !== 'pending') {
    throw new Error('استخدم طلب الإلغاء للرحلات المقبولة من شاشة التتبع.');
  }

  const cancellableStatuses = ['pending'];

  const cancelledAt = nowIso();
  const nextPayload = {
    ...meta.payload,
    statusKey: 'cancelled',
    statusAr: 'ملغي',
    cancellationReason: 'ألغى الزبون الطلب',
    cancelledAt,
    updatedAt: cancelledAt,
  };

  const supabase = assertSupabaseAdmin();
  const { data: updated, error } = await supabase
    .from('taxi_requests')
    .update({
      status_key: 'cancelled',
      request_payload: nextPayload,
      cancellation_reason: null,
      updated_at: cancelledAt,
    })
    .eq('id', id)
    .in('status_key', cancellableStatuses)
    .select()
    .maybeSingle();

  if (error) throw new Error(error.message);
  if (!updated) throw new Error('لا يمكن إلغاء هذا الطلب حالياً.');

  try {
    const { notifyTripCancelled } = require('../push/taxi_push_events');
    await notifyTripCancelled(meta.customerPhone, null);
  } catch (_) {}

  return formatTaxiRequestForClient(updated);
}

async function requestTripCancellation(customerPhone, requestId, reason) {
  const normalizedPhone = await resolvePhoneKey(customerPhone);
  const id = String(requestId || '').trim();
  if (!id) throw new Error('Request id is required.');

  const row = await selectSingle('taxi_requests', 'id', id);
  if (!row) throw new Error('Request not found.');

  const meta = readTaxiMeta(row);
  if (!phonesOverlap(normalizedPhone, meta.customerPhone)) {
    throw new Error('You are not authorized to cancel this request.');
  }

  const cancellable = ['accepted', 'on_way', 'arrived'];
  if (!cancellable.includes(meta.statusKey)) {
    throw new Error('لا يمكن طلب الإلغاء في هذه المرحلة.');
  }

  const trimmedReason = String(reason || '').trim().slice(0, 300);
  const nextPayload = {
    ...meta.payload,
    statusKey: 'cancel_requested',
    statusAr: 'بانتظار موافقة السائق على الإلغاء',
    cancelRequestReason: trimmedReason || 'طلب إلغاء من الزبون',
    cancelRequestedAt: nowIso(),
    updatedAt: nowIso(),
  };

  await updateRow('taxi_requests', 'id', id, {
    status_key: 'cancel_requested',
    request_payload: nextPayload,
    updated_at: nowIso(),
  });

  try {
    const { notifyCancelRequested } = require('../push/taxi_push_events');
    await notifyCancelRequested(meta.driverPhone, meta.customerPhone);
  } catch (e) {
    console.error('taxi cancel request push error:', e?.message || e);
  }

  return formatTaxiRequestForClient(await selectSingle('taxi_requests', 'id', id));
}

async function updateDriverTripLocation(driverPhone, requestId, lat, lng) {
  const normalizedDriver = await resolvePhoneKey(driverPhone);
  const id = String(requestId || '').trim();
  const driverLat = Number(lat);
  const driverLng = Number(lng);
  if (!id) throw new Error('Request id is required.');
  if (!driverLat || !driverLng) throw new Error('Valid coordinates are required.');

  const row = await selectSingle('taxi_requests', 'id', id);
  if (!row) throw new Error('Request not found.');

  const meta = readTaxiMeta(row);
  if (!phonesOverlap(normalizedDriver, meta.driverPhone)) {
    throw new Error('You are not authorized to update this trip location.');
  }

  const activeStatuses = ['accepted', 'on_way', 'arrived', 'picked_up'];
  if (!activeStatuses.includes(meta.statusKey)) {
    throw new Error('Trip is not active.');
  }

  const updatedAt = nowIso();
  let nextPayload = {
    ...meta.payload,
    driverLat,
    driverLng,
    driverLocationUpdatedAt: updatedAt,
    updatedAt,
  };

  const { maybeNotifyProximityAndDelay, attachLiveEtaToClientRequest } = require('../services/taxi_trip_service');
  nextPayload = await maybeNotifyProximityAndDelay(row, meta, nextPayload);

  const liveBase = attachLiveEtaToClientRequest({
    ...formatTaxiRequestForClient(row),
    driverLat,
    driverLng,
    statusKey: meta.statusKey,
    pickupLat: meta.pickupLat,
    pickupLng: meta.pickupLng,
    dropoffLat: meta.dropoffLat,
    dropoffLng: meta.dropoffLng,
  });
  nextPayload.liveEtaSeconds = liveBase.liveEtaSeconds;
  nextPayload.liveEtaDistanceKm = liveBase.liveEtaDistanceKm;

  await updateRow('taxi_requests', 'id', id, {
    request_payload: nextPayload,
    updated_at: updatedAt,
  });

  try {
    const state = await getUserState(normalizedDriver);
    const profile = { ...(state?.driverProfile || {}) };
    profile.latitude = driverLat;
    profile.longitude = driverLng;
    profile.lat = driverLat;
    profile.lng = driverLng;
    profile.updatedAt = updatedAt;
    const { saveUserState } = require('./users');
    await saveUserState(normalizedDriver, { ...state, driverProfile: profile });
  } catch (_) {}

  return formatTaxiRequestForClient(await selectSingle('taxi_requests', 'id', id));
}

async function expireStalePendingTaxiRequests() {
  const { PENDING_AUTO_CANCEL_MS } = require('../services/taxi_trip_service');
  const cutoff = new Date(Date.now() - PENDING_AUTO_CANCEL_MS).toISOString();
  const rows = await selectMany(
    'taxi_requests',
    [
      { method: 'eq', column: 'status_key', value: 'pending' },
      { method: 'lt', column: 'created_at', value: cutoff },
    ],
    { column: 'created_at', ascending: true },
    50
  );

  let count = 0;
  for (const row of rows || []) {
    const meta = readTaxiMeta(row);
    const cancelledAt = nowIso();
    const nextPayload = {
      ...meta.payload,
      statusKey: 'cancelled',
      statusAr: 'ملغي تلقائياً',
      cancellationReason: 'لم يقبل أي سائق خلال المهلة المحددة',
      cancelledAt,
      autoCancelled: true,
      updatedAt: cancelledAt,
    };
    await updateRow('taxi_requests', 'id', meta.id, {
      status_key: 'cancelled',
      request_payload: nextPayload,
      cancellation_reason: nextPayload.cancellationReason,
      updated_at: cancelledAt,
    });
    try {
      const { notifyTripCancelled } = require('../push/taxi_push_events');
      await notifyTripCancelled(meta.customerPhone, null);
    } catch (_) {}
    count += 1;
  }
  return count;
}

async function getAdminTaxiTrips(adminPhone, { status, limit = 100 } = {}) {
  await ensureAppUser(adminPhone, {});
  const { ensurePlatformAdminAccess } = require('./admin');
  await ensurePlatformAdminAccess(adminPhone);

  const filters = [];
  const normalizedStatus = String(status || '').trim();
  if (normalizedStatus) {
    filters.push({ method: 'eq', column: 'status_key', value: normalizedStatus });
  }

  const rows = await selectMany(
    'taxi_requests',
    filters,
    { column: 'created_at', ascending: false },
    Math.min(Math.max(Number(limit) || 100, 1), 300)
  );
  return (rows || []).map((row) => formatTaxiRequestForClient(row));
}

async function getAdminTaxiComplaints(adminPhone, { limit = 100 } = {}) {
  await ensureAppUser(adminPhone, {});
  const { ensurePlatformAdminAccess } = require('./admin');
  await ensurePlatformAdminAccess(adminPhone);

  const rows = await selectMany(
    'taxi_requests',
    [{ method: 'eq', column: 'status_key', value: 'completed' }],
    { column: 'completed_at', ascending: false },
    Math.min(Math.max(Number(limit) || 100, 1), 300)
  );

  return (rows || [])
    .map((row) => formatTaxiRequestForClient(row))
    .filter((item) => {
      const rating = Number(item.driverRating ?? 0);
      return item.adminReviewRequired === true || (rating > 0 && rating <= 2);
    });
}

// ── البحث عن سائقين قريبين ────────────────────────────────────────

async function getNearbyDrivers(pickupLat, pickupLng, taxiType = 'economic', excludeDriverIds = [], radiusKm = 5) {
  const supabase = assertSupabaseAdmin();
  const requestedType = normalizeTaxiType(taxiType);

  // الحصول على جميع مستخدمين دور driver
  const { data: appUsers, error } = await supabase
    .from('app_users')
    .select('phone, role, account_type');
  if (error) throw new Error(error.message);

  const candidates = [];
  const excludeSet = new Set(
    (excludeDriverIds || []).map((id) => String(id || '').trim()).filter(Boolean)
  );

  for (const user of (appUsers || [])) {
    const phone = String(user.phone || '').trim();
    if (!phone || excludeSet.has(phone)) continue;

    // قراءة driver profile من getUserState — لا نعتمد على role في app_users
    const state = await getUserState(phone);
    const profile = state?.driverProfile;
    if (!profile || typeof profile !== 'object') continue;
    if (Object.keys(profile).length === 0) continue;
    if (profile.isApproved !== true) continue;
    if (profile.available === false) continue;

    // تحقق من service type
    const services = profile.services || {};
    if (services.taxi === false) continue;

    const driverType = normalizeTaxiType(profile.taxiType);
    if (driverType !== requestedType) continue;

    // حساب المسافة باستخدام Haversine
    const driverLat = Number(profile.latitude ?? profile.lat ?? 0);
    const driverLng = Number(profile.longitude ?? profile.lng ?? 0);
    if (!driverLat || !driverLng) continue;

    const distance = haversineDistance(pickupLat, pickupLng, driverLat, driverLng);
    if (distance > radiusKm) continue;

    candidates.push({
      phone: phone,
      currentLat: driverLat,
      currentLng: driverLng,
      name: profile.name || '',
      taxiType: driverType,
      vehicleModel: profile.vehicleModel || '',
      plateNumber: profile.plateNumber || '',
      color: profile.color || '',
      area: profile.area || '',
      rating: profile.rating || 0,
      totalTrips: 0,
      isAvailable: profile.available !== false,
      isOnline: profile.available !== false,
      isApproved: profile.isApproved === true,
      services: profile.services || {},
      distanceKm: Math.round(distance * 100) / 100,
    });
  }

  // ترتيب حسب المسافة (الأقرب أولاً)
  candidates.sort((a, b) => a.distanceKm - b.distanceKm);

  return candidates;
}

// ── جلب الطلبات الواردة للسائق ──────────────────────────────────

async function getDriverIncomingRequests(driverPhone, lat, lng, taxiType, radiusKm = 15) {
  const normalizedDriver = await resolvePhoneKey(driverPhone);
  const hasLocation = Number(lat) && Number(lng);
  if (!hasLocation) return [];

  const driverType = normalizeTaxiType(taxiType);

  const rows = await selectMany(
    'taxi_requests',
    [{ method: 'eq', column: 'status_key', value: 'pending' }],
    { column: 'created_at', ascending: false }
  );

  if (!Array.isArray(rows) || rows.length === 0) return [];

  const normalizeType = (value) => normalizeTaxiType(value);

  const matchesType = (row, meta) => {
    const requestType = normalizeType(
      row.taxi_type || meta.taxiType || meta.payload?.taxiType
    );
    return requestType === normalizeType(driverType);
  };

  const buildCandidate = (row, meta, roundedDistance) => ({
    ...meta.payload,
    id: meta.id,
    statusKey: meta.statusKey,
    statusAr: meta.payload.statusAr || 'بانتظار سائق',
    distanceKm: roundedDistance,
    customerPhone: '',
    phone: '',
  });

  const withinRadius = [];

  for (const row of rows) {
    const meta = readTaxiMeta(row);
    if (!matchesType(row, meta)) continue;

    const rejectedIds = Array.isArray(meta.payload.rejectedByDriverIds)
      ? meta.payload.rejectedByDriverIds
      : [];
    if (rejectedIds.length > 0) {
      const variants = getPhoneVariants(normalizedDriver);
      const alreadyRejected = variants.some((v) => rejectedIds.includes(v));
      if (alreadyRejected) continue;
    }

    let roundedDistance = 0;
    if (meta.pickupLat && meta.pickupLng) {
      const distance = haversineDistance(lat, lng, meta.pickupLat, meta.pickupLng);
      roundedDistance = Math.round(distance * 100) / 100;
      if (distance > radiusKm) continue;
    } else {
      continue;
    }

    withinRadius.push(buildCandidate(row, meta, roundedDistance));
  }

  withinRadius.sort((a, b) => a.distanceKm - b.distanceKm);
  return withinRadius;
}

// ── الحصول على السائقين النشيطين حسب النوع ───────────────────────

async function getActiveDriverPhonesByTaxiType(taxiType = 'economic') {
  const supabase = assertSupabaseAdmin();
  const requestedType = normalizeTaxiType(taxiType);

  const { data: appUsers, error } = await supabase
    .from('app_users')
    .select('phone, role, account_type');
  if (error) throw new Error(error.message);

  const result = [];

  for (const user of (appUsers || [])) {
    const phone = String(user.phone || '').trim();
    if (!phone) continue;

    const role = String(user.role || '').trim();
    const accountType = String(user.account_type || '').trim();
    const isDriverAccount = role === 'driver' || accountType === 'driver';
    if (!isDriverAccount) continue;

    const state = await getUserState(phone);
    const profile = state?.driverProfile;
    if (!profile || typeof profile !== 'object') continue;
    if (profile.isApproved !== true) continue;
    if (profile.available === false) continue;

    const services = profile.services || {};
    if (services.taxi === false) continue;

    const driverType = normalizeTaxiType(profile.taxiType);
    if (driverType !== requestedType) continue;

    result.push(phone);
  }

  return result;
}

// ── استعلامات ─────────────────────────────────────────────────────

async function getCustomerActiveRequest(customerPhone) {
  const normalizedPhone = await resolvePhoneKey(customerPhone);
  const variants = getPhoneVariants(normalizedPhone);
  if (variants.length === 0) return null;

  const activeStatuses = ['pending', 'accepted', 'arrived', 'picked_up', 'cancel_requested', 'on_way'];
  const rows = await selectMany(
    'taxi_requests',
    [
      { method: 'in', column: 'phone', value: variants },
      { method: 'in', column: 'status_key', value: activeStatuses },
    ],
    { column: 'created_at', ascending: false }
  );

  return Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
}

async function getDriverActiveRequest(driverPhone) {
  const normalizedDriver = await resolvePhoneKey(driverPhone);
  const variants = getPhoneVariants(normalizedDriver);
  if (variants.length === 0) return null;

  const activeStatuses = ['accepted', 'arrived', 'picked_up', 'cancel_requested', 'on_way'];
  const rows = await selectMany(
    'taxi_requests',
    [
      { method: 'in', column: 'driver_phone', value: variants },
      { method: 'in', column: 'status_key', value: activeStatuses },
    ],
    { column: 'created_at', ascending: false }
  );

  return Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
}

async function updateDriverRatingStats(driverPhone, newRating) {
  const phoneKey = await resolvePhoneKey(driverPhone);
  if (!phoneKey) return;

  const { saveUserState } = require('./users');
  const state = (await getUserState(phoneKey)) || {};
  const profile = { ...(state.driverProfile || {}) };
  const prevRating = Number(profile.rating ?? 0);
  const prevCount = Number(profile.ratingCount ?? 0);
  const count = prevCount + 1;
  const avg = prevCount > 0
    ? Math.round(((prevRating * prevCount) + newRating) / count * 10) / 10
    : newRating;

  profile.rating = avg;
  profile.ratingCount = count;
  await saveUserState(phoneKey, { ...state, driverProfile: profile });
}

async function rateTaxiRequest(customerPhone, requestId, rating, comment) {
  const normalizedPhone = await resolvePhoneKey(customerPhone);
  const id = String(requestId || '').trim();
  const stars = Number(rating);
  if (!id) throw new Error('Request id is required.');
  if (!Number.isFinite(stars) || stars < 1 || stars > 5) {
    throw new Error('Rating must be between 1 and 5.');
  }

  const row = await selectSingle('taxi_requests', 'id', id);
  if (!row) throw new Error('Request not found.');

  const meta = readTaxiMeta(row);
  if (!phonesOverlap(normalizedPhone, meta.customerPhone)) {
    throw new Error('You are not authorized to rate this request.');
  }
  if (meta.statusKey !== 'completed') {
    throw new Error('Only completed trips can be rated.');
  }

  const existingRating = Number(row.driver_rating ?? meta.payload.driverRating ?? 0);
  if (existingRating > 0) {
    throw new Error('This trip has already been rated.');
  }

  const trimmedComment = String(comment || '').trim().slice(0, 500);
  const adminReviewRequired = stars <= 2 || trimmedComment.length > 0;
  const nextPayload = {
    ...meta.payload,
    driverRating: stars,
    ratingComment: trimmedComment || undefined,
    adminReviewRequired,
    ratedAt: nowIso(),
    updatedAt: nowIso(),
  };

  const dbUpdate = {
    driver_rating: stars,
    request_payload: nextPayload,
    updated_at: nowIso(),
  };

  const updated = await updateRow('taxi_requests', 'id', id, dbUpdate);
  if (meta.driverPhone) {
    try {
      await updateDriverRatingStats(meta.driverPhone, stars);
    } catch (e) {
      console.error('taxi driver rating stats error:', e?.message || e);
    }
  }

  return formatTaxiRequestForClient(updated);
}

async function getCustomerPendingRatingRequest(customerPhone) {
  const normalizedPhone = await resolvePhoneKey(customerPhone);
  const variants = getPhoneVariants(normalizedPhone);
  if (variants.length === 0) return null;

  const rows = await selectMany(
    'taxi_requests',
    [
      { method: 'in', column: 'phone', value: variants },
      { method: 'eq', column: 'status_key', value: 'completed' },
    ],
    { column: 'completed_at', ascending: false },
    10
  );

  const cutoffMs = Date.now() - 7 * 24 * 60 * 60 * 1000;
  for (const row of rows) {
    const payload = normalizeObject(row.request_payload);
    const existingRating = Number(row.driver_rating ?? payload.driverRating ?? 0);
    if (existingRating > 0) continue;

    const completedAt = row.completed_at ?? payload.completedAt;
    if (completedAt) {
      const ts = Date.parse(completedAt);
      if (!Number.isNaN(ts) && ts < cutoffMs) continue;
    }

    return row;
  }

  return null;
}

async function getCustomerHistory(customerPhone) {
  const normalizedPhone = await resolvePhoneKey(customerPhone);
  const variants = getPhoneVariants(normalizedPhone);
  if (variants.length === 0) return [];

  return selectMany(
    'taxi_requests',
    [
      { method: 'in', column: 'phone', value: variants },
      { method: 'in', column: 'status_key', value: ['completed', 'cancelled'] },
    ],
    { column: 'created_at', ascending: false }
  );
}

async function getDriverHistory(driverPhone) {
  const normalizedDriver = await resolvePhoneKey(driverPhone);
  const variants = getPhoneVariants(normalizedDriver);
  if (variants.length === 0) return [];

  return selectMany(
    'taxi_requests',
    [
      { method: 'in', column: 'driver_phone', value: variants },
      { method: 'in', column: 'status_key', value: ['completed', 'cancelled'] },
    ],
    { column: 'created_at', ascending: false }
  );
}

// ── حالة السائق (متصل/غير متصل) ─────────────────────────────────────

async function setDriverOnlineStatus(driverPhone, isOnline) {
  const phoneKey = await resolvePhoneKey(driverPhone);
  const supabase = assertSupabaseAdmin();

  // Try atomic RPC first
  try {
    const { data, error } = await supabase.rpc('atomic_set_driver_online', {
      p_phone: phoneKey,
      p_is_online: Boolean(isOnline),
    });
    if (!error) {
      return { success: true, phone: phoneKey, isOnline: Boolean(isOnline) };
    }
  } catch (_) {
    // fallback
  }

  const { getUserState, saveUserState } = require('./users');
  const state = (await getUserState(phoneKey)) || {};
  const profile = state.driverProfile || {};

  profile.available = Boolean(isOnline);
  profile.updatedAt = nowIso();

  await saveUserState(phoneKey, {
    ...state,
    driverProfile: profile,
  });

  if (await hasColumn('taxi_driver_status')) {
    const variants = getPhoneVariants(phoneKey);
    await supabase
      .from('taxi_driver_status')
      .upsert(
        {
          phone: phoneKey,
          is_online: Boolean(isOnline),
          updated_at: nowIso(),
        },
        { onConflict: 'phone' }
      );
  }

  return { success: true, phone: phoneKey, isOnline: Boolean(isOnline) };
}

module.exports = {
  formatTaxiRequestForClient,
  formatTaxiRequestForDriver,
  hideCustomerPhoneFromTaxiRequest,
  enrichTaxiRequestForClient,
  readTaxiMeta,
  generateRequestNumber,
  haversineDistance,
  createTaxiRequest,
  acceptTaxiRequest,
  rejectTaxiRequest,
  updateTaxiRequestStatus,
  cancelTaxiRequest,
  requestTripCancellation,
  updateDriverTripLocation,
  expireStalePendingTaxiRequests,
  getAdminTaxiTrips,
  getAdminTaxiComplaints,
  getNearbyDrivers,
  getActiveDriverPhonesByTaxiType,
  getDriverIncomingRequests,
  getCustomerActiveRequest,
  getDriverActiveRequest,
  getCustomerPendingRatingRequest,
  getCustomerHistory,
  getDriverHistory,
  rateTaxiRequest,
  setDriverOnlineStatus,
};
