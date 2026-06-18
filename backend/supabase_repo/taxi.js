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
  getSupabaseAdmin,
} = require('./common');
const {
  ensureAppUser,
  getUserState,
} = require('./users');
const {
  readDriverProfileFromState,
  isDriverProfileComplete,
  isDriverApproved,
} = require('./couriers_drivers');

function readTaxiMeta(row) {
  const payload = normalizeObject(row.request_payload);
  return {
    row,
    payload,
    id: String(row.id ?? payload.id ?? '').trim(),
    customerPhone: String(row.phone ?? payload.customerPhone ?? '').trim(),
    driverPhone: String(
      row.driver_phone ?? payload.driverPhone ?? payload.assignedDriverPhone ?? ''
    ).trim(),
    statusKey: String(row.status_key ?? payload.statusKey ?? '').trim(),
    rideTypeId: String(row.ride_type_id ?? payload.rideTypeId ?? '').trim(),
  };
}

function isTaxiPoolRequest(meta) {
  const status = meta.statusKey;
  return (status === 'pending' || status === 'new') && !meta.driverPhone;
}

async function saveTaxiRequest(phone, data = {}, options = {}) {
  const customerPhone = await resolvePhoneKey(phone);
  await ensureAppUser(customerPhone, data);

  const request = normalizeObject(data.request ?? data.request_payload);
  const requestId = String(request.id ?? data.id ?? '').trim();
  if (!requestId) {
    throw new Error('Request id is required.');
  }

  const existingRow = await selectSingle('taxi_requests', 'id', requestId);
  const previousMeta = existingRow ? readTaxiMeta(existingRow) : null;

  const rawDriverPhone = String(
    data.driver_phone ??
      data.driverPhone ??
      request.driverPhone ??
      request.assignedDriverPhone ??
      ''
  ).trim();
  const driverPhone = rawDriverPhone ? await resolvePhoneKey(rawDriverPhone) : null;

  request.customerPhone = customerPhone;
  if (driverPhone) {
    request.driverPhone = driverPhone;
    request.assignedDriverPhone = driverPhone;
  }

  const payload = {
    id: requestId,
    phone: customerPhone,
    request_number: String(request.requestNumber ?? data.request_number ?? '').trim() || null,
    status_key: String(request.statusKey ?? data.status_key ?? '').trim() || 'pending',
    ride_type_id: String(request.rideTypeId ?? data.ride_type_id ?? '').trim() || null,
    request_payload: request,
    updated_at: nowIso(),
  };

  if (await hasColumn('taxi_requests', 'driver_phone')) {
    payload.driver_phone = driverPhone;
  }

  const savedRow = await saveRow('taxi_requests', payload, 'id');
  const nextMeta = readTaxiMeta(savedRow);

  if (!options.skipPush) {
    try {
      const { onTaxiRequestSaved } = require('./push_events');
      await onTaxiRequestSaved({
        previousMeta,
        nextMeta,
        isNew: !existingRow,
      });
    } catch (error) {
      console.error('push onTaxiRequestSaved error:', error?.message || error);
    }
  }

  return savedRow;
}

async function getCustomerTaxiRequests(phone) {
  const normalized = await resolvePhoneKey(phone);
  const variants = getPhoneVariants(normalized);
  if (await hasColumn('taxi_requests', 'phone')) {
    return selectMany(
      'taxi_requests',
      [{ method: 'in', column: 'phone', value: variants }],
      { column: 'updated_at', ascending: false }
    );
  }
  const rows = await selectMany(
    'taxi_requests',
    [],
    { column: 'updated_at', ascending: false }
  );
  return rows.filter((row) => phonesOverlap(normalized, readTaxiMeta(row).customerPhone));
}

async function getTaxiPoolOrders(driverPhone = '') {
  const rows = await selectMany(
    'taxi_requests',
    [],
    { column: 'updated_at', ascending: false }
  );
  let driverVariants = [];
  if (driverPhone) {
    const normalized = await resolvePhoneKey(driverPhone);
    driverVariants = getPhoneVariants(normalized);
  }
  return rows.filter((row) => {
    const meta = readTaxiMeta(row);
    if (!isTaxiPoolRequest(meta)) return false;
    if (!driverVariants.length) return true;
    const rejected = Array.isArray(meta.payload.rejectedByDrivers)
      ? meta.payload.rejectedByDrivers.map((item) => String(item).trim())
      : [];
    return !driverVariants.some((variant) => rejected.includes(variant));
  });
}

async function getDriverTaxiOrders(driverPhone) {
  const variants = getPhoneVariants(driverPhone);
  if (await hasColumn('taxi_requests', 'driver_phone')) {
    return selectMany(
      'taxi_requests',
      [{ method: 'in', column: 'driver_phone', value: variants }],
      { column: 'updated_at', ascending: false }
    );
  }

  const rows = await selectMany(
    'taxi_requests',
    [],
    { column: 'updated_at', ascending: false }
  );
  return rows.filter((row) => {
    const meta = readTaxiMeta(row);
    return phonesOverlap(driverPhone, meta.driverPhone);
  });
}

