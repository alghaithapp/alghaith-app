const { createClient } = require('@supabase/supabase-js');

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

async function saveRow(table, payload, conflictColumn) {
  const supabase = assertSupabaseAdmin();
  const conflictValue = payload[conflictColumn];
  if (conflictValue === undefined || conflictValue === null || String(conflictValue).trim() === '') {
    throw new Error(`Missing ${conflictColumn} for ${table}.`);
  }

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
  return selectSingle('app_users', 'phone', phone);
}

async function getAppUserId(phone) {
  const appUser = await getAppUser(phone);
  return appUser?.id ? String(appUser.id) : null;
}

async function saveAppUser(phone, data = {}) {
  const payload = { phone, updated_at: nowIso() };
  assignIfDefined(payload, 'full_name', data.fullName ?? data.full_name);
  assignIfDefined(payload, 'role', data.role);
  assignIfDefined(payload, 'avatar_base64', data.avatarBase64 ?? data.avatar_base64);
  return saveRow('app_users', payload, 'phone');
}

async function deleteAppUser(phone) {
  return deleteRow('app_users', 'phone', phone);
}

async function getCustomerProfile(phone) {
  return selectSingle('customer_profiles', 'phone', phone);
}

async function saveCustomerProfile(phone, data = {}) {
  const basePayload = {
    phone,
    updated_at: nowIso(),
  };
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
  assignIfDefined(basePayload, 'address', data.address);

  return saveRow(
    'customer_profiles',
    basePayload,
    'phone'
  );
}

async function deleteCustomerProfile(phone) {
  return deleteRow('customer_profiles', 'phone', phone);
}

async function getMerchantProfile(phone) {
  return selectSingle('merchant_profiles', 'phone', phone);
}

async function saveMerchantProfile(phone, data = {}) {
  const basePayload = { updated_at: nowIso() };
  assignIfDefined(basePayload, 'store_name', data.store_name ?? data.storeName);
  assignIfDefined(basePayload, 'description', data.description);
  assignIfDefined(
    basePayload,
    'primary_service_id',
    data.primary_service_id ?? data.primaryServiceId
  );
  assignIfDefined(basePayload, 'whatsapp', data.whatsapp);
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
  basePayload.work_sample_images_base64 = normalizeArray(
    data.work_sample_images_base64 ?? data.workSampleImagesBase64
  );
  basePayload.professional_info = normalizeObject(
    data.professional_info ?? data.professionalInfo
  );
  assignIfDefined(
    basePayload,
    'professional_category_id',
    data.professional_category_id ?? data.professionalCategoryId
  );
  basePayload.service_ids = normalizeArray(data.service_ids ?? data.serviceIds);
  assignIfDefined(
    basePayload,
    'active_service_id',
    data.active_service_id ?? data.activeServiceId
  );
  return saveRow('merchant_profiles', { ...basePayload, phone }, 'phone');
}

async function deleteMerchantProfile(phone) {
  return deleteRow('merchant_profiles', 'phone', phone);
}

async function getCustomerAddresses(phone) {
  return selectMany(
    'customer_addresses',
    [{ method: 'eq', column: 'phone', value: phone }],
    { column: 'sort_order', ascending: true }
  );
}

async function saveCustomerAddress(phone, data = {}) {
  const addressText = String(data.address ?? data.address_text ?? '').trim();
  if (!addressText) {
    throw new Error('Address is required.');
  }
  const sortOrder = Number.parseInt(data.sortOrder ?? data.sort_order, 10) || 0;
  const supabase = assertSupabaseAdmin();
  const existing = await supabase
    .from('customer_addresses')
    .select('id')
    .eq('phone', phone)
    .eq('address_text', addressText)
    .maybeSingle();
  if (existing.error) throw new Error(existing.error.message);

  const payload = {
    phone,
    address_text: addressText,
    sort_order: sortOrder,
    updated_at: nowIso(),
  };

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
  const { error } = await supabase
    .from('customer_addresses')
    .delete()
    .eq('phone', phone)
    .eq('address_text', address);
  if (error) throw new Error(error.message);
}

async function getCustomerFavorites(phone) {
  return selectMany(
    'customer_favorites',
    [{ method: 'eq', column: 'phone', value: phone }],
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

  if (!isFavorite) {
    const { error } = await supabase
      .from('customer_favorites')
      .delete()
      .eq('phone', phone)
      .eq('product_id', productId);
    if (error) throw new Error(error.message);
    return null;
  }

  const payload = {
    phone,
    product_id: productId,
    updated_at: nowIso(),
  };

  const existing = await supabase
    .from('customer_favorites')
    .select('phone, product_id')
    .eq('phone', phone)
    .eq('product_id', productId)
    .maybeSingle();
  if (existing.error) throw new Error(existing.error.message);

  if (existing.data) {
    const { data: updated, error } = await supabase
      .from('customer_favorites')
      .update(payload)
      .eq('phone', phone)
      .eq('product_id', productId)
      .select()
      .maybeSingle();
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
  const order = normalizeObject(data.order ?? data.order_payload);
  const orderId = String(order.id ?? data.id ?? '').trim();
  if (!orderId) {
    throw new Error('Order id is required.');
  }

  return saveRow(
    'customer_orders',
    {
      id: orderId,
      phone,
      order_number: String(order.orderNumber ?? data.order_number ?? '').trim() || null,
      status_key: String(order.statusKey ?? data.status_key ?? '').trim() || null,
      delivery_status_key:
        String(order.deliveryStatusKey ?? data.delivery_status_key ?? '').trim() || null,
      order_payload: order,
      updated_at: nowIso(),
    },
    'id'
  );
}

async function getUserState(phone) {
  const row = await selectSingle('app_state', 'phone', phone);
  return row ? row.state || null : null;
}

async function saveUserState(phone, state = {}) {
  const payload = {
    phone,
    state,
    updated_at: nowIso(),
  };
  return saveRow('app_state', payload, 'phone');
}

async function deleteUserState(phone) {
  return deleteRow('app_state', 'phone', phone);
}

async function getMerchantProducts(phone) {
  return selectMany(
    'merchant_products',
    [{ method: 'eq', column: 'phone', value: phone }],
    { column: 'created_at', ascending: false }
  );
}

async function saveMerchantProduct(phone, data = {}) {
  const payload = {
    id:
      data.id && String(data.id).trim().length > 0
        ? String(data.id).trim()
        : String(Date.now()),
    phone,
    updated_at: nowIso(),
  };
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

async function listShoppingStores(subCategoryId = '') {
  const profiles = await selectMany('merchant_profiles');
  const target = String(subCategoryId || '').trim();
  const result = [];

  for (const profile of profiles) {
    const serviceIds = normalizeArray(profile.service_ids).map((item) =>
      String(item)
    );
    const hasShopping = serviceIds.includes('product');
    const isOpen = profile.is_open !== false;
    if (!hasShopping || !isOpen) continue;

    const products = await selectMany(
      'merchant_products',
      [
        { method: 'eq', column: 'phone', value: profile.phone },
        { method: 'eq', column: 'category', value: 'product' },
      ],
      { column: 'created_at', ascending: false }
    );

    const filteredProducts = products.filter((row) => {
      if (!target) return true;
      return String(row.sub_category || '').trim() === target;
    });

    if (filteredProducts.length === 0) continue;

    result.push({
      profile,
      products: filteredProducts,
    });
  }

  return result;
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
  listRealEstateListings,
};
