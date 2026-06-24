const {
  nowIso,
  assignIfDefined,
  normalizeArray,
  normalizeObject,
  parseOptionalBoolean,
  isUuid,
  getPhoneVariants,
  phonesOverlap,
  canonicalPhone,
  selectSingleByPhone,
  resolvePhoneKey,
  selectSingle,
  selectMany,
  hasColumn,
  saveRow,
  deleteRow,
  assertSupabaseAdmin,
  getSupabaseAdmin,
} = require('./common');
const {
  ensureAppUser,
  getAppUser,
  getAppUserId,
  getUserState,
  saveUserState,
} = require('./users');

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

  // المهنيين الجدد يحتاجون موافقة، لكن إذا كان لديهم بيانات قديمة
  // نعتبرهم مفعّلين فقط إذا كان لديهم موافقة صريحة
  if (isProfessionalMerchantProfile(profile)) {
    const info = normalizeObject(profile.professional_info);
    return Boolean(String(info.name ?? '').trim()) &&
           (profile.is_approved === true || profile.isApproved === true);
  }

  return false;
}

function merchantApprovalStatus(profile) {
  if (isMerchantApproved(profile)) return 'approved';
  const status = String(profile.approval_status ?? profile.approvalStatus ?? '').trim();
  if (status === 'rejected') return 'rejected';
  if (status === 'pending') return 'pending';
  if (profile.is_approved === false || profile.isApproved === false) return 'pending';
  if (isProfessionalMerchantProfile(profile)) return 'pending';
  // إذا لم يُضبط approval_status مطلقاً، فهو معلق للموافقة (pending)
  return 'pending';
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

  // Try atomic RPC first
  try {
    const isReject = String(patch.approvalStatus || '').trim() === 'rejected';
    let rpcResult;
    if (isReject) {
      const { data, error } = await supabase.rpc('atomic_reject_merchant', {
        p_phone: phoneKey,
        p_reason_key: patch.rejectionReasonKey || patch.rejection_reason_key || null,
        p_message_ar: patch.rejectionMessageAr || patch.rejection_message_ar || null,
      });
      if (!error) rpcResult = data;
    } else if (patch.isApproved !== undefined || patch.is_approved !== undefined) {
      const { data, error } = await supabase.rpc('atomic_approve_merchant', {
        p_phone: phoneKey,
        p_approved: Boolean(patch.isApproved ?? patch.is_approved),
      });
      if (!error) rpcResult = data;
    }
    if (rpcResult) return { phone: phoneKey, ...patch, ...rpcResult };
  } catch (_) {
    // fallback to original multi-query approach
  }

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
    return { phone: phoneKey, ...patch, _columnMissing: true };
  }

  return Array.isArray(data) && data.length > 0 ? data[0] : null;
}

/** أقسام التسوق العالمي فقط — لا تُخلط مع التسوق المحلي. */
const GLOBAL_SHOPPING_SUB_CATEGORY_IDS = new Set(['iran', 'china']);

const SCHOOL_SUPPLIES_SUB_CATEGORY_IDS = new Set([
  'school_books_magazines',
  'school_pens',
  'school_notebooks',
  'school_colors',
  'school_erasers',
]);

const LEGACY_SCHOOL_SUB_CATEGORY_ALIASES = {
  books_magazines: 'school_books_magazines',
};

function normalizeShoppingSubCategoryId(sub) {
  const value = String(sub || '').trim();
  if (!value) return '';
  return LEGACY_SCHOOL_SUB_CATEGORY_ALIASES[value] || value;
}

function shoppingSubCategoryMatches(productSub, filterSub) {
  const filter = normalizeShoppingSubCategoryId(filterSub);
  if (!filter) return true;
  const product = normalizeShoppingSubCategoryId(productSub);
  if (product === filter) return true;
  const rawProduct = String(productSub || '').trim();
  if (rawProduct === 'school' && filter.startsWith('school_')) return true;
  return false;
}

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
    if (target) return shoppingSubCategoryMatches(sub, target);
    return true;
  }

  if (channel === 'product' || channel === '') {
    if (GLOBAL_SHOPPING_SUB_CATEGORY_IDS.has(sub)) return false;
    if (target) return shoppingSubCategoryMatches(sub, target);
    return true;
  }

  if (target) return shoppingSubCategoryMatches(sub, target);
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

