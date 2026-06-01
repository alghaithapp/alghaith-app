const { createClient } = require('@supabase/supabase-js');
const WebSocket = require('ws');

function normalizeSupabaseUrl(url) {
  if (!url) return '';
  let normalized = String(url).trim();
  if (normalized.endsWith('/rest/v1/')) {
    normalized = normalized.slice(0, -'/rest/v1/'.length);
  } else if (normalized.endsWith('/rest/v1')) {
    normalized = normalized.slice(0, -'/rest/v1'.length);
  }
  while (normalized.endsWith('/')) {
    normalized = normalized.slice(0, -1);
  }
  return normalized;
}

const supabaseUrl = normalizeSupabaseUrl(
  process.env.SUPABASE_URL || process.env.SUPABASE_PROJECT_URL || ''
);
const supabaseServiceRoleKey =
  process.env.SUPABASE_SERVICE_ROLE_KEY ||
  process.env.SUPABASE_SERVICE_ROLE ||
  '';
const isConfigured = Boolean(supabaseUrl && supabaseServiceRoleKey);

function decodeJwtPayload(token) {
  const parts = String(token || '').split('.');
  if (parts.length < 2) return null;
  const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, '=');
  try {
    const json = Buffer.from(padded, 'base64').toString('utf8');
    return JSON.parse(json);
  } catch (_) {
    return null;
  }
}

const supabaseKeyPayload = decodeJwtPayload(supabaseServiceRoleKey);
const supabaseKeyRole = supabaseKeyPayload?.role || null;
const isLikelyAnonKey = supabaseKeyRole === 'anon';
const isLikelyServiceRoleKey = supabaseKeyRole === 'service_role';

let supabaseAdmin = null;
const schemaColumnCache = new Map();

function getSupabaseAdmin() {
  if (supabaseAdmin) return supabaseAdmin;
  if (!supabaseUrl || !supabaseServiceRoleKey) {
    return null;
  }
  supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
    realtime: {
      transport: WebSocket,
    },
  });
  return supabaseAdmin;
}

function assertSupabaseAdmin() {
  const admin = getSupabaseAdmin();
  if (!admin) {
    throw new Error(
      'SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required for database operations.'
    );
  }
  return admin;
}

function nowIso() {
  return new Date().toISOString();
}

function assignIfDefined(target, key, value) {
  if (value !== undefined) {
    target[key] = value;
  }
}

function normalizeArray(value) {
  if (Array.isArray(value)) return value;
  if (typeof value === 'string' && value.trim().length > 0) {
    try {
      const parsed = JSON.parse(value);
      if (Array.isArray(parsed)) {
        return parsed;
      }
    } catch (_) {}
  }
  return [];
}

function normalizeObject(value) {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value;
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    try {
      const parsed = JSON.parse(value);
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        return parsed;
      }
    } catch (_) {}
  }
  return {};
}

function profileServiceIds(profile) {
  const serviceIds = normalizeArray(profile.service_ids).map((item) =>
    String(item).trim()
  );
  const parsed = serviceIds.filter(Boolean);
  if (parsed.length > 0) {
    return parsed;
  }
  const primary = String(profile.primary_service_id || '').trim();
  return primary ? [primary] : [];
}

function buildProfileByPhoneMap(profiles) {
  const map = new Map();
  for (const profile of profiles) {
    for (const variant of getPhoneVariants(profile.phone)) {
      map.set(variant, profile);
    }
  }
  return map;
}

function findProfileForPhone(map, phone) {
  for (const variant of getPhoneVariants(phone)) {
    const profile = map.get(variant);
    if (profile) return profile;
  }
  return null;
}

function isUuid(value) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    String(value || '').trim()
  );
}

function getPhoneVariants(phone) {
  const digits = String(phone || '').replace(/\D/g, '');
  if (digits.length < 10) {
    const trimmed = String(phone || '').trim();
    return trimmed ? [trimmed] : [];
  }
  const core = digits.slice(-10);
  return [`+964${core}`, `964${core}`, `0${core}`, core];
}

function canonicalPhone(phone) {
  const digits = String(phone || '').replace(/\D/g, '');
  if (!digits) return '';
  if (digits.startsWith('0') && digits.length >= 11) {
    return `+964${digits.slice(1)}`;
  }
  if (digits.startsWith('964')) {
    return `+${digits}`;
  }
  if (digits.length === 10 && digits.startsWith('7')) {
    return `+964${digits}`;
  }
  const trimmed = String(phone || '').trim();
  return trimmed.startsWith('+') ? trimmed : `+${digits}`;
}

async function selectSingleByPhone(table, phone) {
  const variants = getPhoneVariants(phone);
  if (variants.length === 0) return null;

  const supabase = assertSupabaseAdmin();
  const { data, error } = await supabase
    .from(table)
    .select()
    .in('phone', variants)
    .order('updated_at', { ascending: false })
    .limit(1);
  if (error) throw new Error(error.message);
  if (!Array.isArray(data) || data.length === 0) return null;
  return data[0];
}

async function resolvePhoneKey(phone) {
  const tables = ['app_users', 'customer_profiles', 'merchant_profiles', 'app_state'];
  for (const table of tables) {
    const existing = await selectSingleByPhone(table, phone);
    if (existing?.phone) {
      return existing.phone;
    }
  }
  return canonicalPhone(phone);
}

async function selectSingle(table, column, value) {
  const supabase = assertSupabaseAdmin();
  const { data, error } = await supabase
    .from(table)
    .select()
    .eq(column, value)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data || null;
}

