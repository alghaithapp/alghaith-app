const {
  selectSingleByPhone,
  resolvePhoneKey,
  saveRow,
  nowIso,
  normalizeObject,
  assertSupabaseAdmin,
  hasColumn,
} = require('./common');
const { ensureAppUser, getAppUserId } = require('./users');
const { stripBase64Deep } = require('../services/image_refs');

async function readLegacyAppStateProfile(phoneKey, key) {
  const row = await selectSingleByPhone('app_state', phoneKey);
  const slice = row?.state?.[key];
  if (!slice || typeof slice !== 'object' || Array.isArray(slice)) return null;
  return stripBase64Deep({ ...slice });
}

function resolveApprovalStatus(profile) {
  if (profile?.isApproved === true || profile?.is_approved === true) {
    return 'approved';
  }
  const status = String(profile?.approvalStatus ?? profile?.approval_status ?? '').trim();
  if (status === 'rejected' || status === 'approved' || status === 'pending') {
    return status;
  }
  return 'pending';
}

function rowToDriverProfileMap(row) {
  if (!row) return null;
  const payload = normalizeObject(row.profile_payload);
  const approvalStatus = row.approval_status || resolveApprovalStatus(payload);
  return stripBase64Deep({
    ...payload,
    name: String(payload.name ?? row.display_name ?? '').trim(),
    phone: String(payload.phone ?? row.phone ?? '').trim(),
    type: String(row.driver_type ?? payload.type ?? 'taxi').trim() || 'taxi',
    isApproved: row.is_approved === true,
    is_approved: row.is_approved === true,
    approvalStatus,
    approval_status: approvalStatus,
    available: row.available !== false,
    isSuspended: row.is_suspended === true,
    is_suspended: row.is_suspended === true,
    latitude: row.latitude ?? payload.latitude ?? payload.lat,
    longitude: row.longitude ?? payload.longitude ?? payload.lng,
    lat: row.latitude ?? payload.latitude ?? payload.lat,
    lng: row.longitude ?? payload.longitude ?? payload.lng,
  });
}

function rowToCourierProfileMap(row) {
  if (!row) return null;
  const payload = normalizeObject(row.profile_payload);
  const approvalStatus = row.approval_status || resolveApprovalStatus(payload);
  return stripBase64Deep({
    ...payload,
    name: String(payload.name ?? row.display_name ?? '').trim(),
    phone: String(payload.phone ?? row.phone ?? '').trim(),
    isApproved: row.is_approved === true,
    is_approved: row.is_approved === true,
    approvalStatus,
    approval_status: approvalStatus,
    available: row.available !== false,
    isSuspended: row.is_suspended === true,
    is_suspended: row.is_suspended === true,
  });
}

async function attachUserIdIfRequired(table, phoneKey, row) {
  if (!(await hasColumn(table, 'user_id'))) return row;
  const userId = await getAppUserId(phoneKey);
  if (!userId) {
    throw new Error('تعذر ربط الملف بحساب المستخدم. تأكد من تسجيل الحساب أولاً.');
  }
  return { ...row, user_id: userId };
}

function buildDriverRow(phoneKey, merged) {
  const approvalStatus = resolveApprovalStatus(merged);
  const isApproved = approvalStatus === 'approved';
  return {
    phone: phoneKey,
    display_name: String(merged.name ?? '').trim() || null,
    driver_type: String(merged.type ?? 'taxi').trim() || 'taxi',
    approval_status: approvalStatus,
    is_approved: isApproved,
    available: merged.available !== false && merged.isSuspended !== true,
    is_suspended: merged.isSuspended === true,
    latitude:
      merged.latitude != null
        ? Number(merged.latitude)
        : merged.lat != null
          ? Number(merged.lat)
          : null,
    longitude:
      merged.longitude != null
        ? Number(merged.longitude)
        : merged.lng != null
          ? Number(merged.lng)
          : null,
    profile_payload: merged,
    updated_at: nowIso(),
  };
}

function buildCourierRow(phoneKey, merged) {
  const approvalStatus = resolveApprovalStatus(merged);
  const isApproved = approvalStatus === 'approved';
  return {
    phone: phoneKey,
    display_name: String(merged.name ?? '').trim() || null,
    approval_status: approvalStatus,
    is_approved: isApproved,
    available: merged.available !== false && merged.isSuspended !== true,
    is_suspended: merged.isSuspended === true,
    profile_payload: merged,
    updated_at: nowIso(),
  };
}

async function getDriverProfile(phone) {
  const phoneKey = await resolvePhoneKey(phone);
  const row = await selectSingleByPhone('driver_profiles', phoneKey);
  if (row) return rowToDriverProfileMap(row);
  return readLegacyAppStateProfile(phoneKey, 'driverProfile');
}

async function saveDriverProfile(phone, patch = {}) {
  const phoneKey = await resolvePhoneKey(phone);
  await ensureAppUser(phoneKey);
  const existing = (await getDriverProfile(phoneKey)) || {};
  const merged = stripBase64Deep({ ...existing, ...normalizeObject(patch) });
  const row = await attachUserIdIfRequired(
    'driver_profiles',
    phoneKey,
    buildDriverRow(phoneKey, merged),
  );
  await saveRow('driver_profiles', row, 'phone');
  return rowToDriverProfileMap(row);
}

async function deleteDriverProfile(phone) {
  const phoneKey = await resolvePhoneKey(phone);
  const supabase = assertSupabaseAdmin();
  const { error } = await supabase.from('driver_profiles').delete().eq('phone', phoneKey);
  if (error && !/does not exist/i.test(error.message || '')) {
    throw new Error(error.message);
  }
}

async function getCourierProfile(phone) {
  const phoneKey = await resolvePhoneKey(phone);
  const row = await selectSingleByPhone('courier_profiles', phoneKey);
  if (row) return rowToCourierProfileMap(row);
  return readLegacyAppStateProfile(phoneKey, 'courierProfile');
}

async function saveCourierProfile(phone, patch = {}) {
  const phoneKey = await resolvePhoneKey(phone);
  await ensureAppUser(phoneKey);
  const existing = (await getCourierProfile(phoneKey)) || {};
  const merged = stripBase64Deep({ ...existing, ...normalizeObject(patch) });
  const row = await attachUserIdIfRequired(
    'courier_profiles',
    phoneKey,
    buildCourierRow(phoneKey, merged),
  );
  await saveRow('courier_profiles', row, 'phone');
  return rowToCourierProfileMap(row);
}

async function deleteCourierProfile(phone) {
  const phoneKey = await resolvePhoneKey(phone);
  const supabase = assertSupabaseAdmin();
  const { error } = await supabase.from('courier_profiles').delete().eq('phone', phoneKey);
  if (error && !/does not exist/i.test(error.message || '')) {
    throw new Error(error.message);
  }
}

module.exports = {
  getDriverProfile,
  saveDriverProfile,
  deleteDriverProfile,
  getCourierProfile,
  saveCourierProfile,
  deleteCourierProfile,
  rowToDriverProfileMap,
  rowToCourierProfileMap,
};
