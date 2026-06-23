const {
  selectSingleByPhone,
  resolvePhoneKey,
  nowIso,
  assignIfDefined,
  saveRow,
  deleteRow,
  getPhoneVariants,
  assertSupabaseAdmin,
  PLATFORM_ADMIN_PHONES,
} = require('./common');

async function getAppUser(phone) {
  return selectSingleByPhone('app_users', phone);
}

async function getAppUserId(phone) {
  const appUser = await getAppUser(phone);
  return appUser?.id ? String(appUser.id) : null;
}

async function ensureAppUser(phone, seed = {}) {
  const existing = await getAppUser(phone);
  if (existing) return existing;
  await saveAppUser(phone, seed);
  return getAppUser(phone);
}

async function saveAppUser(phone, data = {}) {
  const phoneKey = await resolvePhoneKey(phone);
  const existing = await getAppUser(phoneKey);
  const incomingType = data.account_type ?? data.accountType;
  if (
    incomingType &&
    existing?.account_type &&
    existing.account_type !== incomingType
  ) {
    throw new Error('Account type is locked and cannot be changed.');
  }

  const payload = { phone: phoneKey, updated_at: nowIso() };
  assignIfDefined(payload, 'full_name', data.fullName ?? data.full_name);
  assignIfDefined(payload, 'role', data.role);
  assignIfDefined(payload, 'account_type', incomingType);
  const avatarRef = data.avatar_base64 ?? data.avatarBase64;
  assignIfDefined(payload, 'avatar_base64', avatarRef);
  assignIfDefined(
    payload,
    'customer_avatar_base64',
    data.customer_avatar_base64 ?? data.customerAvatarBase64 ?? avatarRef
  );
  return saveRow('app_users', payload, 'phone');
}

async function deleteAppUser(phone) {
  const phoneKey = await resolvePhoneKey(phone);
  const supabase = assertSupabaseAdmin();

  const phoneVariants = getPhoneVariants(phoneKey);
  if (phoneVariants.length > 0) {
    const { error: tokenError } = await supabase
      .from('device_tokens')
      .delete()
      .in('phone', phoneVariants);
    if (tokenError && !/does not exist/i.test(tokenError.message || '')) {
      throw new Error(tokenError.message);
    }

    const { error: inboxError } = await supabase
      .from('push_inbox_state')
      .delete()
      .in('phone', phoneVariants);
    if (inboxError && !/does not exist/i.test(inboxError.message || '')) {
      console.warn('deleteAppUser push_inbox_state cleanup:', inboxError.message);
    }

    for (const tableColumn of ['merchant_phone', 'customer_phone']) {
      const { error: reviewError } = await supabase
        .from('merchant_reviews')
        .delete()
        .in(tableColumn, phoneVariants);
      if (reviewError && !/does not exist/i.test(reviewError.message || '')) {
        console.warn(`deleteAppUser reviews cleanup (${tableColumn}):`, reviewError.message);
      }
    }
  }

  return deleteRow('app_users', 'phone', phoneKey);
}

async function getUserState(phone) {
  const row = await selectSingleByPhone('app_state', phone);
  return row ? row.state || null : null;
}

async function saveUserState(phone, state = {}) {
  const phoneKey = await resolvePhoneKey(phone);
  await ensureAppUser(phoneKey);
  // استخدام دالة merge_app_state للدمج الذري بدلاً من الاستبدال الكامل
  // هذا يمنع فقدان بيانات driverProfile, courierProfile, merchantStore, إلخ.
  try {
    const supabase = assertSupabaseAdmin();
    const { data, error } = await supabase.rpc('merge_app_state', {
      p_phone: phoneKey,
      p_state: state,
    });
    if (error) {
      // fallback: إذا كانت الـ RPC غير موجودة، استخدم upsert العادي
      const payload = { phone: phoneKey, state, updated_at: nowIso() };
      return saveRow('app_state', payload, 'phone');
    }
    return data;
  } catch (_) {
    const payload = { phone: phoneKey, state, updated_at: nowIso() };
    return saveRow('app_state', payload, 'phone');
  }
}

async function deleteUserState(phone) {
  return deleteRow('app_state', 'phone', phone);
}

async function getConfiguredAdminPhones() {
  const envPhones = String(process.env.ADMIN_PHONES || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);

  const allPhones = [...envPhones, ...PLATFORM_ADMIN_PHONES];
  const expanded = new Set();
  for (const phone of allPhones) {
    for (const variant of getPhoneVariants(phone)) {
      expanded.add(variant);
    }
  }
  return expanded;
}

async function assertAdminAccess(phone) {
  const normalized = await resolvePhoneKey(phone);
  const variants = getPhoneVariants(normalized);
  const adminPhones = await getConfiguredAdminPhones();

  if (variants.some((item) => adminPhones.has(item))) {
    return normalized;
  }

  const appUser = await getAppUser(normalized);
  const appUserRole = String(appUser?.role ?? '').trim();
  if (appUserRole === 'admin') {
    return normalized;
  }

  const state = await getUserState(normalized);
  if (state?.adminAccess === true) {
    return normalized;
  }
  const role = String(state?.userRole ?? state?.user_role ?? '').trim();
  if (role === 'admin') {
    return normalized;
  }

  throw new Error('Admin access required.');
}

module.exports = {
  getAppUser,
  getAppUserId,
  ensureAppUser,
  saveAppUser,
  deleteAppUser,
  getUserState,
  saveUserState,
  deleteUserState,
  getConfiguredAdminPhones,
  assertAdminAccess,
};