async function selectMany(table, filters = [], orderBy = null) {
  const supabase = assertSupabaseAdmin();
  let query = supabase.from(table).select();
  for (const filter of filters) {
    query = query[filter.method](filter.column, filter.value);
  }
  if (orderBy) {
    query = query.order(orderBy.column, { ascending: orderBy.ascending });
  }
  const { data, error } = await query;
  if (error) throw new Error(error.message);
  return Array.isArray(data) ? data : [];
}

async function hasColumn(table, column) {
  const cacheKey = `${table}.${column}`;
  if (schemaColumnCache.has(cacheKey)) {
    return schemaColumnCache.get(cacheKey);
  }

  const supabase = assertSupabaseAdmin();
  const { error } = await supabase.from(table).select(column).limit(1);
  const exists = !error;
  schemaColumnCache.set(cacheKey, exists);
  return exists;
}

async function saveRow(table, payload, conflictColumn) {
  const supabase = assertSupabaseAdmin();
  let conflictValue = payload[conflictColumn];
  if (
    conflictValue === undefined ||
    conflictValue === null ||
    String(conflictValue).trim() === ''
  ) {
    throw new Error(`Missing ${conflictColumn} for ${table}.`);
  }

  if (conflictColumn === 'phone') {
    conflictValue = await resolvePhoneKey(conflictValue);
    payload.phone = conflictValue;
    const existing = await selectSingleByPhone(table, conflictValue);
    if (existing) {
      const { data, error } = await supabase
        .from(table)
        .update(payload)
        .eq('phone', existing.phone)
        .select();
      if (error) throw new Error(error.message);
      if (Array.isArray(data)) return data[0] || null;
      return data || null;
    }
  } else {
    const existingQuery = await supabase
      .from(table)
      .select(conflictColumn)
      .eq(conflictColumn, conflictValue)
      .maybeSingle();
    if (existingQuery.error) {
      throw new Error(existingQuery.error.message);
    }

    if (existingQuery.data) {
      const { data, error } = await supabase
        .from(table)
        .update(payload)
        .eq(conflictColumn, conflictValue)
        .select();
      if (error) throw new Error(error.message);
      if (Array.isArray(data)) return data[0] || null;
      return data || null;
    }
  }

  const { data, error } = await supabase.from(table).insert(payload).select();
  if (error) throw new Error(error.message);
  if (Array.isArray(data)) return data[0] || null;
  return data || null;
}

async function deleteRow(table, column, value) {
  const supabase = assertSupabaseAdmin();
  const { error } = await supabase.from(table).delete().eq(column, value);
  if (error) throw new Error(error.message);
}

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
  return deleteRow('app_users', 'phone', phone);
}

async function getCustomerProfile(phone) {
  return selectSingleByPhone('customer_profiles', phone);
}

async function saveCustomerProfile(phone, data = {}) {
  const phoneKey = await resolvePhoneKey(phone);
  const appUser = await ensureAppUser(phoneKey, data);
  const basePayload = {
    updated_at: nowIso(),
  };
  if (await hasColumn('customer_profiles', 'phone')) {
    basePayload.phone = phoneKey;
  }
  if (await hasColumn('customer_profiles', 'user_id')) {
    basePayload.user_id = appUser?.id || null;
  }
  assignIfDefined(
    basePayload,
    'display_name',
    data.display_name ?? data.displayName ?? data.full_name
  );
  assignIfDefined(
    basePayload,
    'avatar_base64',
    data.avatar_base64 ?? data.avatarBase64
  );
  if (await hasColumn('customer_profiles', 'customer_avatar_base64')) {
    assignIfDefined(
      basePayload,
      'customer_avatar_base64',
      data.customer_avatar_base64 ??
        data.customerAvatarBase64 ??
        data.avatar_base64 ??
        data.avatarBase64
    );
  }
  assignIfDefined(basePayload, 'address', data.address);

  const conflictColumn = (await hasColumn('customer_profiles', 'phone'))
    ? 'phone'
    : 'user_id';
  return saveRow('customer_profiles', basePayload, conflictColumn);
}

async function deleteCustomerProfile(phone) {
  return deleteRow('customer_profiles', 'phone', phone);
}

async function getMerchantProfile(phone) {
  return selectSingleByPhone('merchant_profiles', phone);
}

