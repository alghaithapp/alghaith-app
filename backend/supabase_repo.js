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

function parseOptionalBoolean(value) {
  if (value === undefined || value === null) return undefined;
  if (typeof value === 'boolean') return value;
  const normalized = String(value).trim().toLowerCase();
  if (!normalized) return undefined;
  if (['true', '1', 'yes', 'y', 'on'].includes(normalized)) return true;
  if (['false', '0', 'no', 'n', 'off'].includes(normalized)) return false;
  return undefined;
}

function resolveMerchantContactVisibility(profile = {}) {
  const info = normalizeObject(profile.professional_info ?? profile.professionalInfo);
  const visibility = normalizeObject(info.contact_visibility ?? info.contactVisibility);
  const showPhoneToCustomers =
    parseOptionalBoolean(
      profile.show_phone_to_customers ??
        profile.showPhoneToCustomers ??
        visibility.show_phone_to_customers ??
        visibility.showPhoneToCustomers
    ) ?? true;
  const showWhatsAppToCustomers =
    parseOptionalBoolean(
      profile.show_whatsapp_to_customers ??
        profile.showWhatsAppToCustomers ??
        visibility.show_whatsapp_to_customers ??
        visibility.showWhatsAppToCustomers
    ) ?? true;

  return { showPhoneToCustomers, showWhatsAppToCustomers };
}