function readServiceEnabledMap(profile) {
  const raw =
    profile?.service_enabled ??
    profile?.serviceEnabled ??
    profile?.store_data?.service_enabled ??
    profile?.store_data?.serviceEnabled ??
    null;
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return {};
  return raw;
}

function isMerchantServiceEnabled(profile, serviceId) {
  const id = String(serviceId || '').trim();
  if (!id) return true;
  const map = readServiceEnabledMap(profile);
  if (Object.prototype.hasOwnProperty.call(map, id)) {
    return map[id] !== false;
  }
  return true;
}

function merchantQualifiesForServiceListing(profile, serviceId) {
  const normalizedServiceId = String(serviceId || '').trim();
  if (normalizedServiceId === 'bazar_ghaith') {
    if (!canMerchantPublishInBazaar(profile)) return false;
    const services = profileServiceIds(profile);
    const hasRestaurant =
      services.includes('restaurant') &&
      isMerchantServiceEnabled(profile, 'restaurant');
    const hasProduct =
      services.includes('product') &&
      isMerchantServiceEnabled(profile, 'product');
    return hasRestaurant || hasProduct;
  }
  if (!profileHasService(profile, normalizedServiceId)) return false;
  return isMerchantServiceEnabled(profile, normalizedServiceId);
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

function merchantProfileSections(profile) {
  return normalizeArray(profile?.product_sections ?? profile?.productSections);
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
  if (await hasColumn('merchant_profiles', 'service_enabled')) {
    if (data.service_enabled !== undefined || data.serviceEnabled !== undefined) {
      basePayload.service_enabled = normalizeObject(
        data.service_enabled ?? data.serviceEnabled
      );
    }
  } else {
    const storeData = normalizeObject(basePayload.store_data);
    if (data.service_enabled !== undefined || data.serviceEnabled !== undefined) {
      storeData.serviceEnabled = normalizeObject(
        data.service_enabled ?? data.serviceEnabled
      );
      basePayload.store_data = storeData;
    }
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
  if (await hasColumn('merchant_profiles', 'service_sub_category')) {
    assignIfDefined(
      basePayload,
      'service_sub_category',
      data.service_sub_category ?? data.serviceSubCategory
    );
  } else {
    // تخزين serviceSubCategory في store_data كحل بديل إذا لم يكن العمود موجوداً
    const storeData = normalizeObject(basePayload.store_data);
    if (data.serviceSubCategory || data.service_sub_category) {
      storeData.serviceSubCategory = data.serviceSubCategory ?? data.service_sub_category;
      basePayload.store_data = storeData;
    }
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
    const incomingStoreName = String(
      basePayload.store_name ?? data.store_name ?? data.storeName ?? ''
    ).trim();
    if (!incomingStoreName) {
      basePayload.store_name =
        String(appUser?.full_name ?? data.full_name ?? data.fullName ?? '').trim() ||
        `تاجر ${phoneKey.slice(-4)}`;
    }
  }
  return saveRow('merchant_profiles', { ...basePayload, phone: phoneKey }, 'phone');
}

async function deleteMerchantProfile(phone) {
  return deleteRow('merchant_profiles', 'phone', phone);
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
  // إذا لم يعدل التاجر اسم المتجر بعد، نأخذه من البيانات الواردة (للمهنيين بشكل خاص)
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
  if (await hasColumn('merchant_products', 'neighborhood')) {
    assignIfDefined(payload, 'neighborhood', data.neighborhood);
  }
  if (await hasColumn('merchant_products', 'facade')) {
    assignIfDefined(payload, 'facade', data.facade);
  }
  if (await hasColumn('merchant_products', 'gallery_images_base64')) {
    if (data.gallery_images_base64 !== undefined || data.galleryImagesBase64 !== undefined) {
      const raw = data.gallery_images_base64 ?? data.galleryImagesBase64;
      payload.gallery_images_base64 = Array.isArray(raw)
        ? raw.map((entry) => String(entry || '').trim()).filter(Boolean)
        : normalizeArray(raw);
    }
  }
  if (data.prep_minutes !== undefined && data.prep_minutes !== null) {
    payload.prep_minutes = Number.parseInt(data.prep_minutes, 10);
  }
  if (data.is_available !== undefined) {
    payload.is_available = Boolean(data.is_available);
  }
  return saveRow('merchant_products', payload, 'id');
}

async function deleteMerchantProduct(id, phone) {
  const productId = String(id || '').trim();
  if (!productId) {
    throw new Error('Product id is required.');
  }

  const supabase = assertSupabaseAdmin();
  const phoneKey = phone ? await resolvePhoneKey(phone) : null;
  let query = supabase.from('merchant_products').delete().eq('id', productId);
  if (phoneKey) {
    query = query.eq('phone', phoneKey);
  }
  const { error } = await query;
  if (error) throw new Error(error.message);

  if (phoneKey) {
    await removeMerchantProductFromUserState(phoneKey, productId);
  }
}

async function removeMerchantProductFromUserState(phoneKey, productId) {
  const state = (await getUserState(phoneKey)) || {};
  const items = Array.isArray(state.items) ? state.items : [];
  const targetId = String(productId || '').trim();
  if (!targetId || items.length === 0) return;

  const filtered = items.filter(
    (item) => String(item?.id || '').trim() !== targetId
  );
  if (filtered.length === items.length) return;

  await saveUserState(phoneKey, { items: filtered });
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
      if (!isMerchantServiceEnabled(row, 'professionals')) return false;
      if (!target) return true;
      const categoryId = String(row.professional_category_id || '').trim();
      return categoryId === target;
    })
    .map((row) => enrichProfessionalProfileRow(row));
}