async function saveMerchantProfile(phone, data = {}) {
  const appUser = await ensureAppUser(phone, data);
  const basePayload = { updated_at: nowIso() };
  if (await hasColumn('merchant_profiles', 'user_id')) {
    basePayload.user_id = appUser?.id || null;
  }
  assignIfDefined(basePayload, 'store_name', data.store_name ?? data.storeName);
  assignIfDefined(basePayload, 'description', data.description);
  assignIfDefined(
    basePayload,
    'primary_service_id',
    data.primary_service_id ?? data.primaryServiceId
  );
  if (await hasColumn('merchant_profiles', 'whatsapp')) {
    assignIfDefined(basePayload, 'whatsapp', data.whatsapp);
  }
  assignIfDefined(basePayload, 'address', data.address);
  assignIfDefined(basePayload, 'open_time', data.open_time ?? data.openTime);
  assignIfDefined(basePayload, 'close_time', data.close_time ?? data.closeTime);
  assignIfDefined(basePayload, 'delivery_areas', data.delivery_areas ?? data.deliveryAreas);
  if (data.delivery_fee !== undefined) {
    basePayload.delivery_fee = Number.parseInt(data.delivery_fee, 10) || 0;
  }
  if (data.is_open !== undefined) {
    basePayload.is_open = Boolean(data.is_open);
  }
  if (data.rating !== undefined) {
    basePayload.rating = Number(data.rating);
  }
  assignIfDefined(basePayload, 'cover_image_url', data.cover_image_url ?? data.coverImageUrl);
  assignIfDefined(basePayload, 'logo_image_url', data.logo_image_url ?? data.logoImageUrl);
  assignIfDefined(
    basePayload,
    'profile_image_base64',
    data.profile_image_base64 ?? data.profileImageBase64
  );
  if (await hasColumn('merchant_profiles', 'work_sample_images_base64')) {
    basePayload.work_sample_images_base64 = normalizeArray(
      data.work_sample_images_base64 ?? data.workSampleImagesBase64
    );
  }
  if (await hasColumn('merchant_profiles', 'professional_info')) {
    basePayload.professional_info = normalizeObject(
      data.professional_info ?? data.professionalInfo
    );
  }
  if (await hasColumn('merchant_profiles', 'professional_category_id')) {
    assignIfDefined(
      basePayload,
      'professional_category_id',
      data.professional_category_id ?? data.professionalCategoryId
    );
  }
  if (await hasColumn('merchant_profiles', 'service_ids')) {
    basePayload.service_ids = normalizeArray(data.service_ids ?? data.serviceIds);
  }
  if (await hasColumn('merchant_profiles', 'active_service_id')) {
    assignIfDefined(
      basePayload,
      'active_service_id',
      data.active_service_id ?? data.activeServiceId
    );
  }
  const phoneKey = await resolvePhoneKey(phone);
  return saveRow('merchant_profiles', { ...basePayload, phone: phoneKey }, 'phone');
}

async function deleteMerchantProfile(phone) {
  return deleteRow('merchant_profiles', 'phone', phone);
}

async function getCustomerAddresses(phone) {
  if (await hasColumn('customer_addresses', 'phone')) {
    return selectMany(
      'customer_addresses',
      [{ method: 'eq', column: 'phone', value: phone }],
      { column: 'sort_order', ascending: true }
    );
  }

  const userId = await getAppUserId(phone);
  if (!userId) return [];

  const orderBy = (await hasColumn('customer_addresses', 'sort_order'))
    ? { column: 'sort_order', ascending: true }
    : { column: 'created_at', ascending: false };

  const rows = await selectMany(
    'customer_addresses',
    [{ method: 'eq', column: 'user_id', value: userId }],
    orderBy
  );
  return rows.map((row) => ({
    ...row,
    address_text: row.address_text ?? row.address ?? '',
  }));
}

async function saveCustomerAddress(phone, data = {}) {
  const addressText = String(data.address ?? data.address_text ?? '').trim();
  if (!addressText) {
    throw new Error('Address is required.');
  }
  const sortOrder = Number.parseInt(data.sortOrder ?? data.sort_order, 10) || 0;
  const supabase = assertSupabaseAdmin();
  const appUser = await ensureAppUser(phone, data);
  if (!appUser?.id) {
    throw new Error('Unable to resolve app user for address.');
  }

  let existingQuery = supabase.from('customer_addresses').select('id');
  if (await hasColumn('customer_addresses', 'phone')) {
    existingQuery = existingQuery.eq('phone', phone);
  } else {
    existingQuery = existingQuery.eq('user_id', appUser.id);
  }
  existingQuery = existingQuery.eq(
    (await hasColumn('customer_addresses', 'address_text')) ? 'address_text' : 'address',
    addressText
  );
  const existing = await existingQuery.maybeSingle();
  if (existing.error) throw new Error(existing.error.message);

  const payload = { updated_at: nowIso() };
  if (await hasColumn('customer_addresses', 'phone')) {
    payload.phone = phone;
  }
  if (await hasColumn('customer_addresses', 'user_id')) {
    payload.user_id = appUser.id;
  }
  if (await hasColumn('customer_addresses', 'address_text')) {
    payload.address_text = addressText;
  }
  if (await hasColumn('customer_addresses', 'address')) {
    payload.address = addressText;
  }
  if (await hasColumn('customer_addresses', 'sort_order')) {
    payload.sort_order = sortOrder;
  }
  if (await hasColumn('customer_addresses', 'label')) {
    payload.label = String(data.label || 'عنوان محفوظ');
  }
  if (await hasColumn('customer_addresses', 'is_default')) {
    payload.is_default = Boolean(data.is_default ?? false);
  }

  if (existing.data?.id) {
    const { data: updated, error } = await supabase
      .from('customer_addresses')
      .update(payload)
      .eq('id', existing.data.id)
      .select()
      .maybeSingle();
    if (error) throw new Error(error.message);
    return updated || null;
  }

  const { data: inserted, error } = await supabase
    .from('customer_addresses')
    .insert(payload)
    .select()
    .maybeSingle();
  if (error) throw new Error(error.message);
  return inserted || null;
}

async function deleteCustomerAddress(phone, address) {
  const supabase = assertSupabaseAdmin();
  let query = supabase.from('customer_addresses').delete();
  if (await hasColumn('customer_addresses', 'phone')) {
    query = query.eq('phone', phone);
  } else {
    const userId = await getAppUserId(phone);
    if (!userId) return;
    query = query.eq('user_id', userId);
  }
  query = query.eq(
    (await hasColumn('customer_addresses', 'address_text')) ? 'address_text' : 'address',
    address
  );
  const { error } = await query;
  if (error) throw new Error(error.message);
}