async function acceptTaxiRequest(driverPhone, requestId, data = {}) {
  const normalizedDriver = await resolvePhoneKey(driverPhone);
  const id = String(requestId || '').trim();
  if (!id) {
    throw new Error('Request id is required.');
  }

  const row = await selectSingle('taxi_requests', 'id', id);
  if (!row) {
    throw new Error('Request not found.');
  }

  const meta = readTaxiMeta(row);
  if (!isTaxiPoolRequest(meta)) {
    throw new Error('Request is not available for acceptance.');
  }

  const driverName =
    String(data.driverName ?? data.driver_name ?? '').trim() || 'سائق الغيث';
  const vehicleType = String(data.vehicleType ?? data.vehicle_type ?? '').trim();

  const nextRequest = {
    ...meta.payload,
    statusKey: 'accepted',
    statusAr: 'تم القبول',
    statusEn: 'Accepted',
    assignedDriverName: driverName,
    driverPhone: normalizedDriver,
    assignedDriverPhone: normalizedDriver,
    vehicleType: vehicleType || meta.payload.vehicleType || null,
    driverAcceptedAt: nowIso(),
  };

  return saveTaxiRequest(meta.customerPhone, {
    request: nextRequest,
    driver_phone: normalizedDriver,
  });
}

async function rejectTaxiRequest(driverPhone, requestId) {
  const normalizedDriver = await resolvePhoneKey(driverPhone);
  const id = String(requestId || '').trim();
  if (!id) {
    throw new Error('Request id is required.');
  }

  const row = await selectSingle('taxi_requests', 'id', id);
  if (!row) {
    throw new Error('Request not found.');
  }

  const meta = readTaxiMeta(row);
  if (!isTaxiPoolRequest(meta)) {
    throw new Error('Request is not available for rejection.');
  }

  const rejected = Array.isArray(meta.payload.rejectedByDrivers)
    ? meta.payload.rejectedByDrivers.map((item) => String(item).trim()).filter(Boolean)
    : [];
  const variants = getPhoneVariants(normalizedDriver);
  const alreadyRejected = variants.some((variant) => rejected.includes(variant));
  if (!alreadyRejected) {
    rejected.push(normalizedDriver);
  }

  const nextRequest = {
    ...meta.payload,
    rejectedByDrivers: rejected,
  };

  return saveTaxiRequest(meta.customerPhone, {
    request: nextRequest,
    driver_phone: null,
  });
}

async function updateTaxiRequestStatus(actorPhone, requestId, updates = {}) {
  const normalizedActor = await resolvePhoneKey(actorPhone);
  const id = String(requestId || '').trim();
  if (!id) {
    throw new Error('Request id is required.');
  }

  const row = await selectSingle('taxi_requests', 'id', id);
  if (!row) {
    throw new Error('Request not found.');
  }

  const meta = readTaxiMeta(row);
  const isCustomer = phonesOverlap(normalizedActor, meta.customerPhone);
  const isDriver = phonesOverlap(normalizedActor, meta.driverPhone);

  if (!isCustomer && !isDriver) {
    throw new Error('You are not authorized to update this request.');
  }

  const statusKey = String(updates.statusKey ?? meta.statusKey ?? '').trim();
  const customerOnlyStatuses = new Set(['cancelled', 'cancel_requested']);
  if (customerOnlyStatuses.has(statusKey) && !isCustomer) {
    throw new Error('Only the customer can cancel this request.');
  }
  if (!customerOnlyStatuses.has(statusKey) && meta.driverPhone && !isDriver) {
    throw new Error('You are not assigned to this request.');
  }

  const nextRequest = {
    ...meta.payload,
    statusKey,
    statusAr: String(updates.statusAr ?? meta.payload.statusAr ?? '').trim(),
    statusEn: String(updates.statusEn ?? meta.payload.statusEn ?? '').trim(),
    assignedDriverName:
      String(updates.assignedDriverName ?? meta.payload.assignedDriverName ?? '').trim() ||
      meta.payload.assignedDriverName,
    vehicleType:
      String(updates.vehicleType ?? meta.payload.vehicleType ?? '').trim() ||
      meta.payload.vehicleType,
    driverPhone: meta.driverPhone || null,
    assignedDriverPhone: meta.driverPhone || null,
  };

  if (statusKey === 'completed') {
    nextRequest.statusAr = 'مكتمل';
    nextRequest.statusEn = 'Completed';
    nextRequest.completedAt = nowIso();
  }

  return saveTaxiRequest(meta.customerPhone, {
    request: nextRequest,
    driver_phone: meta.driverPhone || null,
  });
}

async function getActiveDriverPhones() {
  const users = await selectMany('app_users', []);
  const phones = new Set();

  for (const user of users) {
    const phone = String(user.phone ?? '').trim();
    if (!phone) continue;

    const role = String(user.role ?? '').trim();
    const accountType = String(user.account_type ?? '').trim();
    const isDriverAccount = role === 'driver' || accountType === 'driver';
    if (!isDriverAccount) continue;

    const state = await getUserState(phone);
    const profile = readDriverProfileFromState(state);
    if (!isDriverProfileComplete(profile) || !isDriverApproved(profile)) continue;
    if (profile?.available === false) continue;

    const services = profile?.services;
    if (services && typeof services === 'object' && services.taxi === false) continue;

    phones.add(phone);
  }

  return [...phones];
}

module.exports = {
  readTaxiMeta,
  isTaxiPoolRequest,
  saveTaxiRequest,
  getCustomerTaxiRequests,
  getTaxiPoolOrders,
  getDriverTaxiOrders,
  acceptTaxiRequest,
  rejectTaxiRequest,
  updateTaxiRequestStatus,
  getActiveDriverPhones,
};