// الخدمات التي تعتمد على التواصل المباشر دون منتجات (جمال، مهنيون، إلخ)
const CONTACT_ONLY_SERVICES = new Set(['beauty', 'professionals', 'tourism']);

async function listMerchantStoresByService({
  serviceId,
  productCategory,
  subCategoryId = '',
  marketplaceCategory = '',
}) {
  const profiles = await selectMany('merchant_profiles');
  const normalizedServiceId = String(serviceId || '').trim();
  const channel = String(marketplaceCategory || '').trim();
  const normalizedSubCategoryId = String(subCategoryId || '').trim();
  const isContactOnly = CONTACT_ONLY_SERVICES.has(normalizedServiceId);
  const result = [];

  for (const profile of profiles) {
    const isOpen = profile.is_open !== false;
    if (!isOpen) continue;
    if (isMerchantFrozen(profile)) continue;
    if (!isMerchantApproved(profile)) continue;
    if (!merchantQualifiesForServiceListing(profile, normalizedServiceId)) {
      continue;
    }

    // تصفية حسب serviceSubCategory إذا كان محدداً
    if (normalizedSubCategoryId) {
      const profileSubCat = String(
        profile.service_sub_category ||
        (profile.store_data && profile.store_data.serviceSubCategory) ||
        ''
      ).trim();
      if (profileSubCat && profileSubCat !== normalizedSubCategoryId) continue;
    }

    // خدمات التواصل المباشر: تظهر بدون منتجات
    if (isContactOnly) {
      result.push({
        profile: withMerchantCustomerContacts(profile),
        products: [],
      });
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
        subCategoryId: normalizedSubCategoryId,
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

      const productService = String(
        row.category || row.service_id || ''
      ).trim();
      if (
        productService &&
        !isMerchantServiceEnabled(profile, productService)
      ) {
        return false;
      }

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
      if (target && !shoppingSubCategoryMatches(row.sub_category, target)) {
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
    .filter(({ merchant }) => merchant && merchant.is_open !== false && !isMerchantFrozen(merchant))
    .filter(({ merchant, product }) => {
      const productService = String(
        product.category || product.service_id || 'real_estate'
      ).trim();
      return isMerchantServiceEnabled(merchant, productService || 'real_estate');
    });
}

function merchantProfilePayloadFromAppState(state, appUser) {
  const merchantStore = normalizeObject(state?.merchantStore);
  const storeName =
    String(merchantStore.name ?? merchantStore.store_name ?? '').trim() ||
    String(appUser?.full_name ?? '').trim();
  if (!storeName) return null;

  const serviceIds = normalizeArray(
    merchantStore.serviceIds ?? merchantStore.service_ids
  );
  const category =
    String(
      merchantStore.category ??
        merchantStore.activeServiceId ??
        merchantStore.active_service_id ??
        merchantStore.primary_service_id ??
        merchantStore.primaryServiceId ??
        ''
    ).trim() || (serviceIds[0] || 'product');

  return {
    store_name: storeName,
    description: merchantStore.description,
    primary_service_id: category,
    service_ids: serviceIds.length > 0 ? serviceIds : [category],
    active_service_id:
      merchantStore.activeServiceId ?? merchantStore.active_service_id ?? category,
    whatsapp: merchantStore.whatsapp,
    address: merchantStore.address,
    latitude: merchantStore.latitude ?? merchantStore.lat,
    longitude: merchantStore.longitude ?? merchantStore.lng,
    open_time: merchantStore.openTime ?? merchantStore.open_time,
    close_time: merchantStore.closeTime ?? merchantStore.close_time,
    delivery_fee: merchantStore.deliveryFee ?? merchantStore.delivery_fee,
    delivery_areas: merchantStore.deliveryAreas ?? merchantStore.delivery_areas,
    is_open: merchantStore.isOpen ?? merchantStore.is_open ?? true,
    service_enabled: normalizeObject(
      merchantStore.service_enabled ?? merchantStore.serviceEnabled ?? {}
    ),
    restaurant_category:
      merchantStore.restaurantCategory ?? merchantStore.restaurant_category,
    service_sub_category:
      merchantStore.serviceSubCategory ?? merchantStore.service_sub_category,
    professional_category_id:
      merchantStore.professionalCategoryId ??
      merchantStore.professional_category_id,
    professional_info:
      merchantStore.professionalInfo ?? merchantStore.professional_info,
    profile_image_base64:
      merchantStore.profileImageBase64 ?? merchantStore.profile_image_base64,
    cover_image_url:
      merchantStore.coverImageBase64 ??
      merchantStore.coverImage ??
      merchantStore.cover_image_url,
    logo_image_url:
      merchantStore.logoImageBase64 ??
      merchantStore.logoImage ??
      merchantStore.logo_image_url,
    work_sample_images_base64:
      merchantStore.workSampleImagesBase64 ??
      merchantStore.work_sample_images_base64,
    product_sections:
      merchantStore.productSections ?? merchantStore.product_sections,
    is_approved: false,
    approval_status: 'pending',
  };
}

function resolveStateForPhone(stateByPhone, phone) {
  for (const variant of getPhoneVariants(phone)) {
    const state = stateByPhone[variant];
    if (state && typeof state === 'object') return state;
  }
  return {};
}

async function ensureMerchantProfileRecord(phone, options = {}) {
  const phoneKey = await resolvePhoneKey(phone);
  let profile = await getMerchantProfile(phoneKey);
  if (profile) return profile;

  const appUser = await getAppUser(phoneKey);
  const state = (await getUserState(phoneKey)) || {};
  const payload = merchantProfilePayloadFromAppState(state, appUser);
  const storeName =
    payload?.store_name ||
    String(appUser?.full_name ?? '').trim() ||
    `تاجر ${phoneKey.slice(-4)}`;

  profile = await saveMerchantProfile(phoneKey, {
    ...(payload || {}),
    store_name: storeName,
    primary_service_id: payload?.primary_service_id || 'product',
    is_approved: false,
    approval_status: 'pending',
    ...options,
  });

  if (!profile) {
    throw new Error('Merchant profile not found.');
  }
  return profile;
}

function hasMerchantDataInState(state) {
  const normalized = normalizeObject(state);
  if (normalized.merchantProfileComplete === true) return true;
  const store = normalizeObject(normalized.merchantStore);
  if (!store || Object.keys(store).length === 0) return false;
  const storeName = String(store.name ?? store.store_name ?? '').trim();
  return storeName.length > 0;
}

async function merchantProfileExistsForPhone(phone, existingPhones) {
  const phoneKey = String(phone || '').trim();
  if (!phoneKey) return true;
  if (getPhoneVariants(phoneKey).some((variant) => existingPhones.has(variant))) {
    return true;
  }
  const profile = await getMerchantProfile(phoneKey);
  return Boolean(profile);
}

async function createMerchantProfileIfMissing(phone, state, appUser, existingPhones) {
  const phoneKey = String(phone || '').trim();
  if (!phoneKey) return false;
  if (await merchantProfileExistsForPhone(phoneKey, existingPhones)) {
    return false;
  }

  const payload = merchantProfilePayloadFromAppState(state, appUser);
  const role = String(appUser?.role ?? '').trim();
  const isMerchantIntent =
    role === 'merchant' || payload !== null || hasMerchantDataInState(state);
  if (!isMerchantIntent) return false;

  const toSave =
    payload ||
    ({
      store_name:
        String(appUser?.full_name ?? '').trim() || `تاجر ${phoneKey.slice(-4)}`,
      primary_service_id: 'product',
      is_approved: false,
      approval_status: 'pending',
    });

  if (!String(toSave.store_name ?? '').trim()) return false;

  await saveMerchantProfile(phoneKey, toSave);
  for (const variant of getPhoneVariants(phoneKey)) {
    existingPhones.add(variant);
  }
  return true;
}

async function syncMissingMerchantProfilesFromAppState() {
  const [users, states, existingMerchants] = await Promise.all([
    selectMany('app_users', [], { column: 'updated_at', ascending: false }),
    selectMany('app_state', [], { column: 'updated_at', ascending: false }),
    selectMany('merchant_profiles', [], { column: 'phone', ascending: true }),
  ]);

  const existingPhones = new Set();
  for (const row of existingMerchants) {
    for (const variant of getPhoneVariants(row.phone)) {
      existingPhones.add(variant);
    }
  }

  const stateByPhone = {};
  for (const row of states) {
    const phone = String(row.phone || '').trim();
    if (!phone) continue;
    for (const variant of getPhoneVariants(phone)) {
      stateByPhone[variant] = row.state || {};
    }
  }

  let synced = 0;

  for (const user of users) {
    const phone = String(user.phone || '').trim();
    if (!phone) continue;
    const state = resolveStateForPhone(stateByPhone, phone);
    const created = await createMerchantProfileIfMissing(
      phone,
      state,
      user,
      existingPhones
    );
    if (created) synced += 1;
  }

  // تغطية حالات app_state التي لا يوجد لها صف مطابق في app_users
  const scannedStatePhones = new Set();
  for (const row of states) {
    const phone = String(row.phone || '').trim();
    if (!phone) continue;
    let alreadyScanned = false;
    for (const variant of getPhoneVariants(phone)) {
      if (scannedStatePhones.has(variant)) {
        alreadyScanned = true;
        break;
      }
    }
    if (alreadyScanned) continue;
    for (const variant of getPhoneVariants(phone)) {
      scannedStatePhones.add(variant);
    }

    const state = row.state || {};
    if (!hasMerchantDataInState(state)) continue;

    const appUser = await getAppUser(phone).catch(() => null);
    const created = await createMerchantProfileIfMissing(
      phone,
      state,
      appUser,
      existingPhones
    );
    if (created) synced += 1;
  }

  if (synced > 0) {
    console.log(`syncMissingMerchantProfiles: created ${synced} merchant profile(s).`);
  }
  return synced;
}

module.exports = {
  resolveMerchantContactVisibility,
  withMerchantCustomerContacts,
  profileServiceIds,
  isMerchantFrozen,
  isProfessionalMerchantProfile,
  merchantProfileDisplayName,
  isMerchantApproved,
  merchantApprovalStatus,
  merchantRejectionMessage,
  MERCHANT_REJECTION_REASONS,
  mapMerchantApprovalFields,
  syncMerchantApprovalToState,
  updateMerchantApprovalRecord,
  profileHasService,
  productMatchesStoreListing,
  buildProfileByPhoneMap,
  canMerchantPublishInBazaar,
  merchantQualifiesForServiceListing,
  isBazaarEligibleProductCategory,
  resolveListingProductService,
  evaluateBazaarCustomerVisibility,
  mapStateItemToProductPayload,
  findProfileForPhone,
  merchantProfileSections,
  getMerchantProfile,
  saveMerchantProfile,
  deleteMerchantProfile,
  enrichProfessionalProfileRow,
  getMerchantProducts,
  saveMerchantProduct,
  deleteMerchantProduct,
  listProfessionalProfiles,
  listMerchantStoresByService,
  listShoppingStores,
  listServiceStores,
  listOfferCatalogProducts,
  getMarketplaceStats,
  listRestaurantStores,
  listCatalogProducts,
  listRealEstateListings,
  GLOBAL_SHOPPING_SUB_CATEGORY_IDS,
  MARKETPLACE_CATEGORY_DEFS,
  syncMerchantProductsForBazaar,
  merchantProfilePayloadFromAppState,
  ensureMerchantProfileRecord,
  syncMissingMerchantProfilesFromAppState,
};