async function getCustomerFavorites(phone) {
  if (await hasColumn('customer_favorites', 'phone')) {
    return selectMany(
      'customer_favorites',
      [{ method: 'eq', column: 'phone', value: phone }],
      { column: 'created_at', ascending: false }
    );
  }

  const userId = await getAppUserId(phone);
  if (!userId) return [];
  return selectMany(
    'customer_favorites',
    [{ method: 'eq', column: 'user_id', value: userId }],
    { column: 'created_at', ascending: false }
  );
}

async function saveCustomerFavorite(phone, data = {}) {
  const productId = String(data.productId ?? data.product_id ?? '').trim();
  if (!productId) {
    throw new Error('Product id is required.');
  }
  const isFavorite = data.isFavorite !== false && data.is_favorite !== false;
  const supabase = assertSupabaseAdmin();
  const appUser = await ensureAppUser(phone, data);
  if (!appUser?.id) {
    throw new Error('Unable to resolve app user for favorite.');
  }

  // Some legacy databases still keep product_id as uuid while parts of the app
  // can generate text ids. Ignore those writes instead of breaking the session.
  if (!isUuid(productId)) {
    return null;
  }

  if (!isFavorite) {
    let removeQuery = supabase.from('customer_favorites').delete();
    if (await hasColumn('customer_favorites', 'phone')) {
      removeQuery = removeQuery.eq('phone', phone);
    } else {
      removeQuery = removeQuery.eq('user_id', appUser.id);
    }
    const { error } = await removeQuery.eq('product_id', productId);
    if (error) throw new Error(error.message);
    return null;
  }

  const payload = {
    product_id: productId,
    updated_at: nowIso(),
  };
  if (await hasColumn('customer_favorites', 'phone')) {
    payload.phone = phone;
  }
  if (await hasColumn('customer_favorites', 'user_id')) {
    payload.user_id = appUser.id;
  }

  let existingQuery = supabase
    .from('customer_favorites')
    .select('product_id')
    .eq('product_id', productId);
  if (await hasColumn('customer_favorites', 'phone')) {
    existingQuery = existingQuery.eq('phone', phone);
  } else {
    existingQuery = existingQuery.eq('user_id', appUser.id);
  }
  const existing = await existingQuery.maybeSingle();
  if (existing.error) throw new Error(existing.error.message);

  if (existing.data) {
    let updateQuery = supabase
      .from('customer_favorites')
      .update(payload)
      .eq('product_id', productId);
    if (await hasColumn('customer_favorites', 'phone')) {
      updateQuery = updateQuery.eq('phone', phone);
    } else {
      updateQuery = updateQuery.eq('user_id', appUser.id);
    }
    const { data: updated, error } = await updateQuery.select().maybeSingle();
    if (error) throw new Error(error.message);
    return updated || null;
  }

  const { data: inserted, error } = await supabase
    .from('customer_favorites')
    .insert(payload)
    .select()
    .maybeSingle();
  if (error) throw new Error(error.message);
  return inserted || null;
}

async function getCustomerOrders(phone) {
  return selectMany(
    'customer_orders',
    [{ method: 'eq', column: 'phone', value: phone }],
    { column: 'created_at', ascending: false }
  );
}

async function saveCustomerOrder(phone, data = {}) {
  await ensureAppUser(phone, data);
  const order = normalizeObject(data.order ?? data.order_payload);
  const orderId = String(order.id ?? data.id ?? '').trim();
  if (!orderId) {
    throw new Error('Order id is required.');
  }

  const merchantPhone =
    String(
      data.merchant_phone ??
        data.merchantPhone ??
        order.merchantPhone ??
        ''
    ).trim() || null;

  const courierPhone =
    String(
      data.courier_phone ??
        data.courierPhone ??
        order.courierPhone ??
        order.assignedCourierPhone ??
        ''
    ).trim() || null;

  const payload = {
    id: orderId,
    phone,
    order_number: String(order.orderNumber ?? data.order_number ?? '').trim() || null,
    status_key: String(order.statusKey ?? data.status_key ?? '').trim() || null,
    delivery_status_key:
      String(order.deliveryStatusKey ?? data.delivery_status_key ?? '').trim() || null,
    order_payload: order,
    updated_at: nowIso(),
  };

  if (await hasColumn('customer_orders', 'merchant_phone')) {
    payload.merchant_phone = merchantPhone;
  }
  if (await hasColumn('customer_orders', 'courier_phone')) {
    payload.courier_phone = courierPhone;
  }

  return saveRow('customer_orders', payload, 'id');
}

function readOrderMeta(row) {
  const payload = normalizeObject(row.order_payload);
  return {
    row,
    payload,
    id: String(row.id ?? payload.id ?? '').trim(),
    customerPhone: String(row.phone ?? payload.customerPhone ?? '').trim(),
    merchantPhone: String(row.merchant_phone ?? payload.merchantPhone ?? '').trim(),
    courierPhone: String(
      row.courier_phone ?? payload.courierPhone ?? payload.assignedCourierPhone ?? ''
    ).trim(),
    statusKey: String(row.status_key ?? payload.statusKey ?? '').trim(),
    deliveryStatusKey: String(
      row.delivery_status_key ?? payload.deliveryStatusKey ?? ''
    ).trim(),
  };
}