function withMerchantCustomerContacts(profile = {}) {
  const visibility = resolveMerchantContactVisibility(profile);
  const phone = String(profile.phone || '').trim();
  const whatsapp = String(profile.whatsapp || '').trim();
  const customerPhone = visibility.showPhoneToCustomers ? phone : '';
  const customerWhatsApp = visibility.showWhatsAppToCustomers
    ? whatsapp || phone
    : '';

  return {
    ...profile,
    show_phone_to_customers: visibility.showPhoneToCustomers,
    show_whatsapp_to_customers: visibility.showWhatsAppToCustomers,
    customer_phone: customerPhone,
    customer_whatsapp: customerWhatsApp,
  };
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

function isMerchantFrozen(profile) {
  return profile?.is_frozen === true;
}

function isProfessionalMerchantProfile(profile) {
  if (!profile) return false;
  const primary = String(profile.primary_service_id ?? '').trim();
  if (primary === 'professionals') return true;
  const serviceIds = normalizeArray(profile.service_ids);
  if (serviceIds.map((item) => String(item)).includes('professionals')) return true;
  const info = normalizeObject(profile.professional_info);
  if (String(info.name ?? '').trim()) return true;
  if (String(profile.professional_category_id ?? '').trim()) return true;
  return false;
}

function merchantProfileDisplayName(profile) {
  if (!profile) return '';
  const storeName = String(profile.store_name ?? profile.storeName ?? '').trim();
  if (storeName) return storeName;
  const info = normalizeObject(profile.professional_info);
  return String(info.name ?? '').trim();
}

function isMerchantApproved(profile) {
  if (!profile) return false;
  // إذا كان هناك قرار صريح (موافقة أو رفض) نلتزم به
  if (profile.is_approved === true || profile.isApproved === true) return true;
  if (profile.is_approved === false || profile.isApproved === false) {
    const status = String(
      profile.approval_status ?? profile.approvalStatus ?? ''
    ).trim();
    if (status === 'approved') return true;
    return false;
  }

  const status = String(
    profile.approval_status ?? profile.approvalStatus ?? ''
  ).trim();
  if (status === 'approved') return true;
  if (status === 'pending' || status === 'rejected') return false;

  // حالة انتقالية: إذا لم توجد الأعمدة في قاعدة البيانات بعد
  // نعتبر المتاجر القديمة (التي لها اسم) واصحاب المهن الذين لديهم منتجات موافق عليهم تلقائياً
  if (isProfessionalMerchantProfile(profile)) {
    // المهنيين الجدد يحتاجون موافقة، لكن إذا كان لديهم بيانات قديمة نعتبرهم مفعّلين
    const info = normalizeObject(profile.professional_info);
    return Boolean(String(info.name ?? '').trim());
  }

  const storeName = merchantProfileDisplayName(profile);
  return storeName.length > 0;
}

function merchantApprovalStatus(profile) {
  if (isMerchantApproved(profile)) return 'approved';
  const status = String(profile.approval_status ?? profile.approvalStatus ?? '').trim();
  if (status === 'rejected') return 'rejected';
  if (status === 'pending') return 'pending';
  if (profile.is_approved === false || profile.isApproved === false) return 'pending';
  if (isProfessionalMerchantProfile(profile)) return 'pending';
  return 'approved';
}

function merchantRejectionMessage(profile) {
  return String(profile?.rejection_message_ar ?? profile?.rejectionMessageAr ?? '').trim();
}

const MERCHANT_REJECTION_REASONS = {
  storeName:
    'اسم المتجر غير واضح أو غير مطابق. يرجى إدخال اسم المتجر بشكل صحيح.',
  phone:
    'رقم الهاتف أو واتساب غير صحيح. يرجى إدخال رقم مفعّل على واتساب.',
  address:
    'عنوان المتجر أو موقعه على الخريطة غير واضح. يرجى تحديد الموقع بدقة.',
  images:
    'صور المتجر (الشعار أو الغلاف) غير واضحة أو غير مناسبة. يرجى رفع صور أفضل.',
  description:
    'وصف المتجر ناقص أو غير مناسب. يرجى كتابة وصف واضح لنشاطك.',
};

function mapMerchantApprovalFields(profile) {
  return {
    isApproved: isMerchantApproved(profile),
    approvalStatus: merchantApprovalStatus(profile),
    rejectionReasonKey:
      String(profile?.rejection_reason_key ?? profile?.rejectionReasonKey ?? '').trim() ||
      null,
    rejectionMessageAr: merchantRejectionMessage(profile) || null,
  };
}

async function syncMerchantApprovalToState(phoneKey, patch = {}) {
  const state = (await getUserState(phoneKey)) || {};
  const merchantStore =
    state.merchantStore && typeof state.merchantStore === 'object'
      ? { ...state.merchantStore }
      : {};
  const nextStore = { ...merchantStore, ...patch };
  await saveUserState(phoneKey, { ...state, merchantStore: nextStore });
  return nextStore;
}

async function updateMerchantApprovalRecord(phoneKey, patch = {}) {
  const supabase = assertSupabaseAdmin();
  const variants = getPhoneVariants(phoneKey);
  const dbPatch = { updated_at: nowIso() };
  if (patch.isApproved !== undefined) {
    dbPatch.is_approved = Boolean(patch.isApproved);
  }
  if (patch.approvalStatus !== undefined) {
    dbPatch.approval_status = String(patch.approvalStatus || '').trim();
  }
  if (patch.rejectionReasonKey !== undefined) {
    dbPatch.rejection_reason_key = patch.rejectionReasonKey || null;
  }
  if (patch.rejectionMessageAr !== undefined) {
    dbPatch.rejection_message_ar = patch.rejectionMessageAr || null;
  }
  if (patch.rejectedAt !== undefined) {
    dbPatch.rejected_at = patch.rejectedAt || null;
  }

  const { data, error } = await supabase
    .from('merchant_profiles')
    .update(dbPatch)
    .in('phone', variants)
    .select();

  if (error) {
    if (/column/i.test(error.message || '')) {
      console.warn(`DB_WARNING: Column missing in merchant_profiles. Ensure SQL migration is applied. Error: ${error.message}`);
    } else {
      throw new Error(error.message);
    }
  }

  const statePatch = {
    isApproved: patch.isApproved,
    is_approved: patch.isApproved,
    approvalStatus: patch.approvalStatus,
    approval_status: patch.approvalStatus,
    rejectionReasonKey: patch.rejectionReasonKey ?? null,
    rejection_reason_key: patch.rejectionReasonKey ?? null,
    rejectionMessageAr: patch.rejectionMessageAr ?? null,
    rejection_message_ar: patch.rejectionMessageAr ?? null,
    rejectedAt: patch.rejectedAt ?? null,
    rejected_at: patch.rejectedAt ?? null,
  };
  Object.keys(statePatch).forEach((key) => {
    if (statePatch[key] === undefined) delete statePatch[key];
  });
  await syncMerchantApprovalToState(phoneKey, statePatch);

  if (error && /column/i.test(error.message || '')) {
    // If column is missing, we still want to indicate "success" for state sync
    // but the DB won't have the data. This helps identify the issue.
    return { phone: phoneKey, ...patch, _columnMissing: true };
  }

  return Array.isArray(data) && data.length > 0 ? data[0] : null;
}

/** أقسام التسوق العالمي فقط — لا تُخلط مع التسوق المحلي. */
const GLOBAL_SHOPPING_SUB_CATEGORY_IDS = new Set(['iran', 'china']);

function profileHasService(profile, serviceId) {
  const target = String(serviceId || '').trim();
  if (!target) return false;
  return profileServiceIds(profile).includes(target);
}

function productMatchesStoreListing({
  row,
  profile = null,
  productCategory,
  subCategoryId = '',
  marketplaceCategory = '',
}) {
  if (row.is_available === false) return false;

  const productService = resolveListingProductService(row, profile);
  const requestedCategory = String(productCategory || '').trim();
  const channel = String(marketplaceCategory || '').trim();
  const isBazaarChannel = channel === 'bazar_ghaith';

  if (isBazaarChannel) {
    if (!['product', 'restaurant'].includes(productService)) return false;
  } else if (productService !== requestedCategory) {
    return false;
  }

  const sub = String(row.sub_category || '').trim();
  const target = String(subCategoryId || '').trim();

  if (channel === 'global_shopping') {
    if (!GLOBAL_SHOPPING_SUB_CATEGORY_IDS.has(sub)) return false;
    if (target && sub !== target) return false;
    return true;
  }

  if (isBazaarChannel) {
    if (productService == 'product' && GLOBAL_SHOPPING_SUB_CATEGORY_IDS.has(sub)) {
      return false;
    }
    if (target) return sub === target;
    return true;
  }

  if (channel === 'product' || channel === '') {
    if (GLOBAL_SHOPPING_SUB_CATEGORY_IDS.has(sub)) return false;
    if (target) return sub === target;
    return true;
  }

  if (target) return sub === target;
  return true;
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

function canMerchantPublishInBazaar(profile) {
  return profile?.is_bazaar_member === true;
}

function merchantQualifiesForServiceListing(profile, serviceId) {
  const normalizedServiceId = String(serviceId || '').trim();
  if (normalizedServiceId === 'bazar_ghaith') {
    if (!canMerchantPublishInBazaar(profile)) return false;
    const services = profileServiceIds(profile);
    return services.includes('restaurant') || services.includes('product');
  }
  return profileHasService(profile, normalizedServiceId);
}

function isBazaarEligibleProductCategory(value) {
  const category = String(value || '').trim();
  return category === 'product' || category === 'restaurant';
}

function resolveListingProductService(row, profile) {
  const raw = String(row.category || row.service_id || '').trim();
  if (isBazaarEligibleProductCategory(raw)) return raw;
  if (!profile) return raw;
  const services = profileServiceIds(profile);
  if (services.includes('product')) return 'product';
  if (services.includes('restaurant')) return 'restaurant';
  return raw;
}

function evaluateBazaarCustomerVisibility(profile, products = []) {
  const notes = [];
  if (profile.is_open === false) notes.push('المتجر مغلق');
  if (isMerchantFrozen(profile)) notes.push('الحساب مجمّد');
  if (!canMerchantPublishInBazaar(profile)) notes.push('غير مصرّح في البازار');
  const services = profileServiceIds(profile);
  if (!services.includes('product') && !services.includes('restaurant')) {
    notes.push('التاجر ليس في قسم منتجات أو مطاعم');
  }

  const visibleProducts = products.filter((row) =>
    productMatchesStoreListing({
      row,
      profile,
      productCategory: 'bazar_ghaith',
      marketplaceCategory: 'bazar_ghaith',
    })
  );

  if (products.length === 0) {
    notes.push('لا توجد منتجات منشورة');
  } else if (visibleProducts.length === 0) {
    notes.push('لا يوجد منتج صالح للعرض (القسم أو التوفر)');
  }

  return {
    visibleToCustomers: notes.length === 0 && visibleProducts.length > 0,
    visibleProductCount: visibleProducts.length,
    visibilityNotes: notes,
  };
}

function mapStateItemToProductPayload(item = {}) {
  const category = String(
    item.category ?? item.service_id ?? item.serviceId ?? ''
  ).trim();
  const id = String(item.id || '').trim();
  if (!id || !isBazaarEligibleProductCategory(category)) {
    return null;
  }

  const isAvailable =
    item.isAvailable !== false && item.is_available !== false;

  return {
    id,
    category,
    service_id: category,
    name_ar: item.nameAr ?? item.name_ar ?? '',
    name_en: item.nameEn ?? item.name_en ?? '',
    description_ar: item.descriptionAr ?? item.description_ar ?? '',
    description_en: item.descriptionEn ?? item.description_en ?? '',
    price: Number.parseInt(item.price, 10) || 0,
    rating: Number(item.rating ?? 4.8),
    sub_category: item.subCategory ?? item.sub_category ?? '',
    section_id: item.sectionId ?? item.section_id ?? '',
    category_label_ar: item.categoryLabelAr ?? item.category_label_ar ?? '',
    category_label_en: item.categoryLabelEn ?? item.category_label_en ?? '',
    image: item.image ?? item.imageUrl ?? '',
    image_base64: item.imageBase64 ?? item.image_base64 ?? '',
    is_favorite: Boolean(item.isFavorite ?? item.is_favorite ?? false),
    avg_price_label_ar: item.avgPriceLabelAr ?? item.avg_price_label_ar ?? '',
    avg_price_label_en: item.avgPriceLabelEn ?? item.avg_price_label_en ?? '',
    action_label_ar: item.actionLabelAr ?? item.action_label_ar ?? '',
    action_label_en: item.actionLabelEn ?? item.action_label_en ?? '',
    address: item.address ?? '',
    prep_minutes: item.prepMinutes ?? item.prep_minutes ?? null,
    is_available: isAvailable,
  };
}

/**
 * عند تفعيل البازار: تأكد أن كل منتجات التاجر المنشورة مسبقاً
 * (في merchant_products أو app_state) جاهزة للظهور في بازار ومطاعم الغيث.
 */
async function syncMerchantProductsForBazaar(merchantPhone) {
  const phoneKey = await resolvePhoneKey(merchantPhone);
  const profile = await getMerchantProfile(phoneKey);
  if (!profile || !canMerchantPublishInBazaar(profile)) {
    return { synced: 0, totalEligible: 0 };
  }

  const services = profileServiceIds(profile);
  if (!services.includes('restaurant') && !services.includes('product')) {
    return { synced: 0, totalEligible: 0 };
  }

  const existingProducts = await getMerchantProducts(phoneKey);
  const knownIds = new Set(
    existingProducts.map((row) => String(row.id || '').trim()).filter(Boolean)
  );

  let synced = 0;

  for (const row of existingProducts) {
    let category = String(row.category || row.service_id || '').trim();
    if (!isBazaarEligibleProductCategory(category)) {
      if (services.includes('product')) category = 'product';
      else if (services.includes('restaurant')) category = 'restaurant';
      else continue;
    }
    const sub = String(row.sub_category || '').trim();
    if (category === 'product' && GLOBAL_SHOPPING_SUB_CATEGORY_IDS.has(sub)) {
      continue;
    }

    const needsNormalization =
      row.category !== category ||
      row.service_id !== category ||
      !isBazaarEligibleProductCategory(
        String(row.category || row.service_id || '').trim()
      );
    if (!needsNormalization) continue;

    await saveMerchantProduct(phoneKey, {
      ...row,
      category,
      service_id: category,
    });
    synced += 1;
  }

  const state = await getUserState(phoneKey);
  const stateItems = Array.isArray(state?.items) ? state.items : [];
  for (const item of stateItems) {
    const payload = mapStateItemToProductPayload(item);
    if (!payload || knownIds.has(payload.id)) continue;

    const sub = String(payload.sub_category || '').trim();
    if (
      payload.category === 'product' &&
      GLOBAL_SHOPPING_SUB_CATEGORY_IDS.has(sub)
    ) {
      continue;
    }

    await saveMerchantProduct(phoneKey, payload);
    knownIds.add(payload.id);
    synced += 1;
  }

  const refreshed = await getMerchantProducts(phoneKey);
  const totalEligible = refreshed.filter((row) => {
    const category = String(row.category || row.service_id || '').trim();
    if (!isBazaarEligibleProductCategory(category)) return false;
    if (row.is_available === false) return false;
    const sub = String(row.sub_category || '').trim();
    if (category === 'product' && GLOBAL_SHOPPING_SUB_CATEGORY_IDS.has(sub)) {
      return false;
    }
    return true;
  }).length;

  return { synced, totalEligible };
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

function phonesOverlap(left, right) {
  const leftVariants = new Set(getPhoneVariants(left));
  if (leftVariants.size === 0) return false;
  for (const variant of getPhoneVariants(right)) {
    if (leftVariants.has(variant)) {
      return true;
    }
  }
  return false;
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
  const raw = String(phone || '').trim();
  if (!raw) return raw;

  const tables = ['app_users', 'customer_profiles', 'merchant_profiles', 'app_state'];
  for (const table of tables) {
    const existing = await selectSingleByPhone(table, phone);
    if (existing?.phone) {
      return existing.phone;
    }
  }
  const canonical = canonicalPhone(phone);
  // مفاتيح نظامية غير رقمية (مثل إعدادات المنصة) تُحفظ كما هي.
  if (canonical) return canonical;
  return raw;
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
  const showPhoneToCustomers = parseOptionalBoolean(
    data.show_phone_to_customers ?? data.showPhoneToCustomers
  );
  const showWhatsAppToCustomers = parseOptionalBoolean(
    data.show_whatsapp_to_customers ?? data.showWhatsAppToCustomers
  );
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
  if (await hasColumn('merchant_profiles', 'latitude')) {
    assignIfDefined(basePayload, 'latitude', data.latitude ?? data.lat);
  }
  if (await hasColumn('merchant_profiles', 'longitude')) {
    assignIfDefined(basePayload, 'longitude', data.longitude ?? data.lng);
  }
  if (await hasColumn('merchant_profiles', 'lat')) {
    assignIfDefined(basePayload, 'lat', data.latitude ?? data.lat);
  }
  if (await hasColumn('merchant_profiles', 'lng')) {
    assignIfDefined(basePayload, 'lng', data.longitude ?? data.lng);
  }
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
    const info = normalizeObject(data.professional_info ?? data.professionalInfo);
    if (showPhoneToCustomers !== undefined || showWhatsAppToCustomers !== undefined) {
      const visibility = normalizeObject(info.contact_visibility ?? info.contactVisibility);
      if (showPhoneToCustomers !== undefined) {
        visibility.show_phone_to_customers = showPhoneToCustomers;
        visibility.showPhoneToCustomers = showPhoneToCustomers;
      }
      if (showWhatsAppToCustomers !== undefined) {
        visibility.show_whatsapp_to_customers = showWhatsAppToCustomers;
        visibility.showWhatsAppToCustomers = showWhatsAppToCustomers;
      }
      info.contact_visibility = visibility;
      info.contactVisibility = {
        showPhoneToCustomers:
          visibility.showPhoneToCustomers ?? visibility.show_phone_to_customers,
        showWhatsAppToCustomers:
          visibility.showWhatsAppToCustomers ?? visibility.show_whatsapp_to_customers,
      };
    }
    basePayload.professional_info = info;
  }
  if (await hasColumn('merchant_profiles', 'show_phone_to_customers')) {
    if (showPhoneToCustomers !== undefined) {
      basePayload.show_phone_to_customers = showPhoneToCustomers;
    }
  }
  if (await hasColumn('merchant_profiles', 'show_whatsapp_to_customers')) {
    if (showWhatsAppToCustomers !== undefined) {
      basePayload.show_whatsapp_to_customers = showWhatsAppToCustomers;
    }
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
  if (await hasColumn('merchant_profiles', 'product_sections')) {
    basePayload.product_sections = normalizeArray(
      data.product_sections ?? data.productSections
    );
  }
  if (await hasColumn('merchant_profiles', 'restaurant_category')) {
    assignIfDefined(
      basePayload,
      'restaurant_category',
      data.restaurant_category ?? data.restaurantCategory
    );
  }
  if (await hasColumn('merchant_profiles', 'is_approved')) {
    if (data.is_approved !== undefined || data.isApproved !== undefined) {
      basePayload.is_approved = Boolean(data.is_approved ?? data.isApproved);
    }
  }
  if (await hasColumn('merchant_profiles', 'approval_status')) {
    assignIfDefined(
      basePayload,
      'approval_status',
      data.approval_status ?? data.approvalStatus
    );
  }
  if (await hasColumn('merchant_profiles', 'rejection_reason_key')) {
    assignIfDefined(
      basePayload,
      'rejection_reason_key',
      data.rejection_reason_key ?? data.rejectionReasonKey
    );
  }
  if (await hasColumn('merchant_profiles', 'rejection_message_ar')) {
    assignIfDefined(
      basePayload,
      'rejection_message_ar',
      data.rejection_message_ar ?? data.rejectionMessageAr
    );
  }
  if (await hasColumn('merchant_profiles', 'rejected_at')) {
    assignIfDefined(basePayload, 'rejected_at', data.rejected_at ?? data.rejectedAt);
  }
  const phoneKey = await resolvePhoneKey(phone);
  const existingProfile = await getMerchantProfile(phoneKey);
  if (!existingProfile) {
    if (await hasColumn('merchant_profiles', 'is_approved')) {
      if (basePayload.is_approved === undefined && basePayload.isApproved === undefined) {
        basePayload.is_approved = false;
      }
    }
    if (await hasColumn('merchant_profiles', 'approval_status')) {
      const incomingStatus = String(
        data.approval_status ?? data.approvalStatus ?? ''
      ).trim();
      if (!incomingStatus) {
        basePayload.approval_status = 'pending';
      }
    }
  }
  return saveRow('merchant_profiles', { ...basePayload, phone: phoneKey }, 'phone');
}

function merchantProfileSections(profile) {
  return normalizeArray(profile?.product_sections ?? profile?.productSections);
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

async function listAllCustomerOrders() {
  return selectMany('customer_orders', [], { column: 'updated_at', ascending: false });
}

async function getCustomerOrders(phone) {
  const variants = getPhoneVariants(phone);
  if (variants.length === 0) return [];
  return selectMany(
    'customer_orders',
    [{ method: 'in', column: 'phone', value: variants }],
    { column: 'created_at', ascending: false }
  );
}

async function saveCustomerOrder(phone, data = {}, options = {}) {
  const customerPhone = await resolvePhoneKey(phone);
  await ensureAppUser(customerPhone, data);
  const order = normalizeObject(data.order ?? data.order_payload);
  const orderId = String(order.id ?? data.id ?? '').trim();
  if (!orderId) {
    throw new Error('Order id is required.');
  }

  const existingRow = await selectSingle('customer_orders', 'id', orderId);
  const previousMeta = existingRow ? readOrderMeta(existingRow) : null;

  const rawMerchantPhone =
    String(
      data.merchant_phone ??
        data.merchantPhone ??
        order.merchantPhone ??
        ''
    ).trim();
  const merchantPhone = rawMerchantPhone
    ? await resolvePhoneKey(rawMerchantPhone)
    : null;

  if (merchantPhone) {
    const merchantProfile = await getMerchantProfile(merchantPhone);
    if (!merchantProfile) {
      throw new Error('Merchant not found.');
    }
    if (isMerchantFrozen(merchantProfile)) {
      throw new Error('MERCHANT_FROZEN');
    }
    if (!isMerchantApproved(merchantProfile)) {
      throw new Error('MERCHANT_NOT_APPROVED');
    }
  }

  const rawCourierPhone =
    String(
      data.courier_phone ??
        data.courierPhone ??
        order.courierPhone ??
        order.assignedCourierPhone ??
        ''
    ).trim();
  const courierPhone = rawCourierPhone
    ? await resolvePhoneKey(rawCourierPhone)
    : null;

  order.customerPhone = customerPhone;
  order.merchantPhone = merchantPhone;
  order.courierPhone = courierPhone;

  const payload = {
    id: orderId,
    phone: customerPhone,
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

  const savedRow = await saveRow('customer_orders', payload, 'id');
  const nextMeta = readOrderMeta(savedRow);

  if (!options.skipPush) {
    try {
      const { onOrderSaved } = require('./push_events');
      await onOrderSaved({
        previousMeta,
        nextMeta,
        isNew: !existingRow,
      });
    } catch (error) {
      console.error('push onOrderSaved error:', error?.message || error);
    }
  }

  return savedRow;
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
    return phonesOverlap(courierPhone, meta.courierPhone);
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
  if (!phonesOverlap(normalizedCourier, meta.courierPhone)) {
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
    openMerchants: merchants.filter(
      (row) => row.is_open !== false && !isMerchantFrozen(row)
    ).length,
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
    return phonesOverlap(merchantPhone, linkedMerchant);
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
  if (!phonesOverlap(normalizedMerchant, linkedMerchant)) {
    throw new Error('You are not allowed to update this order.');
  }

  const nextOrder = {
    ...payload,
    statusKey: String(updates.statusKey ?? payload.statusKey ?? 'pending').trim(),
    statusAr: String(updates.statusAr ?? payload.statusAr ?? '').trim(),
    statusEn: String(updates.statusEn ?? payload.statusEn ?? '').trim(),
  };
  if (updates.noteAr !== undefined) {
    nextOrder.noteAr = String(updates.noteAr ?? '').trim();
  }
  if (updates.noteEn !== undefined) {
    nextOrder.noteEn = String(updates.noteEn ?? '').trim();
  }

  if (updates.deliveryStatusKey !== undefined) {
    nextOrder.deliveryStatusKey = updates.deliveryStatusKey;
  }
  if (updates.deliveryStatusAr !== undefined) {
    nextOrder.deliveryStatusAr = updates.deliveryStatusAr;
  }
  if (updates.deliveryStatusEn !== undefined) {
    nextOrder.deliveryStatusEn = updates.deliveryStatusEn;
  }

  if (updates.lineItems !== undefined) {
    nextOrder.lineItems = Array.isArray(updates.lineItems) ? updates.lineItems : [];
  }
  if (updates.price !== undefined) {
    nextOrder.price = Number.parseInt(String(updates.price), 10) || 0;
  }
  if (updates.itemsCount !== undefined) {
    nextOrder.itemsCount = Number.parseInt(String(updates.itemsCount), 10) || 0;
  }
  if (updates.itemsNameAr !== undefined) {
    nextOrder.itemsNameAr = String(updates.itemsNameAr ?? '').trim();
  }
  if (updates.itemsNameEn !== undefined) {
    nextOrder.itemsNameEn = String(updates.itemsNameEn ?? '').trim();
  }
  if (updates.originalPrice !== undefined) {
    nextOrder.originalPrice = Number.parseInt(String(updates.originalPrice), 10) || 0;
  }
  if (updates.itemsSubtotalIqd !== undefined) {
    nextOrder.itemsSubtotalIqd =
      Number.parseInt(String(updates.itemsSubtotalIqd), 10) || 0;
  }
  if (updates.deliveryFeeIqd !== undefined) {
    nextOrder.deliveryFeeIqd = Number.parseInt(String(updates.deliveryFeeIqd), 10) || 0;
  }
  if (updates.promoDiscountIqd !== undefined) {
    nextOrder.promoDiscountIqd =
      Number.parseInt(String(updates.promoDiscountIqd), 10) || 0;
  }
  if (updates.merchantDecisionAt !== undefined) {
    nextOrder.merchantDecisionAt = String(updates.merchantDecisionAt ?? '').trim() || null;
  }
  if (updates.isPriceLocked !== undefined) {
    nextOrder.isPriceLocked = Boolean(updates.isPriceLocked);
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

async function saveDeviceToken(phone, data = {}) {
  const phoneKey = await resolvePhoneKey(phone);
  await ensureAppUser(phoneKey);
  const token = String(data.token ?? '').trim();
  if (!token) {
    throw new Error('Device token is required.');
  }
  const platform = String(data.platform ?? 'unknown').trim() || 'unknown';
  const supabase = assertSupabaseAdmin();
  const existing = await supabase
    .from('device_tokens')
    .select('id')
    .eq('phone', phoneKey)
    .eq('token', token)
    .maybeSingle();
  if (existing.error) {
    throw new Error(existing.error.message);
  }

  const payload = {
    phone: phoneKey,
    token,
    platform,
    updated_at: nowIso(),
  };

  if (existing.data?.id) {
    const { data: updated, error } = await supabase
      .from('device_tokens')
      .update(payload)
      .eq('id', existing.data.id)
      .select();
    if (error) throw new Error(error.message);
    return Array.isArray(updated) ? updated[0] || null : updated || null;
  }

  const { data: inserted, error } = await supabase
    .from('device_tokens')
    .insert(payload)
    .select();
  if (error) throw new Error(error.message);
  return Array.isArray(inserted) ? inserted[0] || null : inserted || null;
}

async function deleteDeviceToken(phone, token) {
  const phoneKey = await resolvePhoneKey(phone);
  const normalizedToken = String(token || '').trim();
  if (!normalizedToken) {
    throw new Error('Device token is required.');
  }
  const supabase = assertSupabaseAdmin();
  const { error } = await supabase
    .from('device_tokens')
    .delete()
    .eq('phone', phoneKey)
    .eq('token', normalizedToken);
  if (error) throw new Error(error.message);
  return { success: true };
}

async function deleteAllDeviceTokens(phone) {
  const phoneKey = await resolvePhoneKey(phone);
  const supabase = assertSupabaseAdmin();
  const { error } = await supabase.from('device_tokens').delete().eq('phone', phoneKey);
  if (error) throw new Error(error.message);
  return { success: true };
}

async function getActiveCourierPhones() {
  const users = await selectMany('app_users', []);
  const phones = new Set();

  for (const user of users) {
    const phone = String(user.phone ?? '').trim();
    if (!phone) continue;

    const role = String(user.role ?? '').trim();
    const accountType = String(user.account_type ?? '').trim();
    const isDeliveryAccount =
      role === 'delivery' || accountType === 'delivery';
    const isMarketplace = accountType === 'marketplace' || !accountType;

    if (!isDeliveryAccount && !isMarketplace) continue;

    const state = await getUserState(phone);
    const profile = state?.courierProfile;
    if (
      isCourierProfileComplete(profile) &&
      isCourierApproved(profile) &&
      profile.available !== false
    ) {
      phones.add(phone);
    }
  }

  return [...phones];
}

async function getDeviceTokensForPhone(phone) {
  const variants = getPhoneVariants(phone);
  if (variants.length === 0) return [];
  return selectMany(
    'device_tokens',
    [{ method: 'in', column: 'phone', value: variants }],
    { column: 'updated_at', ascending: false }
  );
}

async function recordPushInboxDelivered(phone) {
  const phoneKey = await resolvePhoneKey(phone);
  const supabase = assertSupabaseAdmin();
  const now = nowIso();
  const { data: existing, error: readError } = await supabase
    .from('push_inbox_state')
    .select('*')
    .eq('phone', phoneKey)
    .maybeSingle();

  if (readError && !/does not exist/i.test(readError.message || '')) {
    throw new Error(readError.message);
  }
  if (readError && /does not exist/i.test(readError.message || '')) {
    return { skipped: true };
  }

  const nextCount = Number(existing?.unread_count || 0) + 1;
  const payload = {
    phone: phoneKey,
    unread_count: nextCount,
    last_push_at: now,
    updated_at: now,
  };

  if (existing) {
    const { error } = await supabase
      .from('push_inbox_state')
      .update(payload)
      .eq('phone', phoneKey);
    if (error) throw new Error(error.message);
  } else {
    const { error } = await supabase.from('push_inbox_state').insert(payload);
    if (error) throw new Error(error.message);
  }

  return { success: true, unreadCount: nextCount };
}

async function markPushInboxOpened(phone) {
  const phoneKey = await resolvePhoneKey(phone);
  const supabase = assertSupabaseAdmin();
  const now = nowIso();
  const { data: existing, error: readError } = await supabase
    .from('push_inbox_state')
    .select('phone')
    .eq('phone', phoneKey)
    .maybeSingle();

  if (readError && !/does not exist/i.test(readError.message || '')) {
    throw new Error(readError.message);
  }
  if (readError && /does not exist/i.test(readError.message || '')) {
    return { success: true, skipped: true };
  }

  const payload = {
    unread_count: 0,
    last_opened_at: now,
    updated_at: now,
  };

  if (existing) {
    const { error } = await supabase
      .from('push_inbox_state')
      .update(payload)
      .eq('phone', phoneKey);
    if (error) throw new Error(error.message);
  } else {
    const { error } = await supabase.from('push_inbox_state').insert({
      phone: phoneKey,
      ...payload,
    });
    if (error) throw new Error(error.message);
  }

  return { success: true };
}

async function markPushInboxReminderSent(phone) {
  const phoneKey = await resolvePhoneKey(phone);
  const supabase = assertSupabaseAdmin();
  const now = nowIso();
  const { error } = await supabase
    .from('push_inbox_state')
    .update({
      last_reminder_at: now,
      updated_at: now,
    })
    .eq('phone', phoneKey);
  if (error && !/does not exist/i.test(error.message || '')) {
    throw new Error(error.message);
  }
  return { success: true };
}

async function listPushInboxStatesNeedingReminder() {
  const supabase = assertSupabaseAdmin();
  const { data, error } = await supabase.from('push_inbox_state').select('*');
  if (error) {
    if (/does not exist/i.test(error.message || '')) return [];
    throw new Error(error.message);
  }

  const reminderAfterMs = 2 * 60 * 60 * 1000;
  const nowMs = Date.now();

  return (data || []).filter((row) => {
    const unreadCount = Number(row.unread_count || 0);
    if (unreadCount <= 0) return false;

    const lastPush = new Date(row.last_push_at || 0);
    if (Number.isNaN(lastPush.getTime()) || nowMs - lastPush.getTime() < reminderAfterMs) {
      return false;
    }

    const lastOpened = row.last_opened_at ? new Date(row.last_opened_at) : null;
    if (
      lastOpened &&
      !Number.isNaN(lastOpened.getTime()) &&
      lastOpened.getTime() >= lastPush.getTime()
    ) {
      return false;
    }

    const lastReminder = row.last_reminder_at ? new Date(row.last_reminder_at) : null;
    if (
      lastReminder &&
      !Number.isNaN(lastReminder.getTime()) &&
      lastReminder.getTime() >= lastPush.getTime()
    ) {
      return false;
    }

    return true;
  });
}

async function removeDeviceTokens(tokens = []) {
  const normalized = [...new Set(tokens.map((item) => String(item || '').trim()).filter(Boolean))];
  if (!normalized.length) return { success: true };
  const supabase = assertSupabaseAdmin();
  const { error } = await supabase.from('device_tokens').delete().in('token', normalized);
  if (error) throw new Error(error.message);
  return { success: true };
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
  const merchantProfile = await getMerchantProfile(phoneKey);
  if (!merchantProfile) {
    throw new Error('Merchant profile not found.');
  }
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
  const targetCategory = String(
    data.category ?? data.service_id ?? data.serviceId ?? payload.service_id ?? ''
  ).trim();
  if (targetCategory === 'bazar_ghaith' && !canMerchantPublishInBazaar(merchantProfile)) {
    throw new Error('BAZAAR_APPROVAL_REQUIRED');
  }

  const publishCategory = targetCategory === 'bazar_ghaith' ? 'product' : targetCategory;
  if (publishCategory === 'restaurant' || publishCategory === 'product') {
    const sections = merchantProfileSections(merchantProfile);
    if (sections.length > 0) {
      const sectionId = String(data.section_id ?? data.sectionId ?? '').trim();
      if (!sectionId) {
        throw new Error('SECTION_REQUIRED');
      }
      const known = sections.some(
        (section) => String(section?.id ?? '').trim() === sectionId
      );
      if (!known) {
        throw new Error('SECTION_NOT_FOUND');
      }
    }
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
  if (await hasColumn('merchant_products', 'section_id')) {
    assignIfDefined(payload, 'section_id', data.section_id ?? data.sectionId);
  }
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

function enrichProfessionalProfileRow(row) {
  const info = normalizeObject(row.professional_info);
  const visibility = resolveMerchantContactVisibility(row);
  const rawPhone = String(info.phone || row.whatsapp || row.phone || '').trim();
  const rawWhatsapp = String(
    row.whatsapp || info.whatsapp || info.phone || row.phone || ''
  ).trim();
  const contactPhone = visibility.showPhoneToCustomers
    ? rawPhone || String(row.phone || '').trim()
    : '';
  const contactWhatsapp = visibility.showWhatsAppToCustomers
    ? rawWhatsapp || contactPhone || String(row.phone || '').trim()
    : '';
  const address = String(row.address || info.address || '').trim();
  const openTime = String(row.open_time || info.openTime || '').trim();
  const closeTime = String(row.close_time || info.closeTime || '').trim();
  return {
    ...row,
    phone: contactPhone,
    whatsapp: contactWhatsapp,
    show_phone_to_customers: visibility.showPhoneToCustomers,
    show_whatsapp_to_customers: visibility.showWhatsAppToCustomers,
    customer_phone: contactPhone,
    customer_whatsapp: contactWhatsapp,
    address: address || row.address,
    open_time: openTime || row.open_time,
    close_time: closeTime || row.close_time,
    profile_image_base64:
      row.profile_image_base64 ||
      row.profile_image_url ||
      info.profileImageBase64 ||
      '',
  };
}

async function listProfessionalProfiles(professionId = '') {
  const profiles = await selectMany('merchant_profiles');
  const target = String(professionId || '').trim();
  return profiles
    .filter((row) => {
      if (isMerchantFrozen(row)) return false;
      if (!isMerchantApproved(row)) return false;
      if (row.is_open === false) return false;
      const serviceIds = normalizeArray(row.service_ids);
      const hasProfessionals = serviceIds
        .map((item) => String(item))
        .includes('professionals');
      if (!hasProfessionals) return false;
      if (!target) return true;
      const categoryId = String(row.professional_category_id || '').trim();
      return categoryId === target;
    })
    .map((row) => enrichProfessionalProfileRow(row));
}

async function listMerchantStoresByService({
  serviceId,
  productCategory,
  subCategoryId = '',
  marketplaceCategory = '',
}) {
  const profiles = await selectMany('merchant_profiles');
  const normalizedServiceId = String(serviceId || '').trim();
  const channel = String(marketplaceCategory || '').trim();
  const result = [];

  for (const profile of profiles) {
    const isOpen = profile.is_open !== false;
    if (!isOpen) continue;
    if (isMerchantFrozen(profile)) continue;
    if (!isMerchantApproved(profile)) continue;
    if (!merchantQualifiesForServiceListing(profile, normalizedServiceId)) {
      continue;
    }

    const phoneVariants = getPhoneVariants(profile.phone);
    const products = await selectMany(
      'merchant_products',
      [{ method: 'in', column: 'phone', value: phoneVariants }],
      { column: 'created_at', ascending: false }
    );

    const filteredProducts = products.filter((row) =>
      productMatchesStoreListing({
        row,
        profile,
        productCategory,
        subCategoryId,
        marketplaceCategory: channel || normalizedServiceId,
      })
    );

    // يظهر المتجر فقط إن وُجد منتج واحد على الأقل يطابق القسم/النشاط.
    if (filteredProducts.length === 0) continue;

    result.push({
      profile: withMerchantCustomerContacts(profile),
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
    marketplaceCategory: 'product',
  });
}

async function listServiceStores(
  serviceId = '',
  productCategory = '',
  subCategoryId = '',
  marketplaceCategory = ''
) {
  const normalizedService = String(serviceId || '').trim();
  const normalizedCategory = String(productCategory || normalizedService).trim();
  if (!normalizedService) return [];
  return listMerchantStoresByService({
    serviceId: normalizedService,
    productCategory: normalizedCategory,
    subCategoryId,
    marketplaceCategory: String(marketplaceCategory || '').trim(),
  });
}

async function listOfferCatalogProducts() {
  const stateRows = await selectMany('app_state');
  const offersByPhone = new Map();

  for (const row of stateRows) {
    const state = row.state && typeof row.state === 'object' ? row.state : {};
    const offers = Array.isArray(state.merchantOffers) ? state.merchantOffers : [];
    const activeOffers = offers.filter(
      (offer) => offer && offer.isActive !== false
    );
    if (!activeOffers.length) continue;
    const phone = String(row.phone || '').trim();
    if (phone) offersByPhone.set(phone, activeOffers);
  }

  if (offersByPhone.size === 0) {
    return listCatalogProducts('offers', '');
  }

  const products = await listCatalogProducts('', '');
  const result = [];

  for (const product of products) {
    const phone = String(product.merchant_phone || product.phone || '').trim();
    const phoneVariants = getPhoneVariants(phone);
    let matchedOffers = [];
    for (const variant of phoneVariants) {
      if (offersByPhone.has(variant)) {
        matchedOffers = offersByPhone.get(variant);
        break;
      }
    }
    if (!matchedOffers.length) continue;

    const nameAr = String(product.name_ar || '').trim();
    let bestOffer = null;
    for (const offer of matchedOffers) {
      const names = Array.isArray(offer.productNamesAr)
        ? offer.productNamesAr
        : [];
      const matches =
        names.length === 0 ||
        names.some((name) => {
          const label = String(name || '').trim();
          return label && nameAr.includes(label);
        });
      if (!matches) continue;
      const discount = Number(offer.discountPercent || 0);
      if (
        !bestOffer ||
        discount > Number(bestOffer.discountPercent || 0)
      ) {
        bestOffer = offer;
      }
    }
    if (!bestOffer) continue;

    const price = Number(product.price || 0);
    const discount = Number(bestOffer.discountPercent || 0);
    const discountedPrice = Math.max(
      0,
      Math.round((price * (100 - discount)) / 100)
    );
    result.push({
      ...product,
      category: product.category || 'offers',
      offer_title_ar: bestOffer.titleAr || '',
      offer_discount_percent: discount,
      original_price: price,
      discounted_price: discountedPrice,
    });
  }

  return result.sort(
    (a, b) => Number(b.offer_discount_percent || 0) - Number(a.offer_discount_percent || 0)
  );
}

const MARKETPLACE_CATEGORY_DEFS = [
  { id: 'restaurant', serviceId: 'restaurant', productCategory: 'restaurant' },
  { id: 'product', serviceId: 'product', productCategory: 'product' },
  { id: 'bazar_ghaith', serviceId: 'bazar_ghaith', productCategory: 'bazar_ghaith' },
  { id: 'tourism', serviceId: 'tourism', productCategory: 'tourism' },
  { id: 'beauty', serviceId: 'beauty', productCategory: 'beauty' },
  { id: 'used', serviceId: 'used', productCategory: 'used' },
  { id: 'offers', serviceId: 'offers', productCategory: 'offers' },
  { id: 'cars', serviceId: 'cars', productCategory: 'cars' },
  { id: 'real_estate', serviceId: 'real_estate', productCategory: 'real_estate' },
  { id: 'global_shopping', serviceId: 'product', productCategory: 'product' },
];

async function getMarketplaceStats() {
  const profiles = await selectMany('merchant_profiles');
  const openProfiles = profiles.filter((row) => row.is_open !== false);
  const products = await selectMany(
    'merchant_products',
    [],
    { column: 'created_at', ascending: false }
  );
  const availableProducts = products.filter((row) => row.is_available !== false);
  const profileByPhone = buildProfileByPhoneMap(openProfiles);

  const storeCountByService = {};
  for (const def of MARKETPLACE_CATEGORY_DEFS) {
    const stores = await listMerchantStoresByService({
      serviceId: def.serviceId,
      productCategory: def.productCategory,
      subCategoryId: '',
      marketplaceCategory: def.id,
    });
    storeCountByService[def.id] = stores.length;
  }

  const categories = MARKETPLACE_CATEGORY_DEFS.map((def) => {
    const categoryProducts = availableProducts.filter((row) => {
      const phone = String(row.phone || '').trim();
      const profile = findProfileForPhone(profileByPhone, phone);
      if (!profile) return false;
      if (!merchantQualifiesForServiceListing(profile, def.serviceId)) {
        return false;
      }
      return productMatchesStoreListing({
        row,
        profile,
        productCategory: def.productCategory,
        subCategoryId: '',
        marketplaceCategory: def.id,
      });
    });

    const subCategoryCounts = {};
    for (const row of categoryProducts) {
      const subId = String(row.sub_category || '').trim() || '_all';
      subCategoryCounts[subId] = (subCategoryCounts[subId] || 0) + 1;
    }

    return {
      id: def.id,
      storeCount: storeCountByService[def.id] || 0,
      productCount: categoryProducts.length,
      subCategories: Object.entries(subCategoryCounts).map(([id, count]) => ({
        id: id === '_all' ? '' : id,
        productCount: count,
      })),
    };
  });

  const resolvedCategories = await Promise.all(
    categories.map(async (entry) => {
      const def = MARKETPLACE_CATEGORY_DEFS.find((item) => item.id === entry.id);
      const subCategories = await Promise.all(
        entry.subCategories.map(async (sub) => {
          if (!sub.id || !def) {
            return { ...sub, storeCount: entry.storeCount };
          }
          const stores = await listMerchantStoresByService({
            serviceId: def.serviceId,
            productCategory: def.productCategory,
            subCategoryId: sub.id,
            marketplaceCategory: def.id,
          });
          return {
            ...sub,
            storeCount: stores.length,
          };
        })
      );
      return {
        ...entry,
        subCategories,
        totalCount: Math.max(entry.storeCount, entry.productCount),
      };
    })
  );

  let offerCount = 0;
  try {
    const offers = await listOfferCatalogProducts();
    offerCount = offers.length;
  } catch (_) {
    offerCount = 0;
  }

  const professionals = await listProfessionalProfiles('');
  const realEstate = await listRealEstateListings('');

  return {
    categories: [
      ...resolvedCategories.map((entry) => {
        if (entry.id === 'offers') {
          return {
            ...entry,
            productCount: offerCount,
            totalCount: offerCount,
          };
        }
        if (entry.id === 'real_estate') {
          return {
            ...entry,
            storeCount: realEstate.length,
            productCount: realEstate.length,
            totalCount: realEstate.length,
          };
        }
        return entry;
      }),
      {
        id: 'professionals',
        storeCount: professionals.length,
        productCount: professionals.length,
        totalCount: professionals.length,
        subCategories: [],
      },
    ],
    offerCount,
    professionalCount: professionals.length,
    realEstateCount: realEstate.length,
    updatedAt: nowIso(),
  };
}

async function listRestaurantStores(subCategoryId = '') {
  return listMerchantStoresByService({
    serviceId: 'restaurant',
    productCategory: 'restaurant',
    subCategoryId,
    marketplaceCategory: 'restaurant',
  });
}

async function listCatalogProducts(category = '', subCategoryId = '') {
  const profiles = await selectMany('merchant_profiles');
  const openProfiles = profiles.filter(
    (row) => row.is_open !== false && !isMerchantFrozen(row)
  );
  const profileByPhone = buildProfileByPhoneMap(openProfiles);

  const categoryFilter = String(category || '').trim();
  const target = String(subCategoryId || '').trim();
  const products = await selectMany(
    'merchant_products',
    [],
    { column: 'created_at', ascending: false }
  );

  return products
    .filter((row) => {
      if (row.is_available === false) return false;
      const productService = String(
        row.category || row.service_id || ''
      ).trim();
      if (
        categoryFilter &&
        categoryFilter !== 'bazar_ghaith' &&
        productService !== categoryFilter
      ) {
        return false;
      }
      const phone = String(row.phone || '').trim();
      const profile = findProfileForPhone(profileByPhone, phone);
      if (!profile) return false;

      if (categoryFilter === 'bazar_ghaith') {
        if (!canMerchantPublishInBazaar(profile)) return false;
        const listingService = resolveListingProductService(row, profile);
        if (!['product', 'restaurant'].includes(listingService)) return false;
      }

      const serviceIds = profileServiceIds(profile);
      if (
        categoryFilter === 'product' &&
        !serviceIds.includes('product') &&
        productService !== 'product'
      ) {
        return false;
      }
      if (
        categoryFilter === 'restaurant' &&
        !serviceIds.includes('restaurant') &&
        productService !== 'restaurant'
      ) {
        return false;
      }
      if (
        ['tourism', 'beauty', 'used', 'offers', 'cars'].includes(categoryFilter) &&
        !serviceIds.includes(categoryFilter) &&
        productService !== categoryFilter
      ) {
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
      const profileContacts = withMerchantCustomerContacts(profile || {});
      return {
        ...row,
        merchant_phone: phone,
        merchant_whatsapp: profileContacts.customer_whatsapp ?? '',
        merchant_customer_phone: profileContacts.customer_phone ?? '',
        merchant_customer_whatsapp: profileContacts.customer_whatsapp ?? '',
        merchant_show_phone_to_customers:
          profileContacts.show_phone_to_customers ?? true,
        merchant_show_whatsapp_to_customers:
          profileContacts.show_whatsapp_to_customers ?? true,
        merchant_store_name: profile?.store_name ?? '',
        merchant_address: profile?.address ?? '',
        merchant_latitude:
          profile?.latitude ?? profile?.lat ?? null,
        merchant_longitude:
          profile?.longitude ?? profile?.lng ?? null,
        merchant_open_time: profile?.open_time ?? null,
        merchant_close_time: profile?.close_time ?? null,
        merchant_is_open:
          profile?.is_open === undefined ? true : Boolean(profile?.is_open),
        merchant_is_frozen: profile?.is_frozen === true,
      };
    });
}

async function listRealEstateListings(subCategoryId = '', listingMode = '') {
  const target = String(subCategoryId || '').trim();
  const modeFilter = String(listingMode || '').trim();
  const products = await selectMany(
    'merchant_products',
    [{ method: 'eq', column: 'category', value: 'real_estate' }],
    { column: 'created_at', ascending: false }
  );

  const filteredProducts = products.filter((row) => {
    if (row.is_available === false) return false;
    if (target && String(row.sub_category || '').trim() !== target) {
      return false;
    }
    if (modeFilter) {
      const rowMode = String(row.listing_mode || 'sell').trim();
      if (rowMode !== modeFilter) return false;
    }
    return true;
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

  return filteredProducts
    .map((product) => {
      const phone = String(product.phone || '').trim();
      const merchant = profilesByPhone.get(phone) || null;
      return {
        product,
        merchant: merchant ? withMerchantCustomerContacts(merchant) : null,
      };
    })
    .filter(({ merchant }) => merchant && merchant.is_open !== false && !isMerchantFrozen(merchant));
}

async function saveMerchantReview({
  merchantPhone,
  customerPhone,
  customerName,
  orderId,
  stars,
  comment,
}) {
  const supabase = assertSupabaseAdmin();
  const mPhone = await resolvePhoneKey(merchantPhone);
  const cPhone = await resolvePhoneKey(customerPhone);

  // 1. حفظ التقييم في جدول مخصص (إذا لم يوجد الجدول سيتم استخدام app_state للتاجر كخيار بديل)
  try {
    const { data: review, error } = await supabase
      .from('merchant_reviews')
      .upsert({
        order_id: orderId,
        merchant_phone: mPhone,
        customer_phone: cPhone,
        customer_name: customerName,
        stars: Number(stars),
        comment: comment || '',
        updated_at: nowIso(),
      }, { onConflict: 'order_id' })
      .select()
      .maybeSingle();

    if (error) throw error;

    // 2. حساب المتوسط الجديد للتاجر
    const { data: allReviews, error: fetchError } = await supabase
      .from('merchant_reviews')
      .select('stars')
      .eq('merchant_phone', mPhone);

    if (!fetchError && allReviews.length > 0) {
      const totalStars = allReviews.reduce((sum, r) => sum + (Number(r.stars) || 0), 0);
      const avgRating = (totalStars / allReviews.length).toFixed(1);

      // 3. تحديث ملف التاجر بالتقييم الحقيقي
      await supabase
        .from('merchant_profiles')
        .update({ rating: parseFloat(avgRating) })
        .eq('phone', mPhone);
    }

    // 4. تحديث حالة التاجر (ليصله إشعار بالتقييم الجديد)
    const merchantState = await getUserState(mPhone);
    if (merchantState) {
      const reviews = Array.isArray(merchantState.merchantReviews) ? merchantState.merchantReviews : [];
      const updatedReviews = [
        {
          id: orderId,
          customerName,
          stars: Number(stars),
          comment: comment || '',
          date: new Date().toLocaleDateString('ar-EG'),
        },
        ...reviews.filter(r => r.id !== orderId)
      ].slice(0, 50);

      merchantState.merchantReviews = updatedReviews;
      await saveUserState(mPhone, merchantState);
    }

    return review;
  } catch (error) {
    console.error('saveMerchantReview error:', error);
    // Fallback: إذا لم يوجد جدول، نكتفي بتحديث حالة التاجر
    return { success: false, error: error.message };
  }
}

function readCourierProfileFromState(state) {
  if (!state || typeof state !== 'object') return null;
  const profile = state.courierProfile;
  if (!profile || typeof profile !== 'object') return null;
  return profile;
}

function isCourierProfileComplete(profile) {
  if (!profile || typeof profile !== 'object') return false;
  const name = String(profile.name ?? '').trim();
  const contactPhone = String(profile.phone ?? '').trim();
  const homeAddress = String(
    profile.homeAddress ?? profile.address ?? profile.area ?? ''
  ).trim();
  const vehicleImage = String(
    profile.vehicleImage ?? profile.bikeImage ?? ''
  ).trim();
  return Boolean(name && contactPhone && homeAddress && vehicleImage);
}

function isCourierApproved(profile) {
  return profile?.isApproved === true;
}

const COURIER_REJECTION_REASONS = {
  name: 'الاسم غير صحيح. يرجى إدخال الاسم الثلاثي (الاسم الأول + الأب + العائلة) بشكل واضح.',
  phone: 'رقم الهاتف غير صحيح. يرجى إدخال رقم مفعّل على واتساب.',
  address: 'عنوان السكن غير واضح أو غير مكتمل. يرجى تعديل العنوان.',
  vehicleImage: 'صورة الدراجة غير واضحة أو غير مقبولة. يرجى رفع صورة أوضح للدراجة.',
};

function courierApprovalStatus(profile) {
  if (!profile || typeof profile !== 'object') return 'pending';
  if (profile.isApproved === true || profile.approvalStatus === 'approved') {
    return 'approved';
  }
  const status = String(profile.approvalStatus ?? '').trim();
  if (status === 'rejected') return 'rejected';
  return 'pending';
}

function courierRejectionMessage(profile) {
  const explicit = String(profile?.rejectionMessageAr ?? '').trim();
  if (explicit) return explicit;
  const key = String(profile?.rejectionReasonKey ?? '').trim();
  return COURIER_REJECTION_REASONS[key] || '';
}

function mapCourierForAdmin(phone, user, profile) {
  const name = String(profile.name ?? '').trim();
  const contactPhone = String(profile.phone ?? phone ?? '').trim();
  const homeAddress = String(
    profile.homeAddress ?? profile.address ?? profile.area ?? ''
  ).trim();
  const vehicleImage = String(
    profile.vehicleImage ?? profile.bikeImage ?? ''
  ).trim();

  return {
    phone: String(phone || '').trim(),
    name,
    contactPhone,
    homeAddress,
    vehicleImage,
    available: profile.available !== false && profile.isSuspended !== true,
    isSuspended: profile.isSuspended === true,
    isApproved: isCourierApproved(profile),
    approvalStatus: courierApprovalStatus(profile),
    rejectionReasonKey: String(profile.rejectionReasonKey ?? '').trim() || null,
    rejectionMessageAr: courierRejectionMessage(profile) || null,
    role: String(user?.role ?? '').trim(),
    accountType: String(user?.account_type ?? '').trim(),
    updatedAt: user?.updated_at ?? null,
  };
}

async function getAllCouriers(adminPhone) {
  await assertAdminAccess(adminPhone);

  const [users, states] = await Promise.all([
    selectMany('app_users', [], { column: 'updated_at', ascending: false }),
    selectMany('app_state', [], { column: 'updated_at', ascending: false }),
  ]);

  const stateByPhone = {};
  for (const row of states) {
    const phone = String(row.phone || '').trim();
    if (!phone) continue;
    stateByPhone[phone] = row.state || {};
  }

  const couriers = [];
  const seen = new Set();

  for (const user of users) {
    const phone = String(user.phone || '').trim();
    if (!phone || seen.has(phone)) continue;

    const state = stateByPhone[phone] || {};
    const profile = readCourierProfileFromState(state);
    if (!profile || !isCourierProfileComplete(profile)) continue;

    const name = String(profile.name ?? '').trim();
    const role = String(user.role ?? '').trim();
    const accountType = String(user.account_type ?? '').trim();
    const isCourierAccount =
      role === 'delivery' || accountType === 'delivery' || name.length > 0;

    if (!isCourierAccount) continue;

    seen.add(phone);
    couriers.push(mapCourierForAdmin(phone, user, profile));
  }

  return couriers.sort((a, b) => {
    const rank = (item) => {
      if (item.approvalStatus === 'pending') return 0;
      if (item.approvalStatus === 'rejected') return 1;
      return 2;
    };
    const rankDiff = rank(a) - rank(b);
    if (rankDiff !== 0) return rankDiff;
    return String(a.name || '').localeCompare(String(b.name || ''), 'ar');
  });
}

async function getAllMerchants(adminPhone) {
  await assertAdminAccess(adminPhone);

  const [merchants, orders, products] = await Promise.all([
    selectMany('merchant_profiles', [], { column: 'store_name', ascending: true }),
    selectMany('customer_orders', [], { column: 'updated_at', ascending: false }),
    selectMany('merchant_products', [], { column: 'created_at', ascending: false }),
  ]);
  const userPhones = merchants.map((m) => m.phone).filter(Boolean);

  // Get app_users for these merchants
  const users = userPhones.length > 0
    ? await selectMany('app_users', [{ method: 'in', column: 'phone', value: userPhones }])
    : [];

  const userByPhone = {};
  for (const u of users) {
    userByPhone[u.phone] = u;
  }

  const orderStatsByMerchant = new Map();
  for (const row of orders) {
    const meta = readOrderMeta(row);
    const merchantPhone = meta.merchantPhone;
    if (!merchantPhone) continue;

    let bucket = null;
    for (const variant of getPhoneVariants(merchantPhone)) {
      bucket = orderStatsByMerchant.get(variant);
      if (bucket) break;
    }

    if (!bucket) {
      bucket = {
        totalOrders: 0,
        completedOrders: 0,
        pendingOrders: 0,
        deliveringOrders: 0,
        totalRevenue: 0,
        lastOrderAt: null,
      };
      for (const variant of getPhoneVariants(merchantPhone)) {
        orderStatsByMerchant.set(variant, bucket);
      }
    }

    const price = Number(meta.payload.price || 0);
    bucket.totalOrders += 1;
    if (!bucket.lastOrderAt || String(row.updated_at || '') > String(bucket.lastOrderAt || '')) {
      bucket.lastOrderAt = row.updated_at || null;
    }

    if (meta.statusKey === 'completed') {
      bucket.completedOrders += 1;
      bucket.totalRevenue += price;
    } else if (
      meta.statusKey === 'delivering' ||
      ['accepted', 'picked_up', 'on_way', 'waiting'].includes(meta.deliveryStatusKey)
    ) {
      bucket.deliveringOrders += 1;
    } else {
      bucket.pendingOrders += 1;
    }
  }

  const productStatsByMerchant = new Map();
  for (const row of products) {
    const merchantPhone = String(row.phone || '').trim();
    if (!merchantPhone) continue;

    let bucket = null;
    for (const variant of getPhoneVariants(merchantPhone)) {
      bucket = productStatsByMerchant.get(variant);
      if (bucket) break;
    }

    if (!bucket) {
      bucket = {
        totalProducts: 0,
        availableProducts: 0,
        rows: [],
      };
      for (const variant of getPhoneVariants(merchantPhone)) {
        productStatsByMerchant.set(variant, bucket);
      }
    }

    bucket.totalProducts += 1;
    bucket.rows.push(row);
    if (row.is_available !== false) {
      bucket.availableProducts += 1;
    }
  }

  return merchants.map((m) => {
    const productBucket = productStatsByMerchant.get(m.phone) || {
      totalProducts: 0,
      availableProducts: 0,
      rows: [],
    };
    const bazaarVisibility = evaluateBazaarCustomerVisibility(
      m,
      productBucket.rows
    );

    return {
    ...(orderStatsByMerchant.get(m.phone) || {
      totalOrders: 0,
      completedOrders: 0,
      pendingOrders: 0,
      deliveringOrders: 0,
      totalRevenue: 0,
      lastOrderAt: null,
    }),
    totalProducts: productBucket.totalProducts,
    availableProducts: productBucket.availableProducts,
    visibleToCustomers: bazaarVisibility.visibleToCustomers,
    visibleProductCount: bazaarVisibility.visibleProductCount,
    visibilityNotes: bazaarVisibility.visibilityNotes,
    phone: m.phone,
    storeName: merchantProfileDisplayName(m) || m.store_name || '',
    isProfessional: isProfessionalMerchantProfile(m),
    description: (m.description || '').slice(0, 80),
    primaryServiceId: m.primary_service_id || '',
    isOpen: m.is_open !== false,
    isFrozen: isMerchantFrozen(m),
    rating: Number(m.rating || 0),
    isBazaarMember: m.is_bazaar_member === true,
    createdAt: m.created_at,
    fullName: userByPhone[m.phone]?.full_name || '',
    role: userByPhone[m.phone]?.role || '',
    ...mapMerchantApprovalFields(m),
  };
  }).sort((a, b) => {
    const rank = (item) => {
      if (item.approvalStatus === 'pending') return 0;
      if (item.approvalStatus === 'rejected') return 1;
      return 2;
    };
    const rankDiff = rank(a) - rank(b);
    if (rankDiff !== 0) return rankDiff;
    return String(a.storeName || '').localeCompare(String(b.storeName || ''), 'ar');
  });
}

async function getAdminMerchantDetails(adminPhone, merchantPhone) {
  await assertAdminAccess(adminPhone);

  const profile = await getMerchantProfile(merchantPhone);
  if (!profile) {
    throw new Error('Merchant not found.');
  }

  const [orders, products, appUser] = await Promise.all([
    getMerchantIncomingOrders(profile.phone),
    getMerchantProducts(profile.phone),
    getAppUser(profile.phone),
  ]);

  let totalRevenue = 0;
  let completedOrders = 0;
  let pendingOrders = 0;
  let deliveringOrders = 0;
  let cancelledOrders = 0;
  let codCollected = 0;

  const mappedOrders = orders.map((row) => {
    const meta = readOrderMeta(row);
    const price = Number(meta.payload.price || 0);

    if (meta.statusKey === 'completed') {
      completedOrders += 1;
      totalRevenue += price;
      if (meta.payload.codConfirmed) {
        codCollected += price;
      }
    } else if (
      meta.statusKey === 'delivering' ||
      ['accepted', 'picked_up', 'on_way', 'waiting'].includes(meta.deliveryStatusKey)
    ) {
      deliveringOrders += 1;
    } else if (
      meta.statusKey === 'cancelled' ||
      meta.statusKey === 'rejected' ||
      meta.statusKey === 'failed'
    ) {
      cancelledOrders += 1;
    } else {
      pendingOrders += 1;
    }

    return {
      id: meta.id,
      orderNumber: meta.payload.orderNumber || meta.id,
      statusKey: meta.statusKey,
      statusAr: meta.payload.statusAr || '',
      statusEn: meta.payload.statusEn || '',
      deliveryStatusKey: meta.deliveryStatusKey,
      deliveryStatusAr: meta.payload.deliveryStatusAr || '',
      deliveryStatusEn: meta.payload.deliveryStatusEn || '',
      price,
      customerName: meta.payload.customerNameAr || meta.payload.customerNameEn || '',
      customerPhone: meta.customerPhone,
      itemCount: Array.isArray(meta.payload.items)
        ? meta.payload.items.length
        : Number(meta.payload.itemsCount || 0),
      updatedAt: row.updated_at || row.created_at || null,
      createdAt: row.created_at || null,
    };
  });

  const totalOrders = orders.length;
  const averageOrderValue = completedOrders > 0 ? Math.round(totalRevenue / completedOrders) : 0;

  return {
    merchant: {
      phone: profile.phone,
      storeName: profile.store_name || '',
      description: profile.description || '',
      primaryServiceId: profile.primary_service_id || '',
      serviceIds: profileServiceIds(profile),
      isOpen: profile.is_open !== false,
      isFrozen: isMerchantFrozen(profile),
      isBazaarMember: profile.is_bazaar_member === true,
      rating: Number(profile.rating || 0),
      address: profile.address || '',
      deliveryFee: Number(profile.delivery_fee || 0),
      createdAt: profile.created_at || null,
      updatedAt: profile.updated_at || null,
      fullName: appUser?.full_name || '',
      role: appUser?.role || '',
    },
    stats: {
      totalOrders,
      completedOrders,
      pendingOrders,
      deliveringOrders,
      cancelledOrders,
      totalRevenue,
      codCollected,
      averageOrderValue,
      totalProducts: products.length,
    },
    recentOrders: mappedOrders.slice(0, 20),
    products: products.slice(0, 12).map((product) => ({
      id: String(product.id || ''),
      name: product.name || '',
      category: product.category || '',
      subCategory: product.sub_category || '',
      price: Number(product.price || 0),
      isAvailable: product.is_available !== false,
      createdAt: product.created_at || null,
    })),
  };
}

async function toggleBazaarMemberStatus(adminPhone, merchantPhone, isBazaarMember) {
  await assertAdminAccess(adminPhone);

  const supabase = assertSupabaseAdmin();
  const variants = getPhoneVariants(merchantPhone);

  const { data, error } = await supabase
    .from('merchant_profiles')
    .update({ is_bazaar_member: Boolean(isBazaarMember), updated_at: nowIso() })
    .in('phone', variants)
    .select();

  if (error) throw new Error(error.message);
  if (!Array.isArray(data) || data.length === 0) {
    throw new Error('Merchant not found.');
  }

  const result = { success: true, merchant: data[0] };
  if (Boolean(isBazaarMember)) {
    result.bazaarProductSync = await syncMerchantProductsForBazaar(merchantPhone);
  }
  return result;
}

async function toggleCourierApprovalStatus(adminPhone, courierPhone, isApproved) {
  await assertAdminAccess(adminPhone);

  const phoneKey = await resolvePhoneKey(courierPhone);
  const state = (await getUserState(phoneKey)) || {};
  const profile = readCourierProfileFromState(state);
  if (!profile || !isCourierProfileComplete(profile)) {
    throw new Error('Courier profile not found.');
  }

  const nextProfile = {
    ...profile,
    isApproved: Boolean(isApproved),
    approvalStatus: Boolean(isApproved) ? 'approved' : 'pending',
  };
  if (Boolean(isApproved)) {
    delete nextProfile.rejectionReasonKey;
    delete nextProfile.rejectionMessageAr;
    delete nextProfile.rejectedAt;
  }
  await saveUserState(phoneKey, {
    ...state,
    courierProfile: nextProfile,
  });

  const user = await getAppUser(phoneKey);
  const mapped = mapCourierForAdmin(phoneKey, user, nextProfile);

  if (Boolean(isApproved)) {
    try {
      const { onCourierApproved } = require('./push_events');
      await onCourierApproved(phoneKey);
    } catch (error) {
      console.error('push onCourierApproved error:', error?.message || error);
    }
  }

  return { success: true, courier: mapped };
}

function resolveRejectionMessage(reasonKey, rejectionMessageAr, catalog = {}) {
  const custom = String(rejectionMessageAr || '').trim();
  if (custom) {
    return {
      message: custom,
      key: String(reasonKey || 'custom').trim() || 'custom',
    };
  }
  const normalizedReason = String(reasonKey || '').trim();
  const message = catalog[normalizedReason];
  if (!message) return null;
  return { message, key: normalizedReason };
}

async function rejectCourierApplication(
  adminPhone,
  courierPhone,
  reasonKey = '',
  rejectionMessageAr = ''
) {
  await assertAdminAccess(adminPhone);

  const resolved = resolveRejectionMessage(
    reasonKey,
    rejectionMessageAr,
    COURIER_REJECTION_REASONS
  );
  if (!resolved) {
    throw new Error('Rejection reason is required.');
  }
  const { message, key: normalizedReason } = resolved;

  const phoneKey = await resolvePhoneKey(courierPhone);
  const state = (await getUserState(phoneKey)) || {};
  const profile = readCourierProfileFromState(state);
  if (!profile || !isCourierProfileComplete(profile)) {
    throw new Error('Courier profile not found.');
  }

  const nextProfile = {
    ...profile,
    isApproved: false,
    approvalStatus: 'rejected',
    rejectionReasonKey: normalizedReason,
    rejectionMessageAr: message,
    rejectedAt: nowIso(),
  };
  await saveUserState(phoneKey, {
    ...state,
    courierProfile: nextProfile,
  });

  const user = await getAppUser(phoneKey);
  const mapped = mapCourierForAdmin(phoneKey, user, nextProfile);

  try {
    const { onCourierRejected } = require('./push_events');
    await onCourierRejected(phoneKey, message, normalizedReason);
  } catch (error) {
    console.error('push onCourierRejected error:', error?.message || error);
  }

  return { success: true, courier: mapped };
}

async function toggleMerchantApprovalStatus(adminPhone, merchantPhone, isApproved) {
  await assertAdminAccess(adminPhone);

  const phoneKey = await resolvePhoneKey(merchantPhone);
  const profile = await getMerchantProfile(phoneKey);
  if (!profile || !merchantProfileDisplayName(profile)) {
    throw new Error('Merchant profile not found.');
  }

  const patch = {
    isApproved: Boolean(isApproved),
    approvalStatus: Boolean(isApproved) ? 'approved' : 'pending',
    rejectionReasonKey: null,
    rejectionMessageAr: null,
    rejectedAt: null,
  };
  await updateMerchantApprovalRecord(phoneKey, patch);

  if (Boolean(isApproved)) {
    try {
      const { onMerchantApproved } = require('./push_events');
      await onMerchantApproved(phoneKey);
    } catch (error) {
      console.error('push onMerchantApproved error:', error?.message || error);
    }
  }

  const refreshed = await getMerchantProfile(phoneKey);
  return {
    success: true,
    merchant: {
      phone: phoneKey,
      storeName: refreshed?.store_name || '',
      ...mapMerchantApprovalFields(refreshed || {}),
    },
  };
}

async function rejectMerchantApplication(
  adminPhone,
  merchantPhone,
  reasonKey = '',
  rejectionMessageAr = ''
) {
  await assertAdminAccess(adminPhone);

  const resolved = resolveRejectionMessage(
    reasonKey,
    rejectionMessageAr,
    MERCHANT_REJECTION_REASONS
  );
  if (!resolved) {
    throw new Error('Rejection reason is required.');
  }
  const { message, key: normalizedReason } = resolved;

  const phoneKey = await resolvePhoneKey(merchantPhone);
  const profile = await getMerchantProfile(phoneKey);
  if (!profile || !merchantProfileDisplayName(profile)) {
    throw new Error('Merchant profile not found.');
  }

  await updateMerchantApprovalRecord(phoneKey, {
    isApproved: false,
    approvalStatus: 'rejected',
    rejectionReasonKey: normalizedReason,
    rejectionMessageAr: message,
    rejectedAt: nowIso(),
  });

  try {
    const { onMerchantRejected } = require('./push_events');
    await onMerchantRejected(phoneKey, message, normalizedReason);
  } catch (error) {
    console.error('push onMerchantRejected error:', error?.message || error);
  }

  const refreshed = await getMerchantProfile(phoneKey);
  return {
    success: true,
    merchant: {
      phone: phoneKey,
      storeName: refreshed?.store_name || '',
      ...mapMerchantApprovalFields(refreshed || {}),
    },
  };
}

async function toggleMerchantFreezeStatus(adminPhone, merchantPhone, isFrozen) {
  await assertAdminAccess(adminPhone);

  const supabase = assertSupabaseAdmin();
  const variants = getPhoneVariants(merchantPhone);

  const { data, error } = await supabase
    .from('merchant_profiles')
    .update({ is_frozen: Boolean(isFrozen), updated_at: nowIso() })
    .in('phone', variants)
    .select();

  if (error) throw new Error(error.message);
  if (!Array.isArray(data) || data.length === 0) {
    throw new Error('Merchant not found.');
  }

  try {
    const { onMerchantFrozen } = require('./push_events');
    await onMerchantFrozen(merchantPhone, Boolean(isFrozen));
  } catch (error) {
    console.error('push onMerchantFrozen error:', error?.message || error);
  }

  return { success: true, merchant: data[0] };
}

async function isProtectedAdminAccount(phone) {
  const phoneKey = await resolvePhoneKey(phone);
  const variants = getPhoneVariants(phoneKey);
  const adminPhones = await getConfiguredAdminPhones();
  if (variants.some((item) => adminPhones.has(item))) {
    return true;
  }
  const user = await getAppUser(phoneKey);
  if (String(user?.role ?? '').trim() === 'admin') {
    return true;
  }
  const state = await getUserState(phoneKey);
  if (state?.adminAccess === true) {
    return true;
  }
  const role = String(state?.userRole ?? state?.user_role ?? '').trim();
  return role === 'admin';
}

function readDriverProfileFromState(state) {
  if (!state || typeof state !== 'object') return null;
  const profile = state.driverProfile;
  if (!profile || typeof profile !== 'object') return null;
  return profile;
}

function isDriverProfileComplete(profile) {
  if (!profile || typeof profile !== 'object') return false;
  const name = String(profile.name ?? '').trim();
  const phone = String(profile.phone ?? '').trim();
  const vehicle = String(profile.vehicle ?? '').trim();
  const plate = String(profile.plate ?? '').trim();
  const area = String(profile.area ?? '').trim();
  return Boolean(name && phone && vehicle && plate && area);
}

function isDriverApproved(profile) {
  return profile?.isApproved === true;
}

function driverApprovalStatus(profile) {
  if (!profile || typeof profile !== 'object') return 'pending';
  if (isDriverApproved(profile)) return 'approved';
  if (String(profile.approvalStatus ?? '').trim() === 'rejected') return 'rejected';
  return 'pending';
}

function driverRejectionMessage(profile) {
  return String(profile?.rejectionMessageAr ?? '').trim();
}

function resolveAccountApproval(state, merchantProfile, kind) {
  if (kind === 'customer' || kind === 'admin') {
    return {
      needsApproval: false,
      approvalStatus: null,
      isApproved: true,
      rejectionMessageAr: null,
    };
  }
  if (kind === 'merchant') {
    const profile = merchantProfile || {};
    return {
      needsApproval: true,
      approvalStatus: merchantApprovalStatus(profile),
      isApproved: isMerchantApproved(profile),
      rejectionMessageAr: merchantRejectionMessage(profile) || null,
    };
  }
  if (kind === 'courier') {
    const profile = readCourierProfileFromState(state);
    return {
      needsApproval: true,
      approvalStatus: courierApprovalStatus(profile),
      isApproved: isCourierApproved(profile),
      rejectionMessageAr: courierRejectionMessage(profile) || null,
    };
  }
  if (kind === 'driver') {
    const profile = readDriverProfileFromState(state);
    return {
      needsApproval: true,
      approvalStatus: driverApprovalStatus(profile),
      isApproved: isDriverApproved(profile),
      rejectionMessageAr: driverRejectionMessage(profile) || null,
    };
  }
  return {
    needsApproval: false,
    approvalStatus: null,
    isApproved: true,
    rejectionMessageAr: null,
  };
}

async function toggleDriverApprovalStatus(adminPhone, driverPhone, isApproved) {
  await assertAdminAccess(adminPhone);

  const phoneKey = await resolvePhoneKey(driverPhone);
  const state = (await getUserState(phoneKey)) || {};
  const profile = readDriverProfileFromState(state);
  if (!profile || !isDriverProfileComplete(profile)) {
    throw new Error('Driver profile not found.');
  }

  const nextProfile = {
    ...profile,
    isApproved: Boolean(isApproved),
    approvalStatus: Boolean(isApproved) ? 'approved' : 'pending',
  };
  if (Boolean(isApproved)) {
    delete nextProfile.rejectionReasonKey;
    delete nextProfile.rejectionMessageAr;
    delete nextProfile.rejectedAt;
  }
  await saveUserState(phoneKey, {
    ...state,
    driverProfile: nextProfile,
  });

  const user = await getAppUser(phoneKey);
  const refreshedState = (await getUserState(phoneKey)) || {};
  const mapped = mapAdminAccountSummary(user, refreshedState, null);

  if (Boolean(isApproved)) {
    try {
      const { onDriverApproved } = require('./push_events');
      await onDriverApproved(phoneKey);
    } catch (error) {
      console.error('push onDriverApproved error:', error?.message || error);
    }
  }

  return { success: true, driver: mapped };
}

async function rejectDriverApplication(
  adminPhone,
  driverPhone,
  reasonKey = '',
  rejectionMessageAr = ''
) {
  await assertAdminAccess(adminPhone);

  const resolved = resolveRejectionMessage(reasonKey, rejectionMessageAr, {});
  if (!resolved) {
    throw new Error('Rejection reason is required.');
  }
  const { message, key: normalizedReason } = resolved;

  const phoneKey = await resolvePhoneKey(driverPhone);
  const state = (await getUserState(phoneKey)) || {};
  const profile = readDriverProfileFromState(state);
  if (!profile || !isDriverProfileComplete(profile)) {
    throw new Error('Driver profile not found.');
  }

  const nextProfile = {
    ...profile,
    isApproved: false,
    approvalStatus: 'rejected',
    rejectionReasonKey: normalizedReason,
    rejectionMessageAr: message,
    rejectedAt: nowIso(),
  };
  await saveUserState(phoneKey, {
    ...state,
    driverProfile: nextProfile,
  });

  const user = await getAppUser(phoneKey);
  const refreshedState = (await getUserState(phoneKey)) || {};
  const mapped = mapAdminAccountSummary(user, refreshedState, null);

  try {
    const { onDriverRejected } = require('./push_events');
    await onDriverRejected(phoneKey, message, normalizedReason);
  } catch (error) {
    console.error('push onDriverRejected error:', error?.message || error);
  }

  return { success: true, driver: mapped };
}

function classifyAdminAccountKind(user, state, merchantProfile) {
  const role = String(user?.role ?? '').trim();
  const accountType = String(user?.account_type ?? '').trim();

  if (role === 'admin' || state?.adminAccess === true) {
    return 'admin';
  }

  const storeName = String(merchantProfile?.store_name ?? '').trim();
  const merchantStoreName = String(state?.merchantStore?.name ?? '').trim();
  const professionalInfo = normalizeObject(merchantProfile?.professional_info);
  const hasProfessionalProfile =
    Boolean(String(professionalInfo.name ?? '').trim()) ||
    Boolean(String(merchantProfile?.professional_category_id ?? '').trim()) ||
    isProfessionalMerchantProfile(merchantProfile);
  if (role === 'merchant' || storeName || merchantStoreName || hasProfessionalProfile) {
    return 'merchant';
  }

  const driverProfile = readDriverProfileFromState(state);
  if (
    role === 'driver' ||
    accountType === 'driver' ||
    (driverProfile && Object.keys(driverProfile).length > 0)
  ) {
    return 'driver';
  }

  const courierProfile = readCourierProfileFromState(state);
  if (
    role === 'delivery' ||
    accountType === 'delivery' ||
    isCourierProfileComplete(courierProfile)
  ) {
    return 'courier';
  }

  return 'customer';
}

function accountDisplayName(user, state, merchantProfile, kind) {
  const fullName = String(user?.full_name ?? '').trim();
  const merchantName = String(merchantProfile?.store_name ?? '').trim();
  const merchantStoreName = String(state?.merchantStore?.name ?? '').trim();
  const courierName = String(readCourierProfileFromState(state)?.name ?? '').trim();
  const driverName = String(readDriverProfileFromState(state)?.name ?? '').trim();
  const professionalName = String(
    normalizeObject(merchantProfile?.professional_info)?.name ?? ''
  ).trim();

  if (kind === 'merchant') {
    return merchantName || merchantStoreName || professionalName || fullName || 'تاجر';
  }
  if (kind === 'courier') {
    return courierName || fullName || 'مندوب توصيل';
  }
  if (kind === 'driver') {
    return driverName || fullName || 'سائق تكسي';
  }
  if (kind === 'admin') {
    return fullName || 'مشرف';
  }
  return fullName || 'زبون';
}

function resolveAccountSuspended(state, merchantProfile) {
  if (state?.accountSuspended === true) return true;
  if (isMerchantFrozen(merchantProfile)) return true;
  const courierProfile = readCourierProfileFromState(state);
  if (courierProfile?.isSuspended === true) return true;
  const driverProfile = readDriverProfileFromState(state);
  if (driverProfile?.isSuspended === true) return true;
  return false;
}

function mapAdminAccountSummary(user, state, merchantProfile) {
  const phone = String(user?.phone ?? '').trim();
  const kind = classifyAdminAccountKind(user, state, merchantProfile);
  const courierProfile = readCourierProfileFromState(state);
  const driverProfile = readDriverProfileFromState(state);
  const approval = resolveAccountApproval(state, merchantProfile, kind);

  return {
    phone,
    displayName: accountDisplayName(user, state, merchantProfile, kind),
    fullName: String(user?.full_name ?? '').trim(),
    role: String(user?.role ?? '').trim(),
    accountType: String(user?.account_type ?? '').trim(),
    kind,
    isSuspended: resolveAccountSuspended(state, merchantProfile),
    merchantStoreName: String(merchantProfile?.store_name ?? '').trim(),
    primaryServiceId: String(merchantProfile?.primary_service_id ?? '').trim(),
    courierApproved: isCourierApproved(courierProfile),
    needsApproval: approval.needsApproval,
    approvalStatus: approval.approvalStatus,
    isApproved: approval.isApproved,
    rejectionMessageAr: approval.rejectionMessageAr,
    updatedAt: user?.updated_at ?? merchantProfile?.updated_at ?? null,
    createdAt: user?.created_at ?? merchantProfile?.created_at ?? null,
    hasMerchantProfile: Boolean(merchantProfile),
    hasCourierProfile: isCourierProfileComplete(courierProfile),
    hasDriverProfile: isDriverProfileComplete(driverProfile),
  };
}

async function getAllAdminAccounts(adminPhone) {
  await assertAdminAccess(adminPhone);

  const [users, states, merchants] = await Promise.all([
    selectMany('app_users', [], { column: 'updated_at', ascending: false }),
    selectMany('app_state', [], { column: 'updated_at', ascending: false }),
    selectMany('merchant_profiles', []),
  ]);

  const stateByPhone = {};
  for (const row of states) {
    const phone = String(row.phone || '').trim();
    if (!phone) continue;
    stateByPhone[phone] = row.state || {};
  }

  const merchantByPhone = {};
  for (const row of merchants) {
    const phone = String(row.phone || '').trim();
    if (!phone) continue;
    merchantByPhone[phone] = row;
  }

  const accounts = users
    .map((user) => {
      const phone = String(user.phone || '').trim();
      if (!phone) return null;
      const state = stateByPhone[phone] || {};
      const merchantProfile = merchantByPhone[phone] || null;
      return mapAdminAccountSummary(user, state, merchantProfile);
    })
    .filter(Boolean);

  const kindRank = {
    admin: 0,
    merchant: 1,
    courier: 2,
    driver: 3,
    customer: 4,
  };

  return accounts.sort((a, b) => {
    const rankDiff = (kindRank[a.kind] ?? 9) - (kindRank[b.kind] ?? 9);
    if (rankDiff !== 0) return rankDiff;
    if (a.isSuspended !== b.isSuspended) {
      return a.isSuspended ? -1 : 1;
    }
    return String(a.displayName || '').localeCompare(String(b.displayName || ''), 'ar');
  });
}

async function deleteAllCustomerAddressesForPhone(phone) {
  const phoneKey = await resolvePhoneKey(phone);
  const supabase = assertSupabaseAdmin();
  const variants = getPhoneVariants(phoneKey);
  if (variants.length === 0) return;

  if (await hasColumn('customer_addresses', 'phone')) {
    const { error } = await supabase
      .from('customer_addresses')
      .delete()
      .in('phone', variants);
    if (error && !/does not exist/i.test(error.message || '')) {
      throw new Error(error.message);
    }
    return;
  }

  const userId = await getAppUserId(phoneKey);
  if (!userId) return;
  const { error } = await supabase
    .from('customer_addresses')
    .delete()
    .eq('user_id', userId);
  if (error && !/does not exist/i.test(error.message || '')) {
    throw new Error(error.message);
  }
}

async function purgeAccountData(phone) {
  const phoneKey = await resolvePhoneKey(phone);
  const supabase = assertSupabaseAdmin();
  const variants = getPhoneVariants(phoneKey);

  if (variants.length > 0) {
    const { error: productsError } = await supabase
      .from('merchant_products')
      .delete()
      .in('phone', variants);
    if (productsError && !/does not exist/i.test(productsError.message || '')) {
      throw new Error(productsError.message);
    }

    if (await hasColumn('customer_favorites', 'phone')) {
      const { error: favoritesError } = await supabase
        .from('customer_favorites')
        .delete()
        .in('phone', variants);
      if (favoritesError && !/does not exist/i.test(favoritesError.message || '')) {
        console.warn('purgeAccountData favorites cleanup:', favoritesError.message);
      }
    }
  }

  try {
    await deleteMerchantProfile(phoneKey);
  } catch (error) {
    if (!/not found|No rows/i.test(String(error?.message || ''))) {
      console.warn('purgeAccountData merchant profile:', error?.message || error);
    }
  }

  try {
    await deleteCustomerProfile(phoneKey);
  } catch (error) {
    if (!/not found|No rows/i.test(String(error?.message || ''))) {
      console.warn('purgeAccountData customer profile:', error?.message || error);
    }
  }

  try {
    await deleteAllCustomerAddressesForPhone(phoneKey);
  } catch (error) {
    console.warn('purgeAccountData customer addresses:', error?.message || error);
  }

  try {
    await deleteUserState(phoneKey);
  } catch (error) {
    console.warn('purgeAccountData user state:', error?.message || error);
  }

  try {
    await deleteAllDeviceTokens(phoneKey);
  } catch (error) {
    console.warn('purgeAccountData device tokens:', error?.message || error);
  }

  await deleteAppUser(phoneKey);
  return { success: true, phone: phoneKey };
}

async function adminDeleteAccount(adminPhone, targetPhone) {
  await assertAdminAccess(adminPhone);

  const phoneKey = await resolvePhoneKey(targetPhone);
  if (!phoneKey) {
    throw new Error('Account phone is required.');
  }

  const adminKey = await resolvePhoneKey(adminPhone);
  if (getPhoneVariants(adminKey).some((item) => getPhoneVariants(phoneKey).includes(item))) {
    throw new Error('Cannot delete your own admin session account.');
  }

  if (await isProtectedAdminAccount(phoneKey)) {
    throw new Error('Cannot delete a protected admin account.');
  }

  const existing = await getAppUser(phoneKey);
  if (!existing) {
    throw new Error('Account not found.');
  }

  return purgeAccountData(phoneKey);
}

async function adminSuspendAccount(adminPhone, targetPhone, isSuspended) {
  await assertAdminAccess(adminPhone);

  const phoneKey = await resolvePhoneKey(targetPhone);
  if (!phoneKey) {
    throw new Error('Account phone is required.');
  }

  if (await isProtectedAdminAccount(phoneKey)) {
    throw new Error('Cannot suspend a protected admin account.');
  }

  const existing = await getAppUser(phoneKey);
  if (!existing) {
    throw new Error('Account not found.');
  }

  const state = (await getUserState(phoneKey)) || {};
  const merchantProfile = await getMerchantProfile(phoneKey);
  const courierProfile = readCourierProfileFromState(state);
  const driverProfile = readDriverProfileFromState(state);

  const nextState = {
    ...state,
    accountSuspended: Boolean(isSuspended),
    suspendedAt: isSuspended ? nowIso() : null,
  };

  if (courierProfile) {
    nextState.courierProfile = {
      ...courierProfile,
      isSuspended: Boolean(isSuspended),
      available: !isSuspended,
    };
  }

  if (driverProfile) {
    nextState.driverProfile = {
      ...driverProfile,
      isSuspended: Boolean(isSuspended),
      available: !isSuspended,
    };
  }

  await saveUserState(phoneKey, nextState);

  if (merchantProfile) {
    const supabase = assertSupabaseAdmin();
    const variants = getPhoneVariants(phoneKey);
    const { error } = await supabase
      .from('merchant_profiles')
      .update({ is_frozen: Boolean(isSuspended), updated_at: nowIso() })
      .in('phone', variants);
    if (error) throw new Error(error.message);
  }

  const refreshedState = (await getUserState(phoneKey)) || nextState;
  const refreshedMerchant = await getMerchantProfile(phoneKey);
  return {
    success: true,
    phone: phoneKey,
    isSuspended: resolveAccountSuspended(refreshedState, refreshedMerchant),
    account: mapAdminAccountSummary(existing, refreshedState, refreshedMerchant),
  };
}

const PLATFORM_SETTINGS_PHONE = '__platform_settings__';
const PLATFORM_ADMIN_PHONES = Object.freeze([
  '07744009992',
  '+9647744009992',
]);

function isPlatformAdminPhone(phone) {
  const allowed = new Set();
  for (const configured of PLATFORM_ADMIN_PHONES) {
    for (const variant of getPhoneVariants(configured)) {
      allowed.add(variant);
    }
  }
  for (const variant of getPhoneVariants(phone)) {
    if (allowed.has(variant)) return true;
  }
  return false;
}

async function ensurePlatformAdminAccess(phone) {
  if (!isPlatformAdminPhone(phone)) return false;
  const phoneKey = await resolvePhoneKey(phone);
  if (!phoneKey) return false;

  const existingUser = await getAppUser(phoneKey);
  const primaryRole =
    existingUser?.role === 'customer' || existingUser?.role === 'merchant'
      ? existingUser.role
      : 'customer';

  await ensureAppUser(phoneKey, {
    role: primaryRole,
    full_name: existingUser?.full_name || 'مدير المنصة',
    account_type: existingUser?.account_type || primaryRole,
  });

  const existingState = (await getUserState(phoneKey)) || {};
  if (existingState.adminAccess === true) return true;

  await saveUserState(phoneKey, {
    ...existingState,
    adminAccess: true,
    userRole: existingState.userRole || existingState.user_role || primaryRole,
  });
  return true;
}

const DEFAULT_APP_UPDATE_POLICY = {
  minBuildNumber: 41,
  minVersionName: '1.2.10',
  latestBuildNumber: 0,
  latestVersionName: '',
  messageAr:
    'يجب تحديث التطبيق للمتابعة. الرجاء التحديث من المتجر للاستمرار في استخدام الغيث.',
  androidStoreUrl:
    'https://play.google.com/store/apps/details?id=com.alghaith.app',
  iosStoreUrl: 'https://apps.apple.com/app/id6776741811',
};

function normalizeAppUpdatePolicy(raw = {}) {
  const minBuildNumber = Math.max(
    1,
    Number.parseInt(
      String(
        raw.minBuildNumber ??
          raw.min_build_number ??
          DEFAULT_APP_UPDATE_POLICY.minBuildNumber
      ),
      10
    ) || DEFAULT_APP_UPDATE_POLICY.minBuildNumber
  );
  const minVersionName = String(
    raw.minVersionName ??
      raw.min_version_name ??
      DEFAULT_APP_UPDATE_POLICY.minVersionName
  ).trim() || DEFAULT_APP_UPDATE_POLICY.minVersionName;
  const latestBuildNumber = Math.max(
    0,
    Number.parseInt(
      String(
        raw.latestBuildNumber ??
          raw.latest_build_number ??
          DEFAULT_APP_UPDATE_POLICY.latestBuildNumber
      ),
      10
    ) || 0
  );
  const latestVersionName = String(
    raw.latestVersionName ??
      raw.latest_version_name ??
      DEFAULT_APP_UPDATE_POLICY.latestVersionName
  ).trim();
  const messageAr = String(
    raw.messageAr ?? raw.message_ar ?? DEFAULT_APP_UPDATE_POLICY.messageAr
  ).trim() || DEFAULT_APP_UPDATE_POLICY.messageAr;
  const androidStoreUrl = String(
    raw.androidStoreUrl ??
      raw.android_store_url ??
      DEFAULT_APP_UPDATE_POLICY.androidStoreUrl
  ).trim() || DEFAULT_APP_UPDATE_POLICY.androidStoreUrl;
  const iosStoreUrl = String(
    raw.iosStoreUrl ??
      raw.ios_store_url ??
      DEFAULT_APP_UPDATE_POLICY.iosStoreUrl
  ).trim() || DEFAULT_APP_UPDATE_POLICY.iosStoreUrl;
  const updatedAt = String(raw.updatedAt ?? raw.updated_at ?? '').trim() || null;

  return {
    minBuildNumber,
    minVersionName,
    latestBuildNumber,
    latestVersionName,
    messageAr,
    androidStoreUrl,
    iosStoreUrl,
    updatedAt,
  };
}

async function loadRawAppUpdatePolicyState() {
  const state = await getUserState(PLATFORM_SETTINGS_PHONE);
  if (!state || typeof state !== 'object') return null;
  return state.appUpdatePolicy || state.app_update_policy || null;
}

async function getAppUpdatePolicy() {
  const saved = await loadRawAppUpdatePolicyState();
  return normalizeAppUpdatePolicy(saved || {});
}

async function saveAdminAppUpdatePolicy(adminPhone, patch = {}) {
  await assertAdminAccess(adminPhone);
  const current = await getAppUpdatePolicy();
  const next = normalizeAppUpdatePolicy({
    ...current,
    ...patch,
    updatedAt: nowIso(),
  });
  await ensureAppUser(PLATFORM_SETTINGS_PHONE, {
    role: 'system',
    full_name: 'Platform Settings',
    account_type: 'system',
  });
  const existingState = (await getUserState(PLATFORM_SETTINGS_PHONE)) || {};
  await saveUserState(PLATFORM_SETTINGS_PHONE, {
    ...existingState,
    appUpdatePolicy: next,
  });
  return next;
}

// ── إعداد أقسام الصفحة الرئيسية (يتحكّم فيه الأدمن عن بُعد) ──────────────
const HOME_CATEGORY_PLATFORMS = ['default', 'android', 'ios', 'web'];

function normalizeCategoryOverride(value) {
  if (value === true || value === false) {
    return { default: value };
  }
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }
  const out = {};
  for (const key of HOME_CATEGORY_PLATFORMS) {
    if (value[key] === true || value[key] === false) {
      out[key] = value[key];
    }
  }
  return out;
}

async function getHomeCategoriesConfig() {
  const state = await getUserState(PLATFORM_SETTINGS_PHONE);
  const raw =
    (state && (state.homeCategories || state.home_categories)) || null;
  const overrides = {};
  if (raw && typeof raw === 'object' && raw.overrides &&
      typeof raw.overrides === 'object') {
    for (const [key, value] of Object.entries(raw.overrides)) {
      const id = String(key).trim();
      if (!id) continue;
      const normalized = normalizeCategoryOverride(value);
      if (Object.keys(normalized).length > 0) {
        overrides[id] = normalized;
      }
    }
  }
  return {
    overrides,
    updatedAt: (raw && (raw.updatedAt || raw.updated_at)) || null,
  };
}

async function saveAdminHomeCategoriesConfig(adminPhone, overrides = {}) {
  await assertAdminAccess(adminPhone);
  const existingConfig = await getHomeCategoriesConfig();
  const merged = { ...(existingConfig.overrides || {}) };

  if (overrides && typeof overrides === 'object') {
    for (const [key, value] of Object.entries(overrides)) {
      const id = String(key).trim();
      if (!id) continue;
      const patch = normalizeCategoryOverride(value);
      if (Object.keys(patch).length === 0) {
        delete merged[id];
        continue;
      }
      merged[id] = {
        ...(merged[id] || {}),
        ...patch,
      };
    }
  }

  await ensureAppUser(PLATFORM_SETTINGS_PHONE, {
    role: 'system',
    full_name: 'Platform Settings',
    account_type: 'system',
  });
  const existingState = (await getUserState(PLATFORM_SETTINGS_PHONE)) || {};
  const next = { overrides: merged, updatedAt: nowIso() };
  await saveUserState(PLATFORM_SETTINGS_PHONE, {
    ...existingState,
    homeCategories: next,
  });
  return getHomeCategoriesConfig();
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
  listAllCustomerOrders,
  readOrderMeta,
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
  listServiceStores,
  listCatalogProducts,
  listOfferCatalogProducts,
  getMarketplaceStats,
  listRealEstateListings,
  getMerchantIncomingOrders,
  updateIncomingOrderStatus,
  getDeliveryPoolOrders,
  getCourierAssignedOrders,
  acceptDeliveryOrder,
  rejectDeliveryOrder,
  updateCourierDeliveryStatus,
  saveTaxiRequest,
  getCustomerTaxiRequests,
  getTaxiPoolOrders,
  getDriverTaxiOrders,
  acceptTaxiRequest,
  rejectTaxiRequest,
  updateTaxiRequestStatus,
  getActiveDriverPhones,
  getAdminReports,
  canonicalPhone,
  saveMerchantReview,
  getAllMerchants,
  getAllCouriers,
  toggleCourierApprovalStatus,
  rejectCourierApplication,
  toggleMerchantApprovalStatus,
  rejectMerchantApplication,
  toggleDriverApprovalStatus,
  rejectDriverApplication,
  getAdminMerchantDetails,
  toggleBazaarMemberStatus,
  toggleMerchantFreezeStatus,
  getAllAdminAccounts,
  adminDeleteAccount,
  adminSuspendAccount,
  syncMerchantProductsForBazaar,
  saveDeviceToken,
  deleteDeviceToken,
  deleteAllDeviceTokens,
  getDeviceTokensForPhone,
  removeDeviceTokens,
  getActiveCourierPhones,
  recordPushInboxDelivered,
  markPushInboxOpened,
  markPushInboxReminderSent,
  listPushInboxStatesNeedingReminder,
  getAppUpdatePolicy,
  saveAdminAppUpdatePolicy,
  getHomeCategoriesConfig,
  saveAdminHomeCategoriesConfig,
  ensurePlatformAdminAccess,
  isPlatformAdminPhone,
};