function isDeliveryPoolOrder(meta) {
  return (
    meta.statusKey === 'delivering' &&
    meta.deliveryStatusKey === 'waiting' &&
    !meta.courierPhone
  );
}

async function getDeliveryPoolOrders(courierPhone = '') {
  const rows = await selectMany(
    'customer_orders',
    [],
    { column: 'updated_at', ascending: false }
  );
  let courierVariants = [];
  if (courierPhone) {
    const normalized = await resolvePhoneKey(courierPhone);
    courierVariants = getPhoneVariants(normalized);
  }
  return rows.filter((row) => {
    const meta = readOrderMeta(row);
    if (!isDeliveryPoolOrder(meta)) return false;
    if (!courierVariants.length) return true;
    const rejected = Array.isArray(meta.payload.rejectedByCouriers)
      ? meta.payload.rejectedByCouriers.map((item) => String(item).trim())
      : [];
    return !courierVariants.some((variant) => rejected.includes(variant));
  });
}

async function getCourierAssignedOrders(courierPhone) {
  const variants = getPhoneVariants(courierPhone);
  if (await hasColumn('customer_orders', 'courier_phone')) {
    return selectMany(
      'customer_orders',
      [{ method: 'in', column: 'courier_phone', value: variants }],
      { column: 'updated_at', ascending: false }
    );
  }

  const rows = await selectMany(
    'customer_orders',
    [],
    { column: 'updated_at', ascending: false }
  );
  return rows.filter((row) => {
    const meta = readOrderMeta(row);
    return variants.includes(meta.courierPhone);
  });
}

async function acceptDeliveryOrder(courierPhone, orderId, data = {}) {
  const normalizedCourier = await resolvePhoneKey(courierPhone);
  const id = String(orderId || '').trim();
  if (!id) {
    throw new Error('Order id is required.');
  }

  const row = await selectSingle('customer_orders', 'id', id);
  if (!row) {
    throw new Error('Order not found.');
  }

  const meta = readOrderMeta(row);
  if (!isDeliveryPoolOrder(meta)) {
    throw new Error('Order is not available for delivery.');
  }

  const courierName =
    String(data.courierName ?? data.courier_name ?? '').trim() || 'مندوب الغيث';

  const nextOrder = {
    ...meta.payload,
    deliveryStatusKey: 'accepted',
    deliveryStatusAr: 'المندوب في الطريق للمتجر',
    deliveryStatusEn: 'Courier heading to store',
    assignedCourierName: courierName,
    courierPhone: normalizedCourier,
    courierAcceptedAt: nowIso(),
  };

  return saveCustomerOrder(meta.customerPhone, {
    order: nextOrder,
    merchant_phone: meta.merchantPhone || null,
    courier_phone: normalizedCourier,
  });
}

async function updateCourierDeliveryStatus(courierPhone, orderId, updates = {}) {
  const normalizedCourier = await resolvePhoneKey(courierPhone);
  const id = String(orderId || '').trim();
  if (!id) {
    throw new Error('Order id is required.');
  }

  const row = await selectSingle('customer_orders', 'id', id);
  if (!row) {
    throw new Error('Order not found.');
  }

  const meta = readOrderMeta(row);
  const courierVariants = getPhoneVariants(normalizedCourier);
  if (!courierVariants.includes(meta.courierPhone)) {
    throw new Error('You are not assigned to this order.');
  }

  const deliveryStatusKey = String(
    updates.deliveryStatusKey ?? meta.deliveryStatusKey ?? ''
  ).trim();

  const nextOrder = {
    ...meta.payload,
    deliveryStatusKey,
    deliveryStatusAr: String(updates.deliveryStatusAr ?? meta.payload.deliveryStatusAr ?? '').trim(),
    deliveryStatusEn: String(updates.deliveryStatusEn ?? meta.payload.deliveryStatusEn ?? '').trim(),
    assignedCourierName:
      String(updates.assignedCourierName ?? meta.payload.assignedCourierName ?? '').trim() ||
      meta.payload.assignedCourierName,
    courierPhone: normalizedCourier,
  };

  if (deliveryStatusKey === 'picked_up') {
    nextOrder.deliveryStatusAr = 'تم استلام الطلب من المتجر';
    nextOrder.deliveryStatusEn = 'Order picked up from store';
  }

  if (deliveryStatusKey === 'on_way') {
    nextOrder.deliveryStatusAr = 'المندوب في الطريق للزبون';
    nextOrder.deliveryStatusEn = 'Courier on the way';
    nextOrder.estimatedArrivalMinutes = 20;
    nextOrder.estimatedArrivalAt = new Date(Date.now() + 20 * 60 * 1000).toISOString();
  }

  if (deliveryStatusKey === 'delivered' || deliveryStatusKey === 'completed') {
    nextOrder.deliveryStatusKey = 'delivered';
    nextOrder.deliveryStatusAr = 'تم التسليم — دفع نقداً';
    nextOrder.deliveryStatusEn = 'Delivered — cash collected';
    nextOrder.statusKey = 'completed';
    nextOrder.statusAr = 'مكتمل';
    nextOrder.statusEn = 'Completed';
    nextOrder.codConfirmed = true;
    nextOrder.deliveredAt = nowIso();
  }

  return saveCustomerOrder(meta.customerPhone, {
    order: nextOrder,
    merchant_phone: meta.merchantPhone || null,
    courier_phone: normalizedCourier,
  });
}

async function rejectDeliveryOrder(courierPhone, orderId) {
  const normalizedCourier = await resolvePhoneKey(courierPhone);
  const id = String(orderId || '').trim();
  if (!id) {
    throw new Error('Order id is required.');
  }

  const row = await selectSingle('customer_orders', 'id', id);
  if (!row) {
    throw new Error('Order not found.');
  }

  const meta = readOrderMeta(row);
  if (!isDeliveryPoolOrder(meta)) {
    throw new Error('Order is not available for delivery.');
  }

  const rejected = Array.isArray(meta.payload.rejectedByCouriers)
    ? meta.payload.rejectedByCouriers.map((item) => String(item).trim()).filter(Boolean)
    : [];
  const variants = getPhoneVariants(normalizedCourier);
  const alreadyRejected = variants.some((variant) => rejected.includes(variant));
  if (!alreadyRejected) {
    rejected.push(normalizedCourier);
  }

  const nextOrder = {
    ...meta.payload,
    rejectedByCouriers: rejected,
  };

  return saveCustomerOrder(meta.customerPhone, {
    order: nextOrder,
    merchant_phone: meta.merchantPhone || null,
    courier_phone: null,
  });
}

async function getConfiguredAdminPhones() {
  const envPhones = String(process.env.ADMIN_PHONES || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);

  const expanded = new Set();
  for (const phone of envPhones) {
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

async function getAdminReports(phone) {
  await assertAdminAccess(phone);

  const [orders, merchants, users, products] = await Promise.all([
    selectMany('customer_orders', [], { column: 'updated_at', ascending: false }),
    selectMany('merchant_profiles', []),
    selectMany('app_users', []),
    selectMany('merchant_products', []),
  ]);

  let completedOrders = 0;
  let pendingOrders = 0;
  let deliveringOrders = 0;
  let totalSales = 0;
  let codCollected = 0;

  for (const row of orders) {
    const meta = readOrderMeta(row);
    const price = Number(meta.payload.price) || 0;
    if (meta.statusKey === 'completed') {
      completedOrders += 1;
      totalSales += price;
      if (meta.payload.codConfirmed) {
        codCollected += price;
      }
    } else if (meta.statusKey === 'pending' || meta.statusKey === 'preparing') {
      pendingOrders += 1;
    } else if (
      meta.statusKey === 'delivering' ||
      ['accepted', 'picked_up', 'on_way', 'waiting'].includes(meta.deliveryStatusKey)
    ) {
      deliveringOrders += 1;
    }
  }

  const recentOrders = orders.slice(0, 12).map((row) => {
    const meta = readOrderMeta(row);
    return {
      id: meta.id,
      orderNumber: meta.payload.orderNumber,
      statusKey: meta.statusKey,
      statusAr: meta.payload.statusAr,
      price: meta.payload.price,
      merchantStoreName: meta.payload.merchantStoreName,
      customerNameAr: meta.payload.customerNameAr,
      deliveryStatusKey: meta.deliveryStatusKey,
      updatedAt: row.updated_at,
    };
  });

  return {
    totalOrders: orders.length,
    completedOrders,
    pendingOrders,
    deliveringOrders,
    totalSales,
    codCollected,
    totalMerchants: merchants.length,
    openMerchants: merchants.filter((row) => row.is_open !== false).length,
    totalProducts: products.length,
    totalUsers: users.length,
    recentOrders,
  };
}

async function getMerchantIncomingOrders(merchantPhone) {
  const variants = getPhoneVariants(merchantPhone);
  if (await hasColumn('customer_orders', 'merchant_phone')) {
    return selectMany(
      'customer_orders',
      [{ method: 'in', column: 'merchant_phone', value: variants }],
      { column: 'created_at', ascending: false }
    );
  }

  const rows = await selectMany(
    'customer_orders',
    [],
    { column: 'created_at', ascending: false }
  );
  return rows.filter((row) => {
    const payload = normalizeObject(row.order_payload);
    const linkedMerchant = String(
      row.merchant_phone ?? payload.merchantPhone ?? ''
    ).trim();
    return variants.includes(linkedMerchant);
  });
}

async function updateIncomingOrderStatus(merchantPhone, orderId, updates = {}) {
  const normalizedMerchant = await resolvePhoneKey(merchantPhone);
  const id = String(orderId || '').trim();
  if (!id) {
    throw new Error('Order id is required.');
  }

  const row = await selectSingle('customer_orders', 'id', id);
  if (!row) {
    throw new Error('Order not found.');
  }

  const payload = normalizeObject(row.order_payload);
  const linkedMerchant = String(
    row.merchant_phone ?? payload.merchantPhone ?? ''
  ).trim();
  const merchantVariants = getPhoneVariants(normalizedMerchant);
  if (!merchantVariants.includes(linkedMerchant)) {
    throw new Error('You are not allowed to update this order.');
  }

  const nextOrder = {
    ...payload,
    statusKey: String(updates.statusKey ?? payload.statusKey ?? 'pending').trim(),
    statusAr: String(updates.statusAr ?? payload.statusAr ?? '').trim(),
    statusEn: String(updates.statusEn ?? payload.statusEn ?? '').trim(),
  };

  if (updates.deliveryStatusKey !== undefined) {
    nextOrder.deliveryStatusKey = updates.deliveryStatusKey;
  }
  if (updates.deliveryStatusAr !== undefined) {
    nextOrder.deliveryStatusAr = updates.deliveryStatusAr;
  }
  if (updates.deliveryStatusEn !== undefined) {
    nextOrder.deliveryStatusEn = updates.deliveryStatusEn;
  }

  if (nextOrder.statusKey === 'delivering') {
    nextOrder.deliveryStatusKey = 'waiting';
    nextOrder.deliveryStatusAr = 'بانتظار مندوب التوصيل';
    nextOrder.deliveryStatusEn = 'Waiting for courier';
  }

  return saveCustomerOrder(row.phone, {
    order: nextOrder,
    merchant_phone: linkedMerchant,
  });
}

async function getUserState(phone) {
  const row = await selectSingleByPhone('app_state', phone);
  return row ? row.state || null : null;
}

async function saveUserState(phone, state = {}) {
  const phoneKey = await resolvePhoneKey(phone);
  await ensureAppUser(phoneKey);
  const payload = {
    phone: phoneKey,
    state,
    updated_at: nowIso(),
  };
  return saveRow('app_state', payload, 'phone');
}

async function deleteUserState(phone) {
  return deleteRow('app_state', 'phone', phone);
}

async function getMerchantProducts(phone) {
  const variants = getPhoneVariants(phone);
  return selectMany(
    'merchant_products',
    [{ method: 'in', column: 'phone', value: variants }],
    { column: 'created_at', ascending: false }
  );
}

async function saveMerchantProduct(phone, data = {}) {
  const phoneKey = await resolvePhoneKey(phone);
  const appUser = await ensureAppUser(phoneKey, data);
  const payload = {
    id:
      data.id && String(data.id).trim().length > 0
        ? String(data.id).trim()
        : String(Date.now()),
    phone: phoneKey,
    updated_at: nowIso(),
  };
  if (await hasColumn('merchant_products', 'merchant_user_id')) {
    payload.merchant_user_id = appUser?.id || null;
  }
  if (await hasColumn('merchant_products', 'service_id')) {
    payload.service_id = String(
      data.service_id ?? data.serviceId ?? data.category ?? 'restaurant'
    ).trim() || 'restaurant';
  }
  assignIfDefined(payload, 'name_ar', data.name_ar ?? data.nameAr ?? '');
  assignIfDefined(payload, 'name_en', data.name_en ?? data.nameEn ?? '');
  assignIfDefined(
    payload,
    'description_ar',
    data.description_ar ?? data.descriptionAr ?? ''
  );
  assignIfDefined(
    payload,
    'description_en',
    data.description_en ?? data.descriptionEn ?? ''
  );
  if (data.price !== undefined) {
    payload.price = Number.parseInt(data.price, 10) || 0;
  }
  if (data.rating !== undefined) {
    payload.rating = Number(data.rating);
  }
  assignIfDefined(payload, 'category', data.category);
  assignIfDefined(payload, 'sub_category', data.sub_category ?? data.subCategory);
  assignIfDefined(
    payload,
    'category_label_ar',
    data.category_label_ar ?? data.categoryLabelAr
  );
  assignIfDefined(
    payload,
    'category_label_en',
    data.category_label_en ?? data.categoryLabelEn
  );
  assignIfDefined(payload, 'image', data.image ?? data.imageUrl ?? '');
  assignIfDefined(payload, 'image_base64', data.image_base64 ?? data.imageBase64);
  if (data.is_favorite !== undefined) {
    payload.is_favorite = Boolean(data.is_favorite);
  }
  assignIfDefined(
    payload,
    'avg_price_label_ar',
    data.avg_price_label_ar ?? data.avgPriceLabelAr
  );
  assignIfDefined(
    payload,
    'avg_price_label_en',
    data.avg_price_label_en ?? data.avgPriceLabelEn
  );
  assignIfDefined(
    payload,
    'action_label_ar',
    data.action_label_ar ?? data.actionLabelAr
  );
  assignIfDefined(
    payload,
    'action_label_en',
    data.action_label_en ?? data.actionLabelEn
  );
  assignIfDefined(payload, 'address', data.address);
  if (data.bedrooms !== undefined && data.bedrooms !== null) {
    payload.bedrooms = Number.parseInt(data.bedrooms, 10);
  }
  if (data.bathrooms !== undefined && data.bathrooms !== null) {
    payload.bathrooms = Number.parseInt(data.bathrooms, 10);
  }
  if (data.area_square_meter !== undefined && data.area_square_meter !== null) {
    payload.area_square_meter = Number.parseInt(data.area_square_meter, 10);
  }
  if (data.floor_count !== undefined && data.floor_count !== null) {
    payload.floor_count = Number.parseInt(data.floor_count, 10);
  }
  assignIfDefined(payload, 'listing_mode', data.listing_mode ?? data.listingMode);
  if (data.prep_minutes !== undefined && data.prep_minutes !== null) {
    payload.prep_minutes = Number.parseInt(data.prep_minutes, 10);
  }
  if (data.is_available !== undefined) {
    payload.is_available = Boolean(data.is_available);
  }
  return saveRow('merchant_products', payload, 'id');
}

async function deleteMerchantProduct(id, phone) {
  const supabase = assertSupabaseAdmin();
  let query = supabase.from('merchant_products').delete().eq('id', id);
  if (phone && String(phone).trim().length > 0) {
    query = query.eq('phone', phone);
  }
  const { error } = await query;
  if (error) throw new Error(error.message);
}

async function listProfessionalProfiles(professionId = '') {
  const profiles = await selectMany('merchant_profiles');
  const target = String(professionId || '').trim();
  return profiles.filter((row) => {
    const serviceIds = normalizeArray(row.service_ids);
    const hasProfessionals = serviceIds
      .map((item) => String(item))
      .includes('professionals');
    if (!hasProfessionals) return false;
    if (!target) return true;
    const categoryId = String(row.professional_category_id || '').trim();
    return categoryId === target;
  });
}

async function listMerchantStoresByService({
  serviceId,
  productCategory,
  subCategoryId = '',
}) {
  const profiles = await selectMany('merchant_profiles');
  const target = String(subCategoryId || '').trim();
  const result = [];

  for (const profile of profiles) {
    const serviceIds = profileServiceIds(profile);
    const hasService = serviceIds.includes(String(serviceId));
    const isOpen = profile.is_open !== false;
    if (!isOpen) continue;

    const phoneVariants = getPhoneVariants(profile.phone);
    const products = await selectMany(
      'merchant_products',
      [
        { method: 'in', column: 'phone', value: phoneVariants },
        { method: 'eq', column: 'category', value: productCategory },
      ],
      { column: 'created_at', ascending: false }
    );

    const filteredProducts = products.filter((row) => {
      if (row.is_available === false) return false;
      if (!target) return true;
      return String(row.sub_category || '').trim() === target;
    });

    if (!hasService && filteredProducts.length === 0) continue;

    result.push({
      profile,
      products: filteredProducts,
    });
  }

  return result;
}

async function listShoppingStores(subCategoryId = '') {
  return listMerchantStoresByService({
    serviceId: 'product',
    productCategory: 'product',
    subCategoryId,
  });
}

async function listRestaurantStores(subCategoryId = '') {
  return listMerchantStoresByService({
    serviceId: 'restaurant',
    productCategory: 'restaurant',
    subCategoryId,
  });
}

async function listCatalogProducts(category = '', subCategoryId = '') {
  const profiles = await selectMany('merchant_profiles');
  const openProfiles = profiles.filter((row) => row.is_open !== false);
  const profileByPhone = buildProfileByPhoneMap(openProfiles);

  const categoryFilter = String(category || '').trim();
  const target = String(subCategoryId || '').trim();
  const filters = [];
  if (categoryFilter) {
    filters.push({ method: 'eq', column: 'category', value: categoryFilter });
  }

  const products = await selectMany(
    'merchant_products',
    filters,
    { column: 'created_at', ascending: false }
  );

  return products
    .filter((row) => {
      if (row.is_available === false) return false;
      const phone = String(row.phone || '').trim();
      const profile = findProfileForPhone(profileByPhone, phone);
      if (!profile) return false;

      const serviceIds = profileServiceIds(profile);
      if (categoryFilter === 'product' && !serviceIds.includes('product')) {
        return false;
      }
      if (categoryFilter === 'restaurant' && !serviceIds.includes('restaurant')) {
        return false;
      }
      if (target && String(row.sub_category || '').trim() !== target) {
        return false;
      }
      return true;
    })
    .map((row) => {
      const phone = String(row.phone || '').trim();
      const profile = findProfileForPhone(profileByPhone, phone);
      return {
        ...row,
        merchant_phone: phone,
        merchant_store_name: profile?.store_name ?? '',
      };
    });
}

async function listRealEstateListings(subCategoryId = '') {
  const target = String(subCategoryId || '').trim();
  const products = await selectMany(
    'merchant_products',
    [{ method: 'eq', column: 'category', value: 'real_estate' }],
    { column: 'created_at', ascending: false }
  );

  const filteredProducts = products.filter((row) => {
    if (!target) return true;
    return String(row.sub_category || '').trim() === target;
  });

  const profilesByPhone = new Map();
  for (const product of filteredProducts) {
    const phone = String(product.phone || '').trim();
    if (phone) {
      profilesByPhone.set(phone, null);
    }
  }

  for (const phone of profilesByPhone.keys()) {
    profilesByPhone.set(phone, await selectSingle('merchant_profiles', 'phone', phone));
  }

  return filteredProducts.map((product) => {
    const phone = String(product.phone || '').trim();
    return {
      product,
      merchant: profilesByPhone.get(phone) || null,
    };
  });
}

module.exports = {
  isConfigured,
  supabaseKeyRole,
  isLikelyAnonKey,
  isLikelyServiceRoleKey,
  getAppUser,
  saveAppUser,
  deleteAppUser,
  getCustomerProfile,
  saveCustomerProfile,
  deleteCustomerProfile,
  getCustomerAddresses,
  saveCustomerAddress,
  deleteCustomerAddress,
  getCustomerFavorites,
  saveCustomerFavorite,
  getCustomerOrders,
  saveCustomerOrder,
  getMerchantProfile,
  saveMerchantProfile,
  deleteMerchantProfile,
  getUserState,
  saveUserState,
  deleteUserState,
  getMerchantProducts,
  saveMerchantProduct,
  deleteMerchantProduct,
  listProfessionalProfiles,
  listShoppingStores,
  listRestaurantStores,
  listCatalogProducts,
  listRealEstateListings,
  getMerchantIncomingOrders,
  updateIncomingOrderStatus,
  getDeliveryPoolOrders,
  getCourierAssignedOrders,
  acceptDeliveryOrder,
  rejectDeliveryOrder,
  updateCourierDeliveryStatus,
  getAdminReports,
  canonicalPhone,
};
