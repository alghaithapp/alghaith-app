const {
  nowIso,
  normalizeObject,
  getPhoneVariants,
  resolvePhoneKey,
  normalizeArray,
  selectMany,
  selectManyColumns,
  selectSingleByPhone,
  selectSingle,
  saveRow,
  assertSupabaseAdmin,
  hasColumn,
  PLATFORM_ADMIN_PHONES,
  PLATFORM_SETTINGS_PHONE,
} = require('./common');
const {
  ensureAppUser,
  getAppUser,
  getUserState,
  saveUserState,
  saveAppUser,
  assertAdminAccess,
  getConfiguredAdminPhones,
  getAppUserId,
} = require('./users');
const {
  getMerchantProfile,
  profileServiceIds,
  isMerchantFrozen,
  isProfessionalMerchantProfile,
  merchantProfileDisplayName,
  isMerchantApproved,
  merchantApprovalStatus,
  isProductApproved,
  productApprovalStatus,
  merchantRejectionMessage,
  MERCHANT_REJECTION_REASONS,
  mapMerchantApprovalFields,
  syncMerchantProductsForBazaar,
  updateMerchantApprovalRecord,
  evaluateBazaarCustomerVisibility,
  ensureMerchantProfileRecord,
  syncMissingMerchantProfilesFromAppState,
  syncProfileSubCategoriesFromAppState,
  saveMerchantProfile,
  resolveMerchantContactVisibility,
} = require('./merchants');
const {
  saveCustomerProfile,
} = require('./customer_data');
const {
  readCourierProfileFromState,
  isCourierProfileComplete,
  isCourierApproved,
  COURIER_REJECTION_REASONS,
  courierApprovalStatus,
  courierRejectionMessage,
  mapCourierForAdmin,
  readDriverProfileFromState,
  isDriverProfileComplete,
  isDriverApproved,
  driverApprovalStatus,
  driverRejectionMessage,
  mapDriverForAdmin,
} = require('./couriers_drivers');
const {
  readOrderMeta,
  getMerchantIncomingOrders,
} = require('./orders');
const {
  normalizeProductImagePayload,
  serializeProductRowForClient,
} = require('../services/image_refs');
const {
  getMerchantProducts,
  deleteMerchantProfile,
  saveMerchantProduct,
} = require('./merchants');
const {
  deleteCustomerProfile,
  deleteAppUser,
  deleteUserState,
} = require('./users');
const {
  getDriverProfile,
  saveDriverProfile,
  getCourierProfile,
  saveCourierProfile,
  deleteCourierProfile,
  deleteDriverProfile,
  rowToDriverProfileMap,
  rowToCourierProfileMap,
} = require('./operator_profiles');

async function getAdminReports(phone) {
  await assertAdminAccess(phone);
  await syncMissingMerchantProfilesFromAppState();

  const WEEK_MS = 7 * 24 * 60 * 60 * 1000;
  const now = Date.now();
  const weekAgo = new Date(now - WEEK_MS).toISOString();

  const supabase = assertSupabaseAdmin();

  const [orders, merchants, totalProducts, totalUsers, driverCount, courierCount] = await Promise.all([
    selectMany('customer_orders', [], { column: 'updated_at', ascending: false }, 100),
    selectMany('merchant_profiles', [], { column: 'store_name', ascending: true }, 500),
    supabase.from('merchant_products').select('*', { count: 'exact', head: true }).then((r) => r.count || 0),
    supabase.from('app_users').select('*', { count: 'exact', head: true }).then((r) => r.count || 0),
    supabase.from('driver_profiles').select('*', { count: 'exact', head: true }).then((r) => r.count || 0),
    supabase.from('courier_profiles').select('*', { count: 'exact', head: true }).then((r) => r.count || 0),
  ]);

  let completedOrders = 0, pendingOrders = 0, deliveringOrders = 0, cancelledOrders = 0;
  let totalSales = 0, codCollected = 0, recentRevenue = 0, recentCount = 0;
  const ordersByStatus = {};

  for (const row of orders) {
    const meta = readOrderMeta(row);
    const price = Number(meta.payload.price) || 0;
    const status = meta.statusKey || 'unknown';
    ordersByStatus[status] = (ordersByStatus[status] || 0) + 1;

    if (meta.statusKey === 'completed') {
      completedOrders += 1;
      totalSales += price;
      if (meta.payload.codConfirmed) codCollected += price;
      if (row.updated_at && String(row.updated_at) >= weekAgo) {
        recentRevenue += price;
        recentCount += 1;
      }
    } else if (meta.statusKey === 'pending' || meta.statusKey === 'preparing') {
      pendingOrders += 1;
    } else if (meta.statusKey === 'cancelled' || meta.statusKey === 'rejected' || meta.statusKey === 'failed') {
      cancelledOrders += 1;
    } else if (meta.statusKey === 'delivering' || ['accepted', 'picked_up', 'on_way', 'waiting'].includes(meta.deliveryStatusKey)) {
      deliveringOrders += 1;
    }
  }

  const avgOrderValue = completedOrders > 0 ? Math.round(totalSales / completedOrders) : 0;
  const recentAvgOrderValue = recentCount > 0 ? Math.round(recentRevenue / recentCount) : avgOrderValue;
  const revenueGrowth = avgOrderValue > 0 ? Math.round(((recentAvgOrderValue - avgOrderValue) / avgOrderValue) * 100) : 0;

  const pendingMerchants = merchants.filter((m) => {
    const st = String(m.approval_status || '').trim();
    return st === 'pending' || (!st && !isMerchantApproved(m));
  }).length;
  const frozenMerchants = merchants.filter((m) => isMerchantFrozen(m)).length;
  const rejectedMerchantsCount = merchants.filter((m) => (String(m.approval_status || '').trim()) === 'rejected').length;
  const bazaarMerchants = merchants.filter((m) => m.is_bazaar_member === true).length;

  const topMerchants = merchants.filter((m) => isMerchantApproved(m)).map((m) => {
    let rev = 0, oc = 0;
    for (const row of orders) {
      const meta = readOrderMeta(row);
      if (!meta.merchantPhone) continue;
      try {
        if (getPhoneVariants(meta.merchantPhone).includes(m.phone) && meta.statusKey === 'completed') {
          rev += Number(meta.payload.price) || 0;
          oc += 1;
        }
      } catch (_) {}
    }
    return { phone: m.phone, storeName: merchantProfileDisplayName(m) || m.store_name || '', revenue: rev, orderCount: oc };
  }).filter((m) => m.revenue > 0).sort((a, b) => b.revenue - a.revenue).slice(0, 5);

  const recentOrders = orders.slice(0, 12).map((row) => {
    const meta = readOrderMeta(row);
    return {
      id: meta.id, orderNumber: meta.payload.orderNumber, statusKey: meta.statusKey,
      statusAr: meta.payload.statusAr, price: meta.payload.price,
      merchantStoreName: meta.payload.merchantStoreName, customerNameAr: meta.payload.customerNameAr,
      deliveryStatusKey: meta.deliveryStatusKey, updatedAt: row.updated_at,
    };
  });

  return {
    totalOrders: orders.length, completedOrders, pendingOrders, deliveringOrders, cancelledOrders,
    ordersByStatus, totalSales, codCollected, avgOrderValue, recentRevenue, revenueGrowth,
    totalMerchants: merchants.length,
    openMerchants: merchants.filter((r) => r.is_open !== false && !isMerchantFrozen(r)).length,
    frozenMerchants, pendingMerchantsCount: pendingMerchants, rejectedMerchantsCount,
    bazaarMerchants, topMerchants,
    totalProducts, totalUsers, activeUsersCount: 0,
    totalCouriers: courierCount, totalDrivers: driverCount, totalAdminAccounts: 0,
    recentOrders,
  };
}

function resolveMerchantServiceSubCategory(profile) {
  const direct = String(profile?.service_sub_category || '').trim();
  if (direct) return direct;
  const store = normalizeObject(profile?.store_data);
  return String(
    store.serviceSubCategory ||
      store.service_sub_category ||
      store.subCategoryId ||
      store.sub_category_id ||
      '',
  ).trim();
}

function resolveMerchantSpecialty(profile, state) {
  const info = normalizeObject(profile?.professional_info ?? profile?.professionalInfo);
  const fromInfo = String(info.specialty ?? '').trim();
  if (fromInfo) return fromInfo;

  const normalizedState = normalizeObject(state);
  const merchantStore = normalizeObject(normalizedState.merchantStore);
  const fromStore = String(merchantStore.specialty ?? '').trim();
  if (fromStore) return fromStore;

  const professionalInfo = normalizeObject(
    merchantStore.professionalInfo ?? merchantStore.professional_info,
  );
  return String(professionalInfo.specialty ?? '').trim();
}

function enrichMerchantSummaryFromState(summary, state) {
  const normalizedState = normalizeObject(state);
  const merchantStore = normalizeObject(normalizedState.merchantStore);
  const next = { ...summary };

  if (!String(next.primaryServiceId ?? '').trim()) {
    next.primaryServiceId = String(
      merchantStore.primary_service_id ??
        merchantStore.primaryServiceId ??
        merchantStore.active_service_id ??
        merchantStore.activeServiceId ??
        merchantStore.category ??
        '',
    ).trim();
  }

      if (!String(next.serviceSubCategory ?? '').trim()) {
        next.serviceSubCategory = String(
          merchantStore.serviceSubCategory ??
            merchantStore.service_sub_category ??
            merchantStore.subCategoryId ??
            merchantStore.sub_category_id ??
            '',
        ).trim();
      }

      if (
        !String(next.serviceSubCategory ?? '').trim() &&
        String(next.primaryServiceId ?? '').trim() === 'beauty' &&
        merchantStore.adminPreRegistered === true
      ) {
        const sub = String(
          merchantStore.subCategoryId ?? merchantStore.sub_category_id ?? '',
        ).trim();
        if (sub) next.serviceSubCategory = sub;
      }

  if (!Array.isArray(next.serviceIds) || next.serviceIds.length === 0) {
    const ids = normalizeArray(merchantStore.serviceIds ?? merchantStore.service_ids);
    if (ids.length > 0) next.serviceIds = ids;
  }

  if (!String(next.specialty ?? '').trim()) {
    next.specialty = resolveMerchantSpecialty(summary, normalizedState);
  }

  return next;
}

async function getAllMerchants(adminPhone) {
  await assertAdminAccess(adminPhone);
  await syncMissingMerchantProfilesFromAppState();

  const [merchants, orders] = await Promise.all([
    selectMany('merchant_profiles', [], { column: 'store_name', ascending: true }),
    // تحديث: نحدد عدد الطلبات إلى 500 لتقليل وقت التحميل
    selectMany('customer_orders', [], { column: 'updated_at', ascending: false }, 500),
  ]);
  await syncProfileSubCategoriesFromAppState(merchants);
  const userPhones = merchants.map((m) => m.phone).filter(Boolean);

  const allProducts = await selectMany(
    'merchant_products',
    [],
    { column: 'created_at', ascending: false },
    5000
  );
  const productStatsByPhone = new Map();
  for (const row of allProducts) {
    const phone = String(row.phone || '').trim();
    if (!phone) continue;
    let bucket = productStatsByPhone.get(phone);
    if (!bucket) {
      bucket = { total: 0, approved: 0, pending: 0 };
      productStatsByPhone.set(phone, bucket);
    }
    bucket.total += 1;
    if (isProductApproved(row)) bucket.approved += 1;
    else bucket.pending += 1;
  }

  function productStatsForMerchantPhone(phone) {
    for (const variant of getPhoneVariants(phone)) {
      const bucket = productStatsByPhone.get(variant);
      if (bucket) return bucket;
    }
    return { total: 0, approved: 0, pending: 0 };
  }

  const users = userPhones.length > 0
    ? await selectMany('app_users', [{ method: 'in', column: 'phone', value: userPhones }])
    : [];

  const userByPhone = {};
  for (const u of users) {
    userByPhone[u.phone] = u;
  }

  const needsStateEnrichment = merchants.filter((m) => {
    if (!m.phone) return false;
    const primary = String(m.primary_service_id || '').trim();
    const sub = resolveMerchantServiceSubCategory(m);
    return !primary || !sub;
  });
  const enrichPhones = [
    ...new Set(needsStateEnrichment.map((m) => m.phone).filter(Boolean)),
  ];
  const stateByPhone = {};
  if (enrichPhones.length > 0) {
    const stateRows = await selectMany(
      'app_state',
      [{ method: 'in', column: 'phone', value: enrichPhones }],
      { column: 'updated_at', ascending: false },
      enrichPhones.length,
    );
    for (const row of stateRows) {
      const phone = String(row.phone || '').trim();
      if (!phone) continue;
      stateByPhone[phone] = normalizeObject(row.state);
    }
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

  const result = [];
  for (const m of merchants) {
    if (!m.phone) continue;

    const stats = orderStatsByMerchant.get(m.phone) || {
      completedOrders: 0,
      deliveringOrders: 0,
      pendingOrders: 0,
      totalRevenue: 0,
      lastOrderAt: null,
    };

    const bazaarVisibility = evaluateBazaarCustomerVisibility(m, []);
    const productStats = productStatsForMerchantPhone(m.phone);
    const media = extractMerchantMedia(m);

    result.push(
      enrichMerchantSummaryFromState(
        {
          ...stats,
          totalProducts: productStats.total,
          availableProducts: productStats.approved,
          pendingProducts: productStats.pending,
          visibleToCustomers: bazaarVisibility.visibleToCustomers,
          visibleProductCount: bazaarVisibility.visibleProductCount,
          visibilityNotes: bazaarVisibility.visibilityNotes,
          phone: m.phone,
          storeName:
            merchantProfileDisplayName(m) ||
            String(m.store_name || '').trim() ||
            String(userByPhone[m.phone]?.full_name || '').trim() ||
            `تاجر ${String(m.phone || '').slice(-4)}`,
          isProfessional: isProfessionalMerchantProfile(m),
          description: (m.description || '').slice(0, 80),
          primaryServiceId: m.primary_service_id || '',
          serviceSubCategory: resolveMerchantServiceSubCategory(m),
          specialty: resolveMerchantSpecialty(m, stateByPhone[m.phone]),
          serviceIds: profileServiceIds(m),
          isOpen: m.is_open !== false,
          isFrozen: isMerchantFrozen(m),
          rating: Number(m.rating || 0),
          isBazaarMember: m.is_bazaar_member === true,
          createdAt: m.created_at,
          fullName: userByPhone[m.phone]?.full_name || '',
          role: userByPhone[m.phone]?.role || '',
          profileImageUrl: media.profileImageUrl,
          logoImageUrl: media.logoImageUrl,
          coverImageUrl: media.coverImageUrl,
          clinicImageUrl: media.clinicImageUrl,
          avatarImageUrl: media.avatarImageUrl,
          ...mapMerchantApprovalFields(m),
        },
        stateByPhone[m.phone],
      ),
    );
  }

  return result.sort((a, b) => {
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

async function getAllCouriers(adminPhone) {
  await assertAdminAccess(adminPhone);

  const courierRows = await selectMany('courier_profiles', [], { column: 'updated_at', ascending: false }, 2500);

  const phones = courierRows.map(r => r.phone).filter(Boolean);
  const users = phones.length > 0 ? await selectMany('app_users', [{ method: 'in', column: 'phone', value: phones }]) : [];

  const courierProfileByPhone = {};
  for (const row of courierRows) {
    const phone = String(row.phone || '').trim();
    if (!phone) continue;
    courierProfileByPhone[phone] = rowToCourierProfileMap(row);
  }

  const userByPhone = {};
  for (const user of users) {
    const phone = String(user.phone || '').trim();
    if (!phone) continue;
    userByPhone[phone] = user;
  }

  const couriers = [];
  const seen = new Set();

  for (const [phone, dbProfile] of Object.entries(courierProfileByPhone)) {
    if (seen.has(phone)) continue;
    if (!dbProfile) continue;

    const user = userByPhone[phone] || null;
    seen.add(phone);
    couriers.push(mapCourierForAdmin(phone, user, dbProfile));
  }

  return couriers.sort((a, b) => {
    const rank = (item) => {
      if (item.approvalStatus === 'pending') return 0;
      if (item.approvalStatus === 'rejected') return 1;
      return 2;
    };
    const rankDiff = rank(a) - rank(b);
    if (rankDiff !== 0) return rankDiff;

    const aName = String(a.name || '').trim().toLowerCase();
    const bName = String(b.name || '').trim().toLowerCase();
    return aName.localeCompare(bName);
  });
}

async function getAllDrivers(adminPhone) {
  await assertAdminAccess(adminPhone);

  const driverRows = await selectMany('driver_profiles', [], { column: 'updated_at', ascending: false }, 2000);

  const phones = driverRows.map(r => r.phone).filter(Boolean);
  const users = phones.length > 0 ? await selectMany('app_users', [{ method: 'in', column: 'phone', value: phones }]) : [];

  const driverProfileByPhone = {};
  for (const row of driverRows) {
    const phone = String(row.phone || '').trim();
    if (!phone) continue;
    driverProfileByPhone[phone] = rowToDriverProfileMap(row);
  }

  const userByPhone = {};
  for (const user of users) {
    const phone = String(user.phone || '').trim();
    if (!phone) continue;
    userByPhone[phone] = user;
  }

  const drivers = [];
  const seen = new Set();
  for (const [phone, dbProfile] of Object.entries(driverProfileByPhone)) {
    if (seen.has(phone)) continue;
    if (!dbProfile) continue;

    const user = userByPhone[phone] || null;
    const name = String(dbProfile.name ?? '').trim();
    const role = String(user?.role ?? '').trim();
    const accountType = String(user?.account_type ?? '').trim();
    
    // Accept if it's explicitly a driver account or has a non-empty name
    const isDriverAccount = role === 'driver' || accountType === 'driver' || name.length > 0;
    if (!isDriverAccount) continue;

    seen.add(phone);
    drivers.push(mapDriverForAdmin(phone, user, dbProfile));
  }

  return drivers;
}

function mapAdminProductRow(product) {
  const row = product || {};
  return {
    id: String(row.id || ''),
    name: String(row.name || row.name_ar || row.nameAr || row.title_ar || '').trim(),
    nameAr: String(row.name_ar || row.nameAr || '').trim(),
    category: String(row.category || '').trim(),
    subCategory: String(row.sub_category || row.subCategory || '').trim(),
    price: Number(row.price || 0),
    isAvailable: row.is_available !== false,
    image: String(row.image || row.image_url || '').trim(),
    imageUrl: String(row.image_url || row.image || '').trim(),
    createdAt: row.created_at || null,
    isApproved: row.is_approved !== false,
  };
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
  const media = extractMerchantMedia(profile);

  return {
    merchant: {
      phone: profile.phone,
      storeName: profile.store_name || '',
      description: profile.description || '',
      primaryServiceId: profile.primary_service_id || '',
      serviceIds: profileServiceIds(profile),
      isOpen: profile.is_open !== false,
      isFrozen: isMerchantFrozen(profile),
      isApproved: isMerchantApproved(profile),
      approvalStatus: merchantApprovalStatus(profile),
      isBazaarMember: profile.is_bazaar_member === true,
      rating: Number(profile.rating || 0),
      address: profile.address || '',
      deliveryFee: Number(profile.delivery_fee || 0),
      createdAt: profile.created_at || null,
      updatedAt: profile.updated_at || null,
      fullName: appUser?.full_name || '',
      role: appUser?.role || '',
      profileImageUrl: media.profileImageUrl,
      logoImageUrl: media.logoImageUrl,
      coverImageUrl: media.coverImageUrl,
      clinicImageUrl: media.clinicImageUrl,
      avatarImageUrl: media.avatarImageUrl,
      workSampleUrls: media.workSamples,
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
    products: products.map(mapAdminProductRow),
  };
}

function mapProfessionalCategoryLabel(categoryId) {
  const id = String(categoryId || '').trim();
  if (!id) return '—';
  return PROFESSIONAL_CATEGORY_NAMES[id]?.ar || id;
}

function extractMerchantMedia(profile) {
  const info = normalizeObject(profile?.professional_info);
  const profileImageUrl = String(
    info.profileImageUrl ||
      info.profileImageBase64 ||
      profile?.profile_image_url ||
      profile?.profile_image_base64 ||
      profile?.logo_image_url ||
      '',
  ).trim();
  const logoImageUrl = String(
    profile?.logo_image_url || info.profileImageUrl || profileImageUrl || '',
  ).trim();
  const coverImageUrl = String(
    profile?.cover_image_url || info.coverImageUrl || info.coverImageBase64 || '',
  ).trim();
  const clinicImageUrl = String(
    info.clinicImageUrl || info.clinicImageBase64 || coverImageUrl || '',
  ).trim();
  const workSamples = normalizeArray(
    profile?.work_sample_images_base64 ??
      info.workSampleImagesBase64 ??
      info.work_sample_images_base64,
  )
    .map((item) => String(item || '').trim())
    .filter(Boolean);
  const avatarImageUrl = profileImageUrl || logoImageUrl || coverImageUrl || clinicImageUrl;
  return {
    profileImageUrl,
    logoImageUrl,
    coverImageUrl,
    clinicImageUrl,
    avatarImageUrl,
    workSamples,
  };
}

function extractProfessionalMedia(profile) {
  const { profileImageUrl, workSamples } = extractMerchantMedia(profile || {});
  return { profileImage: profileImageUrl, workSamples };
}

function isAdminProfessionalSummary(merchantSummary, profile) {
  if (!merchantSummary && !profile) return false;
  if (merchantSummary?.isProfessional) return true;
  if (merchantSummary?.primaryServiceId === 'professionals') return true;
  if (profile && isProfessionalMerchantProfile(profile)) return true;
  const serviceIds = merchantSummary?.serviceIds || profileServiceIds(profile || {});
  return serviceIds.includes('professionals');
}

async function getAllProfessionals(adminPhone) {
  await assertAdminAccess(adminPhone);

  const [merchants, profiles] = await Promise.all([
    getAllMerchants(adminPhone),
    selectMany('merchant_profiles', [], { column: 'updated_at', ascending: false }),
  ]);

  const profileByPhone = {};
  for (const profile of profiles) {
    const phone = String(profile.phone || '').trim();
    if (!phone) continue;
    for (const variant of getPhoneVariants(phone)) {
      profileByPhone[variant] = profile;
    }
  }

  const seen = new Set();
  const result = [];

  for (const merchant of merchants) {
    const phone = String(merchant.phone || '').trim();
    if (!phone || seen.has(phone)) continue;

    const profile = profileByPhone[phone] || null;
    if (!isAdminProfessionalSummary(merchant, profile)) continue;

    seen.add(phone);
    const categoryId = String(
      profile?.professional_category_id ||
        normalizeObject(profile?.professional_info)?.professionId ||
        '',
    ).trim();
    const { profileImage, workSamples } = extractProfessionalMedia(profile || {});

    result.push({
      ...merchant,
      professionalCategoryId: categoryId,
      professionalCategoryLabel: mapProfessionalCategoryLabel(categoryId),
      profileImageUrl: profileImage,
      workSampleCount: workSamples.length,
    });
  }

  return result.sort((a, b) => {
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

async function getAdminProfessionalDetails(adminPhone, professionalPhone) {
  const base = await getAdminMerchantDetails(adminPhone, professionalPhone);
  const profile = await getMerchantProfile(professionalPhone);
  if (!profile) {
    throw new Error('Professional not found.');
  }

  const info = normalizeObject(profile.professional_info);
  const visibility = resolveMerchantContactVisibility(profile);
  const categoryId = String(profile.professional_category_id || info.professionId || '').trim();
  const { profileImage, workSamples } = extractProfessionalMedia(profile);

  return {
    ...base,
    professional: {
      categoryId,
      categoryLabel: mapProfessionalCategoryLabel(categoryId),
      profileImageUrl: profileImage,
      workSampleUrls: workSamples,
      description: String(profile.description || info.description || '').trim(),
      contactPhone: String(info.phone || profile.phone || '').trim(),
      whatsapp: String(profile.whatsapp || info.whatsapp || '').trim(),
      openTime: String(profile.open_time || info.openTime || '').trim(),
      closeTime: String(profile.close_time || info.closeTime || '').trim(),
      showPhoneToCustomers: visibility.showPhoneToCustomers,
      showWhatsAppToCustomers: visibility.showWhatsAppToCustomers,
      rejectionMessageAr: merchantRejectionMessage(profile),
      professionalInfo: info,
    },
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

  // Try atomic RPC first
  try {
    const supabase = assertSupabaseAdmin();
    const { data, error } = await supabase.rpc('atomic_approve_courier', {
      p_phone: phoneKey,
      p_approved: Boolean(isApproved),
    });
    if (!error) {
      const user = await getAppUser(phoneKey);
      const profile = (await getCourierProfile(phoneKey)) || {};
      const mapped = mapCourierForAdmin(phoneKey, user, profile);

      if (Boolean(isApproved)) {
        try {
          const { onCourierApproved } = require('../push_events');
          await onCourierApproved(phoneKey);
        } catch (pushError) {
          console.error('push onCourierApproved error:', pushError?.message || pushError);
        }
      }

      return { success: true, courier: mapped };
    }
  } catch (_) {
    // fallback
  }

  const profile = await getCourierProfile(phoneKey);
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
  await saveCourierProfile(phoneKey, nextProfile);

  const user = await getAppUser(phoneKey);
  const mapped = mapCourierForAdmin(phoneKey, user, nextProfile);

  if (Boolean(isApproved)) {
    try {
      const { onCourierApproved } = require('../push_events');
      await onCourierApproved(phoneKey);
    } catch (pushError) {
      console.error('push onCourierApproved error:', pushError?.message || pushError);
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

  // Try atomic RPC first
  try {
    const supabase = assertSupabaseAdmin();
    const { data, error } = await supabase.rpc('atomic_reject_courier', {
      p_phone: phoneKey,
      p_reason_key: normalizedReason,
      p_message_ar: message,
    });
    if (!error) {
      const user = await getAppUser(phoneKey);
      const profile = (await getCourierProfile(phoneKey)) || {};
      const mapped = mapCourierForAdmin(phoneKey, user, profile);

      try {
        const { onCourierRejected } = require('../push_events');
        await onCourierRejected(phoneKey, message, normalizedReason);
      } catch (pushError) {
        console.error('push onCourierRejected error:', pushError?.message || pushError);
      }

      return { success: true, courier: mapped };
    }
  } catch (_) {
    // fallback
  }

  const profile = await getCourierProfile(phoneKey);
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
  await saveCourierProfile(phoneKey, nextProfile);

  const user = await getAppUser(phoneKey);
  const mapped = mapCourierForAdmin(phoneKey, user, nextProfile);

  try {
    const { onCourierRejected } = require('../push_events');
    await onCourierRejected(phoneKey, message, normalizedReason);
  } catch (pushError) {
    console.error('push onCourierRejected error:', pushError?.message || pushError);
  }

  return { success: true, courier: mapped };
}

async function toggleMerchantApprovalStatus(adminPhone, merchantPhone, isApproved) {
  await assertAdminAccess(adminPhone);

  const phoneKey = await resolvePhoneKey(merchantPhone);
  await ensureMerchantProfileRecord(phoneKey);

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
      const { onMerchantApproved } = require('../push_events');
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
  await ensureMerchantProfileRecord(phoneKey);

  await updateMerchantApprovalRecord(phoneKey, {
    isApproved: false,
    approvalStatus: 'rejected',
    rejectionReasonKey: normalizedReason,
    rejectionMessageAr: message,
    rejectedAt: nowIso(),
  });

  try {
    const { onMerchantRejected } = require('../push_events');
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

  const phoneKey = await resolvePhoneKey(merchantPhone);
  const supabase = assertSupabaseAdmin();

  // Try atomic RPC first
  try {
    const { data, error } = await supabase.rpc('atomic_toggle_frozen', {
      p_phone: phoneKey,
      p_is_frozen: Boolean(isFrozen),
    });
    if (!error) {
      try {
        const { onMerchantFrozen } = require('../push_events');
        await onMerchantFrozen(merchantPhone, Boolean(isFrozen));
      } catch (pushError) {
        console.error('push onMerchantFrozen error:', pushError?.message || pushError);
      }
      return { success: true, merchant: { phone: phoneKey, is_frozen: Boolean(isFrozen) } };
    }
  } catch (_) {
    // fallback
  }

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
    const { onMerchantFrozen } = require('../push_events');
    await onMerchantFrozen(merchantPhone, Boolean(isFrozen));
  } catch (pushError) {
    console.error('push onMerchantFrozen error:', pushError?.message || pushError);
  }

  return { success: true, merchant: data[0] };
}

async function updateAccountRole(adminPhone, targetPhone, newRole) {
  await assertAdminAccess(adminPhone);

  const phoneKey = await resolvePhoneKey(targetPhone);
  if (!phoneKey) {
    throw new Error('Account phone is required.');
  }

  const existing = await getAppUser(phoneKey);
  if (!existing) {
    throw new Error('Account not found.');
  }

  const normalizedRole = String(newRole || '').trim().toLowerCase();
  const validRoles = ['customer', 'merchant', 'delivery', 'driver', 'admin'];
  if (!validRoles.includes(normalizedRole)) {
    throw new Error(`Invalid role. Must be one of: ${validRoles.join(', ')}`);
  }

  const supabase = assertSupabaseAdmin();

  // Try atomic RPC first
  try {
    const { data, error } = await supabase.rpc('atomic_update_account_role', {
      p_phone: phoneKey,
      p_role: normalizedRole,
    });
    if (!error) {
      return { success: true, phone: phoneKey, role: normalizedRole };
    }
  } catch (_) {
    // fallback
  }

  const { error } = await supabase
    .from('app_users')
    .update({
      role: normalizedRole,
      account_type: normalizedRole,
      updated_at: nowIso(),
    })
    .eq('phone', phoneKey);

  if (error) throw new Error(error.message);

  const state = (await getUserState(phoneKey)) || {};
  await saveUserState(phoneKey, {
    ...state,
    userRole: normalizedRole,
    user_role: normalizedRole,
  });

  return { success: true, phone: phoneKey, role: normalizedRole };
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

async function toggleDriverApprovalStatus(adminPhone, driverPhone, isApproved) {
  await assertAdminAccess(adminPhone);

  const phoneKey = await resolvePhoneKey(driverPhone);

  // Try atomic RPC first
  try {
    const supabase = assertSupabaseAdmin();
    const { data, error } = await supabase.rpc('atomic_approve_driver', {
      p_phone: phoneKey,
      p_approved: Boolean(isApproved),
    });
    if (!error) {
      const user = await getAppUser(phoneKey);
      const refreshedState = (await getUserState(phoneKey)) || {};
      const operatorProfiles = await loadOperatorProfiles(phoneKey);
      const mapped = mapAdminAccountSummary(
        user,
        refreshedState,
        null,
        operatorProfiles
      );

      if (Boolean(isApproved)) {
        try {
          const { onDriverApproved } = require('../push_events');
          await onDriverApproved(phoneKey);
        } catch (pushError) {
          console.error('push onDriverApproved error:', pushError?.message || pushError);
        }
      }

      return { success: true, driver: mapped };
    }
  } catch (_) {
    // fallback
  }

  const profile = await getDriverProfile(phoneKey);
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
  await saveDriverProfile(phoneKey, nextProfile);

  const user = await getAppUser(phoneKey);
  const refreshedState = (await getUserState(phoneKey)) || {};
  const mapped = mapAdminAccountSummary(user, refreshedState, null, {
    driverProfile: nextProfile,
  });

  if (Boolean(isApproved)) {
    try {
      const { onDriverApproved } = require('../push_events');
      await onDriverApproved(phoneKey);
    } catch (pushError) {
      console.error('push onDriverApproved error:', pushError?.message || pushError);
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

  // Try atomic RPC first
  try {
    const supabase = assertSupabaseAdmin();
    const { data, error } = await supabase.rpc('atomic_reject_driver', {
      p_phone: phoneKey,
      p_reason_key: normalizedReason,
      p_message_ar: message,
    });
    if (!error) {
      const user = await getAppUser(phoneKey);
      const refreshedState = (await getUserState(phoneKey)) || {};
      const operatorProfiles = await loadOperatorProfiles(phoneKey);
      const mapped = mapAdminAccountSummary(
        user,
        refreshedState,
        null,
        operatorProfiles
      );

      try {
        const { onDriverRejected } = require('../push_events');
        await onDriverRejected(phoneKey, message, normalizedReason);
      } catch (pushError) {
        console.error('push onDriverRejected error:', pushError?.message || pushError);
      }

      return { success: true, driver: mapped };
    }
  } catch (_) {
    // fallback
  }

  const profile = await getDriverProfile(phoneKey);
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
  await saveDriverProfile(phoneKey, nextProfile);

  const user = await getAppUser(phoneKey);
  const refreshedState = (await getUserState(phoneKey)) || {};
  const mapped = mapAdminAccountSummary(user, refreshedState, null, {
    driverProfile: nextProfile,
  });

  try {
    const { onDriverRejected } = require('../push_events');
    await onDriverRejected(phoneKey, message, normalizedReason);
  } catch (pushError) {
    console.error('push onDriverRejected error:', pushError?.message || pushError);
  }

  return { success: true, driver: mapped };
}

async function loadOperatorProfiles(phoneKey) {
  const [driverProfile, courierProfile] = await Promise.all([
    getDriverProfile(phoneKey),
    getCourierProfile(phoneKey),
  ]);
  return { driverProfile, courierProfile };
}

function resolveDriverProfile(state, operatorProfiles = {}) {
  return operatorProfiles.driverProfile ?? readDriverProfileFromState(state);
}

function resolveCourierProfile(state, operatorProfiles = {}) {
  return operatorProfiles.courierProfile ?? readCourierProfileFromState(state);
}

function classifyAdminAccountKind(user, state, merchantProfile, operatorProfiles = {}) {
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

  const driverProfile = resolveDriverProfile(state, operatorProfiles);
  if (
    role === 'driver' ||
    accountType === 'driver' ||
    (driverProfile && Object.keys(driverProfile).length > 0)
  ) {
    return 'driver';
  }

  const courierProfile = resolveCourierProfile(state, operatorProfiles);
  if (
    role === 'delivery' ||
    accountType === 'delivery' ||
    isCourierProfileComplete(courierProfile)
  ) {
    return 'courier';
  }

  return 'customer';
}

function accountDisplayName(user, state, merchantProfile, kind, operatorProfiles = {}) {
  const fullName = String(user?.full_name ?? '').trim();
  const merchantName = String(merchantProfile?.store_name ?? '').trim();
  const merchantStoreName = String(state?.merchantStore?.name ?? '').trim();
  const courierName = String(
    resolveCourierProfile(state, operatorProfiles)?.name ?? ''
  ).trim();
  const driverName = String(
    resolveDriverProfile(state, operatorProfiles)?.name ?? ''
  ).trim();
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

function resolveAccountSuspended(state, merchantProfile, operatorProfiles = {}) {
  if (state?.accountSuspended === true) return true;
  if (isMerchantFrozen(merchantProfile)) return true;
  if (resolveCourierProfile(state, operatorProfiles)?.isSuspended === true) {
    return true;
  }
  if (resolveDriverProfile(state, operatorProfiles)?.isSuspended === true) {
    return true;
  }
  return false;
}

const DRIVER_DOCUMENT_KEYS = [
  'profileImage', 'vehicleImage', 'idFrontImage', 'idBackImage',
  'residenceCardImage', 'vehicleRegFrontImage', 'vehicleRegBackImage',
];

function extractDriverDocuments(profile) {
  if (!profile || typeof profile !== 'object') return undefined;
  const docs = {};
  let hasAny = false;
  for (const key of DRIVER_DOCUMENT_KEYS) {
    const url = String(profile[key] ?? '').trim();
    if (url) {
      docs[key] = url;
      hasAny = true;
    }
  }
  return hasAny ? docs : undefined;
}

function mapAdminAccountSummary(user, state, merchantProfile, operatorProfiles = {}) {
  const phone = String(user?.phone ?? '').trim();
  const kind = classifyAdminAccountKind(
    user,
    state,
    merchantProfile,
    operatorProfiles
  );
  const courierProfile = resolveCourierProfile(state, operatorProfiles);
  const driverProfile = resolveDriverProfile(state, operatorProfiles);
  const approval = resolveAccountApproval(state, merchantProfile, kind, operatorProfiles);
  const hasDriverCredential = Boolean(
    driverProfile &&
      (isDriverProfileComplete(driverProfile) ||
        String(driverProfile.name ?? '').trim() ||
        driverProfile.adminPreRegistered === true)
  );

  return {
    phone,
    displayName: accountDisplayName(
      user,
      state,
      merchantProfile,
      kind,
      operatorProfiles
    ),
    fullName: String(user?.full_name ?? '').trim(),
    role: String(user?.role ?? '').trim(),
    accountType: String(user?.account_type ?? '').trim(),
    kind,
    isSuspended: resolveAccountSuspended(state, merchantProfile, operatorProfiles),
    merchantStoreName: String(merchantProfile?.store_name ?? '').trim(),
    primaryServiceId: String(merchantProfile?.primary_service_id ?? '').trim(),
    courierApproved: isCourierApproved(courierProfile),
    needsApproval: approval.needsApproval,
    approvalStatus: approval.approvalStatus,
    isApproved: approval.isApproved,
    rejectionMessageAr: approval.rejectionMessageAr,
    driverIsApproved: isDriverApproved(driverProfile),
    driverApprovalStatus: driverApprovalStatus(driverProfile),
    updatedAt: user?.updated_at ?? merchantProfile?.updated_at ?? null,
    createdAt: user?.created_at ?? merchantProfile?.created_at ?? null,
    hasMerchantProfile: Boolean(merchantProfile),
    hasCourierProfile: isCourierProfileComplete(courierProfile),
    hasDriverProfile: isDriverProfileComplete(driverProfile),
    hasDriverCredential,
    driverProfileComplete: isDriverProfileComplete(driverProfile),
    documents: kind === 'driver' || hasDriverCredential
      ? extractDriverDocuments(driverProfile)
      : undefined,
  };
}

function resolveAccountApproval(state, merchantProfile, kind, operatorProfiles = {}) {
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
    const profile = resolveCourierProfile(state, operatorProfiles);
    return {
      needsApproval: true,
      approvalStatus: courierApprovalStatus(profile),
      isApproved: isCourierApproved(profile),
      rejectionMessageAr: courierRejectionMessage(profile) || null,
    };
  }
  if (kind === 'driver') {
    const profile = resolveDriverProfile(state, operatorProfiles);
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

function resolveStateForAdminAccount(states, phone) {
  for (const row of states) {
    const rowPhone = String(row.phone || '').trim();
    if (!rowPhone) continue;
    for (const variant of getPhoneVariants(phone)) {
      if (getPhoneVariants(rowPhone).includes(variant)) {
        return row.state || {};
      }
    }
  }
  return {};
}

async function getAllAdminAccounts(adminPhone) {
  await assertAdminAccess(adminPhone);
  await syncMissingMerchantProfilesFromAppState();

  const [users, states, merchants, drivers, couriers] = await Promise.all([
    selectMany('app_users', [], { column: 'updated_at', ascending: false }, 3000),
    selectManyColumns(
      'app_state',
      'phone, state',
      [],
      { column: 'updated_at', ascending: false },
      2500
    ),
    selectMany('merchant_profiles', [], { column: 'updated_at', ascending: false }, 2000),
    selectMany('driver_profiles', [], { column: 'updated_at', ascending: false }, 2000),
    selectMany('courier_profiles', [], { column: 'updated_at', ascending: false }, 2000),
  ]);

  const merchantByPhone = {};
  for (const row of merchants) {
    const phone = String(row.phone || '').trim();
    if (!phone) continue;
    for (const variant of getPhoneVariants(phone)) {
      merchantByPhone[variant] = row;
    }
  }

  const driverByPhone = {};
  for (const row of drivers) {
    const phone = String(row.phone || '').trim();
    if (!phone) continue;
    for (const variant of getPhoneVariants(phone)) {
      driverByPhone[variant] = row;
    }
  }

  const courierByPhone = {};
  for (const row of couriers) {
    const phone = String(row.phone || '').trim();
    if (!phone) continue;
    for (const variant of getPhoneVariants(phone)) {
      courierByPhone[variant] = row;
    }
  }

  const accounts = users
    .map((user) => {
      const phone = String(user.phone || '').trim();
      if (!phone) return null;
      const state = resolveStateForAdminAccount(states, phone);
      let merchantProfile = null;
      let driverRow = null;
      let courierRow = null;
      for (const variant of getPhoneVariants(phone)) {
        if (!merchantProfile && merchantByPhone[variant]) {
          merchantProfile = merchantByPhone[variant];
        }
        if (!driverRow && driverByPhone[variant]) {
          driverRow = driverByPhone[variant];
        }
        if (!courierRow && courierByPhone[variant]) {
          courierRow = courierByPhone[variant];
        }
      }
      return mapAdminAccountSummary(user, state, merchantProfile, {
        driverProfile: driverRow ? rowToDriverProfileMap(driverRow) : null,
        courierProfile: courierRow ? rowToCourierProfileMap(courierRow) : null,
      });
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
    await deleteCourierProfile(phoneKey);
  } catch (error) {
    if (!/not found|No rows/i.test(String(error?.message || ''))) {
      console.warn('purgeAccountData courier profile:', error?.message || error);
    }
  }

  try {
    await deleteDriverProfile(phoneKey);
  } catch (error) {
    if (!/not found|No rows/i.test(String(error?.message || ''))) {
      console.warn('purgeAccountData driver profile:', error?.message || error);
    }
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

async function deleteDriverAccount(adminPhone, targetPhone) {
  return adminDeleteAccount(adminPhone, targetPhone);
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

  const supabase = assertSupabaseAdmin();

  // Try atomic RPC first
  try {
    const { data, error } = await supabase.rpc('atomic_suspend_account', {
      p_phone: phoneKey,
      p_is_suspended: Boolean(isSuspended),
    });
    if (!error) {
      const refreshedState = (await getUserState(phoneKey)) || {};
      const refreshedMerchant = await getMerchantProfile(phoneKey);
      const operatorProfiles = await loadOperatorProfiles(phoneKey);
      return {
        success: true,
        phone: phoneKey,
        isSuspended: resolveAccountSuspended(
          refreshedState,
          refreshedMerchant,
          operatorProfiles
        ),
        account: mapAdminAccountSummary(
          existing,
          refreshedState,
          refreshedMerchant,
          operatorProfiles
        ),
      };
    }
  } catch (_) {
    // fallback
  }

  const state = (await getUserState(phoneKey)) || {};
  const merchantProfile = await getMerchantProfile(phoneKey);
  const courierProfile = await getCourierProfile(phoneKey);
  const driverProfile = await getDriverProfile(phoneKey);

  const nextState = {
    ...state,
    accountSuspended: Boolean(isSuspended),
    suspendedAt: isSuspended ? nowIso() : null,
  };

  if (courierProfile) {
    await saveCourierProfile(phoneKey, {
      ...courierProfile,
      isSuspended: Boolean(isSuspended),
      available: !isSuspended,
    });
  }

  if (driverProfile) {
    await saveDriverProfile(phoneKey, {
      ...driverProfile,
      isSuspended: Boolean(isSuspended),
      available: !isSuspended,
    });
  }

  await saveUserState(phoneKey, nextState);

  if (merchantProfile) {
    const variants = getPhoneVariants(phoneKey);
    const { error } = await supabase
      .from('merchant_profiles')
      .update({ is_frozen: Boolean(isSuspended), updated_at: nowIso() })
      .in('phone', variants);
    if (error) throw new Error(error.message);
  }

  const refreshedState = (await getUserState(phoneKey)) || nextState;
  const refreshedMerchant = await getMerchantProfile(phoneKey);
  const operatorProfiles = await loadOperatorProfiles(phoneKey);
  return {
    success: true,
    phone: phoneKey,
    isSuspended: resolveAccountSuspended(
      refreshedState,
      refreshedMerchant,
      operatorProfiles
    ),
    account: mapAdminAccountSummary(
      existing,
      refreshedState,
      refreshedMerchant,
      operatorProfiles
    ),
  };
}

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

const MERCHANT_SIGNUP_SERVICE_IDS = new Set([
  'restaurant',
  'product',
  'cars',
  'global_shopping',
  'professionals',
  'beauty',
  'tourism',
  'real_estate',
  'offers',
  'used',
]);

async function preRegisterCustomerAccount(adminPhone, payload = {}) {
  await assertAdminAccess(adminPhone);

  const rawPhone = String(payload.phone ?? payload.customerPhone ?? '').trim();
  if (!rawPhone) {
    throw new Error('رقم الهاتف مطلوب.');
  }

  const phoneKey = await resolvePhoneKey(rawPhone);
  const fullName = String(payload.fullName ?? payload.full_name ?? '').trim();
  const address = String(payload.address ?? '').trim();

  const existingUser = await getAppUser(phoneKey);
  if (existingUser && String(existingUser.role ?? '').trim() === 'admin') {
    throw new Error('لا يمكن تسجيل رقم المشرف كزبون.');
  }

  await ensureAppUser(phoneKey, {
    role: 'customer',
    account_type: 'marketplace',
    full_name: fullName || undefined,
  });

  if (fullName || address) {
    await saveCustomerProfile(phoneKey, {
      display_name: fullName || undefined,
      full_name: fullName || undefined,
      address: address || undefined,
    });
  }

  const merchantProfile = await getMerchantProfile(phoneKey);
  if (merchantProfile) {
    throw new Error('هذا الرقم مرتبط بحساب تاجر. استخدم رقماً آخر.');
  }

  return {
    success: true,
    phone: phoneKey,
    fullName: fullName || null,
    role: 'customer',
  };
}

async function preRegisterMerchantAccount(adminPhone, payload = {}) {
  await assertAdminAccess(adminPhone);

  const rawPhone = String(
    payload.merchantPhone ?? payload.phone ?? ''
  ).trim();
  if (!rawPhone) {
    throw new Error('رقم الهاتف مطلوب.');
  }

  const phoneKey = await resolvePhoneKey(rawPhone);
  const fullName = String(payload.fullName ?? payload.full_name ?? '').trim();
  const note = String(payload.note ?? payload.notes ?? '').trim();
  const isBazaarMember = Boolean(
    payload.isBazaarMember ?? payload.is_bazaar_member ?? false,
  );
  const serviceSubCategory = String(
    payload.serviceSubCategory ?? payload.service_sub_category ?? '',
  ).trim();

  let serviceIds = normalizeArray(payload.serviceIds ?? payload.service_ids);
  const primaryServiceId = String(
    payload.primaryServiceId ?? payload.primary_service_id ?? serviceIds[0] ?? ''
  ).trim();

  if (serviceIds.length === 0 && primaryServiceId) {
    serviceIds = [primaryServiceId];
  }
  if (serviceIds.length === 0) {
    throw new Error('يرجى اختيار قسم واحد على الأقل.');
  }

  for (const id of serviceIds) {
    if (!MERCHANT_SIGNUP_SERVICE_IDS.has(String(id).trim())) {
      throw new Error(`قسم غير صالح: ${id}`);
    }
  }

  const primary =
    primaryServiceId && serviceIds.includes(primaryServiceId)
      ? primaryServiceId
      : serviceIds[0];

  const existingUser = await getAppUser(phoneKey);
  if (existingUser && String(existingUser.role ?? '').trim() === 'admin') {
    throw new Error('لا يمكن تسجيل رقم المشرف كتاجر.');
  }

  const placeholderStoreName =
    fullName || `تاجر ${phoneKey.slice(-4)}`;

  const existingProfile = await getMerchantProfile(phoneKey);
  if (existingProfile) {
    const existingState = (await getUserState(phoneKey)) || {};
    if (existingState.merchantProfileComplete === true) {
      throw new Error('يوجد ملف تاجر مكتمل لهذا الرقم بالفعل.');
    }
    const storeName = String(existingProfile.store_name ?? '').trim();
    if (storeName && !existingState.adminPreRegisteredMerchant) {
      throw new Error('يوجد ملف تاجر مكتمل لهذا الرقم بالفعل.');
    }
  }

  if (!existingUser) {
    await saveAppUser(phoneKey, {
      role: 'merchant',
      account_type: 'marketplace',
      full_name: fullName || undefined,
    });
  } else {
    const patch = {};
    const existingName = String(existingUser.full_name ?? '').trim();
    if (fullName && !existingName) patch.full_name = fullName;
    if (!String(existingUser.account_type ?? '').trim()) {
      patch.account_type = 'marketplace';
    }
    if (Object.keys(patch).length > 0) {
      await saveAppUser(phoneKey, patch);
    }
  }

  await saveMerchantProfile(phoneKey, {
    store_name: placeholderStoreName,
    primary_service_id: primary,
    service_ids: serviceIds,
    active_service_id: primary,
    is_approved: true,
    approval_status: 'approved',
    is_open: true,
    is_bazaar_member: isBazaarMember,
    admin_pre_registered: true,
    _adminModerationBypass: true,
    description: note || undefined,
    service_sub_category: serviceSubCategory || undefined,
  });

  if (isBazaarMember) {
    try {
      await syncMerchantProductsForBazaar(phoneKey);
    } catch (syncError) {
      console.error('bazaar sync on pre-register error:', syncError?.message || syncError);
    }
  }

  const merchantStoreStub = {
    category: primary,
    serviceIds,
    service_ids: serviceIds,
    activeServiceId: primary,
    active_service_id: primary,
    primary_service_id: primary,
    isApproved: true,
    approvalStatus: 'approved',
    adminPreRegistered: true,
    admin_pre_registered: true,
    name: placeholderStoreName,
    store_name: placeholderStoreName,
  };

  const merchantState = (await getUserState(phoneKey)) || {};
  await saveUserState(phoneKey, {
    ...merchantState,
    userRole: merchantState.userRole || merchantState.user_role || 'merchant',
    user_role: merchantState.user_role || merchantState.userRole || 'merchant',
    merchantProfileComplete: false,
    merchantStore: merchantStoreStub,
    adminPreRegisteredMerchant: true,
    adminPreRegisteredAt: nowIso(),
    adminPreRegisteredBy: adminPhone,
    multiRoleAccount: true,
  });

  const refreshed = await getMerchantProfile(phoneKey);
  const user = await getAppUser(phoneKey);

  return {
    success: true,
    phone: phoneKey,
    fullName: String(user?.full_name ?? fullName ?? '').trim(),
    primaryServiceId: primary,
    serviceIds,
    isApproved: true,
    approvalStatus: 'approved',
    merchantProfileComplete: false,
    storeName: String(refreshed?.store_name ?? '').trim(),
    isBazaarMember,
    serviceSubCategory: serviceSubCategory || null,
  };
}

async function updateMerchantCategoryByAdmin(adminPhone, payload = {}) {
  await assertAdminAccess(adminPhone);

  const rawPhone = String(payload.merchantPhone ?? payload.phone ?? '').trim();
  if (!rawPhone) {
    throw new Error('رقم الهاتف مطلوب.');
  }

  const phoneKey = await resolvePhoneKey(rawPhone);
  const profile = await getMerchantProfile(phoneKey);
  if (!profile) {
    throw new Error('التاجر غير موجود.');
  }

  const primaryServiceId = String(
    payload.primaryServiceId ?? payload.primary_service_id ?? '',
  ).trim();
  if (!primaryServiceId) {
    throw new Error('يرجى اختيار القسم الجديد.');
  }
  if (!MERCHANT_SIGNUP_SERVICE_IDS.has(primaryServiceId)) {
    throw new Error(`قسم غير صالح: ${primaryServiceId}`);
  }

  let serviceIds = normalizeArray(payload.serviceIds ?? payload.service_ids);
  if (serviceIds.length === 0) {
    serviceIds = [primaryServiceId];
  }
  for (const id of serviceIds) {
    if (!MERCHANT_SIGNUP_SERVICE_IDS.has(String(id).trim())) {
      throw new Error(`قسم غير صالح: ${id}`);
    }
  }
  if (!serviceIds.includes(primaryServiceId)) {
    serviceIds = [primaryServiceId, ...serviceIds.filter((id) => id !== primaryServiceId)];
  }

  const serviceSubCategory = String(
    payload.serviceSubCategory ?? payload.service_sub_category ?? '',
  ).trim();
  const isBazaarMember = payload.isBazaarMember ?? payload.is_bazaar_member;

  const profilePatch = {
    primary_service_id: primaryServiceId,
    service_ids: serviceIds,
    active_service_id: primaryServiceId,
    _adminModerationBypass: true,
  };
  if (serviceSubCategory) {
    profilePatch.service_sub_category = serviceSubCategory;
  } else if (primaryServiceId !== 'beauty') {
    profilePatch.service_sub_category = null;
  }
  if (isBazaarMember !== undefined) {
    profilePatch.is_bazaar_member = Boolean(isBazaarMember);
  }

  await saveMerchantProfile(phoneKey, profilePatch);

  if (Boolean(isBazaarMember)) {
    try {
      await syncMerchantProductsForBazaar(phoneKey);
    } catch (syncError) {
      console.error('bazaar sync on category update error:', syncError?.message || syncError);
    }
  }

  const merchantState = (await getUserState(phoneKey)) || {};
  const merchantStore = normalizeObject(merchantState.merchantStore);
  merchantStore.category = primaryServiceId;
  merchantStore.primary_service_id = primaryServiceId;
  merchantStore.primaryServiceId = primaryServiceId;
  merchantStore.active_service_id = primaryServiceId;
  merchantStore.activeServiceId = primaryServiceId;
  merchantStore.service_ids = serviceIds;
  merchantStore.serviceIds = serviceIds;
  if (primaryServiceId === 'beauty') {
    if (serviceSubCategory) {
      merchantStore.serviceSubCategory = serviceSubCategory;
      merchantStore.service_sub_category = serviceSubCategory;
    }
  } else if (serviceSubCategory) {
    merchantStore.serviceSubCategory = serviceSubCategory;
    merchantStore.service_sub_category = serviceSubCategory;
  } else {
    delete merchantStore.serviceSubCategory;
    delete merchantStore.service_sub_category;
    delete merchantStore.subCategoryId;
  }

  await saveUserState(phoneKey, {
    ...merchantState,
    merchantStore,
    multiRoleAccount: true,
  });

  const refreshed = await getMerchantProfile(phoneKey);
  return {
    success: true,
    phone: phoneKey,
    primaryServiceId,
    serviceIds,
    serviceSubCategory: serviceSubCategory || null,
    isBazaarMember: refreshed?.is_bazaar_member === true,
    storeName: String(refreshed?.store_name ?? '').trim(),
  };
}

async function preRegisterDriverAccount(adminPhone, payload = {}) {
  await assertAdminAccess(adminPhone);

  const rawPhone = String(payload.driverPhone ?? payload.phone ?? '').trim();
  if (!rawPhone) {
    throw new Error('رقم الهاتف مطلوب.');
  }

  const fullName = String(payload.fullName ?? payload.full_name ?? '').trim();
  if (!fullName) {
    throw new Error('اسم السائق مطلوب.');
  }

  const note = String(payload.note ?? payload.notes ?? '').trim();
  const phoneKey = await resolvePhoneKey(rawPhone);

  const existingUser = await getAppUser(phoneKey);
  if (existingUser && String(existingUser.role ?? '').trim() === 'admin') {
    throw new Error('لا يمكن تسجيل رقم المشرف كسائق.');
  }

  const existingState = (await getUserState(phoneKey)) || {};
  const existingDriver = await getDriverProfile(phoneKey);
  if (
    existingDriver &&
    isDriverProfileComplete(existingDriver) &&
    !existingState.adminPreRegisteredDriver
  ) {
    throw new Error('يوجد ملف سائق مكتمل لهذا الرقم بالفعل.');
  }

  if (!existingUser) {
    await saveAppUser(phoneKey, {
      role: 'customer',
      account_type: 'marketplace',
      full_name: fullName,
    });
  } else {
    const existingName = String(existingUser.full_name ?? '').trim();
    if (!existingName && fullName) {
      await saveAppUser(phoneKey, { full_name: fullName });
    }
  }

  const savedProfile = await saveDriverProfile(phoneKey, {
    name: fullName,
    phone: phoneKey,
    type: 'taxi',
    services: { taxi: true, delivery: false },
    isApproved: true,
    approvalStatus: 'approved',
    available: false,
    adminPreRegistered: true,
    adminNote: note || undefined,
  });

  await saveUserState(phoneKey, {
    ...existingState,
    driverProfile: savedProfile,
    driverProfileComplete: false,
    adminPreRegisteredDriver: true,
    adminPreRegisteredAt: nowIso(),
    adminPreRegisteredBy: adminPhone,
    multiRoleAccount: true,
  });

  const user = await getAppUser(phoneKey);

  return {
    success: true,
    phone: phoneKey,
    fullName: String(user?.full_name ?? fullName).trim(),
    isApproved: true,
    approvalStatus: 'approved',
    driverProfileComplete: false,
  };
}

async function preRegisterCourierAccount(adminPhone, payload = {}) {
  await assertAdminAccess(adminPhone);

  const rawPhone = String(payload.courierPhone ?? payload.phone ?? '').trim();
  if (!rawPhone) {
    throw new Error('رقم الهاتف مطلوب.');
  }

  const fullName = String(payload.fullName ?? payload.full_name ?? '').trim();
  if (!fullName) {
    throw new Error('اسم المندوب مطلوب.');
  }

  const note = String(payload.note ?? payload.notes ?? '').trim();
  const phoneKey = await resolvePhoneKey(rawPhone);

  const existingUser = await getAppUser(phoneKey);
  if (existingUser && String(existingUser.role ?? '').trim() === 'admin') {
    throw new Error('لا يمكن تسجيل رقم المشرف كمندوب.');
  }

  const existingState = (await getUserState(phoneKey)) || {};
  const existingCourier = await getCourierProfile(phoneKey);
  if (
    existingCourier &&
    isCourierProfileComplete(existingCourier) &&
    existingState.courierProfileComplete === true &&
    !existingState.adminPreRegisteredCourier
  ) {
    throw new Error('يوجد ملف مندوب مكتمل لهذا الرقم بالفعل.');
  }

  if (!existingUser) {
    await saveAppUser(phoneKey, {
      role: 'customer',
      account_type: 'marketplace',
      full_name: fullName,
    });
  } else {
    const existingName = String(existingUser.full_name ?? '').trim();
    if (!existingName && fullName) {
      await saveAppUser(phoneKey, { full_name: fullName });
    }
  }

  const savedProfile = await saveCourierProfile(phoneKey, {
    name: fullName,
    phone: phoneKey,
    isApproved: true,
    approvalStatus: 'approved',
    available: false,
    adminPreRegistered: true,
    adminNote: note || undefined,
  });

  await saveUserState(phoneKey, {
    ...existingState,
    courierProfile: savedProfile,
    courierProfileComplete: false,
    adminPreRegisteredCourier: true,
    adminPreRegisteredAt: nowIso(),
    adminPreRegisteredBy: adminPhone,
    multiRoleAccount: true,
  });

  const user = await getAppUser(phoneKey);

  return {
    success: true,
    phone: phoneKey,
    fullName: String(user?.full_name ?? fullName).trim(),
    isApproved: true,
    approvalStatus: 'approved',
    courierProfileComplete: false,
  };
}

const PROFESSIONAL_CATEGORIES = new Set([
  'plumber', 'electrician', 'ac_tech', 'carpenter', 'cleaner',
  'blacksmith', 'painter', 'builder', 'cctv_tech', 'network_tech',
  'loading_worker', 'gardener', 'aluminum_glass', 'photography', 'wedding',
]);

const PROFESSIONAL_CATEGORY_NAMES = {
  plumber: { ar: 'سباك', en: 'Plumber' },
  electrician: { ar: 'كهربائي', en: 'Electrician' },
  ac_tech: { ar: 'فني تكييف', en: 'AC Technician' },
  carpenter: { ar: 'نجار', en: 'Carpenter' },
  cleaner: { ar: 'تنظيف منازل', en: 'Home Cleaner' },
  blacksmith: { ar: 'حداد', en: 'Blacksmith' },
  painter: { ar: 'صباغ', en: 'Painter' },
  builder: { ar: 'بناء', en: 'Builder' },
  cctv_tech: { ar: 'فني كاميرات مراقبة', en: 'CCTV Technician' },
  network_tech: { ar: 'فني إنترنت وشبكات', en: 'Network Technician' },
  loading_worker: { ar: 'عامل تحميل وتنزيل', en: 'Loading Worker' },
  gardener: { ar: 'عامل حدائق', en: 'Gardener' },
  aluminum_glass: { ar: 'فني ألمنيوم وزجاج', en: 'Aluminum & Glass' },
  photography: { ar: 'استوديوهات تصوير', en: 'Photography Studio' },
  wedding: { ar: 'تجهيز الأعراس والمناسبات', en: 'Wedding & Events' },
};

async function preRegisterProfessionalAccount(adminPhone, payload = {}) {
  await assertAdminAccess(adminPhone);

  const rawPhone = String(payload.professionalPhone ?? payload.phone ?? '').trim();
  if (!rawPhone) {
    throw new Error('رقم الهاتف مطلوب.');
  }

  const phoneKey = await resolvePhoneKey(rawPhone);
  const fullName = String(payload.fullName ?? payload.full_name ?? '').trim();
  if (!fullName) {
    throw new Error('اسم المهني مطلوب.');
  }

  const professionId = String(payload.professionId ?? payload.profession_id ?? '').trim();
  if (!professionId || !PROFESSIONAL_CATEGORIES.has(professionId)) {
    throw new Error('يرجى اختيار تخصص مهني صحيح.');
  }

  const catNames = PROFESSIONAL_CATEGORY_NAMES[professionId] || { ar: '', en: '' };
  const description = String(payload.description ?? '').trim();
  const address = String(payload.address ?? '').trim();
  const phone = String(payload.phone ?? payload.contactPhone ?? '').trim();
  const whatsapp = String(payload.whatsapp ?? '').trim();
  const openTime = String(payload.openTime ?? payload.open_time ?? '').trim();
  const closeTime = String(payload.closeTime ?? payload.close_time ?? '').trim();
  const profileImageUrl = String(payload.profileImageUrl ?? payload.profile_image_url ?? '').trim();
  const workSampleUrls = normalizeArray(payload.workSampleUrls ?? payload.work_sample_urls);

  const showPhone = payload.showPhoneToCustomers !== false;
  const showWhatsapp = payload.showWhatsAppToCustomers !== false;

  const existingUser = await getAppUser(phoneKey);
  if (existingUser && String(existingUser.role ?? '').trim() === 'admin') {
    throw new Error('لا يمكن تسجيل رقم المشرف كمهني.');
  }

  const existingProfileCheck = await getMerchantProfile(phoneKey);
  if (existingProfileCheck) {
    const existingState = (await getUserState(phoneKey)) || {};
    if (existingState.merchantProfileComplete === true) {
      throw new Error('يوجد ملف تاجر مكتمل لهذا الرقم بالفعل.');
    }
  }

  if (!existingUser) {
    await saveAppUser(phoneKey, {
      role: 'merchant',
      account_type: 'marketplace',
      full_name: fullName,
    });
  } else {
    const patch = {};
    const existingName = String(existingUser.full_name ?? '').trim();
    if (!existingName) patch.full_name = fullName;
    if (!String(existingUser.account_type ?? '').trim()) {
      patch.account_type = 'marketplace';
    }
    if (Object.keys(patch).length > 0) {
      await saveAppUser(phoneKey, patch);
    }
  }

  const professionalInfo = {
    name: fullName,
    address,
    phone,
    whatsapp,
    openTime,
    closeTime,
    professionId,
    professionNameAr: catNames.ar,
    professionNameEn: catNames.en,
    profileImageBase64: profileImageUrl,
    workSampleImagesBase64: workSampleUrls,
    contact_visibility: {
      show_phone_to_customers: showPhone,
      show_whatsapp_to_customers: showWhatsapp,
      showPhoneToCustomers: showPhone,
      showWhatsAppToCustomers: showWhatsapp,
    },
    contactVisibility: {
      showPhoneToCustomers: showPhone,
      showWhatsAppToCustomers: showWhatsapp,
    },
  };

  const existingProfile = await getMerchantProfile(phoneKey);
  const profilePayload = {
    store_name: fullName,
    primary_service_id: 'professionals',
    service_ids: ['professionals'],
    active_service_id: 'professionals',
    description: description || undefined,
    is_approved: true,
    approval_status: 'approved',
    is_open: true,
    admin_pre_registered: true,
    _adminModerationBypass: true,
    professional_info: professionalInfo,
    professional_category_id: professionId,
    // profile_image_base64 محذوفة عمداً — صورة المهني تخزن داخل professional_info فقط
  };

  if (existingProfile) {
    await saveMerchantProfile(phoneKey, profilePayload);
  } else {
    const supabase = assertSupabaseAdmin();

    // نحتاج user_id لأن merchant_profiles في الإنتاج عنده user_id NOT NULL
    const { data: appUser } = await supabase
      .from('app_users')
      .select('id')
      .eq('phone', phoneKey)
      .maybeSingle();

    const upsertPayload = { phone: phoneKey, ...profilePayload, updated_at: nowIso() };
    if (appUser?.id) upsertPayload.user_id = appUser.id;

    const { error: upsertErr } = await supabase
      .from('merchant_profiles')
      .upsert(upsertPayload, { onConflict: 'phone' })
      .select();

    if (upsertErr) throw upsertErr;
  }

  const merchantStoreStub = {
    category: 'professionals',
    serviceIds: ['professionals'],
    service_ids: ['professionals'],
    activeServiceId: 'professionals',
    active_service_id: 'professionals',
    primary_service_id: 'professionals',
    isApproved: true,
    approvalStatus: 'approved',
    adminPreRegistered: true,
    name: fullName,
    store_name: fullName,
    isProfessional: true,
    professionalCategoryId: professionId,
    professionalInfo,
  };

  const merchantState = (await getUserState(phoneKey)) || {};
  await saveUserState(phoneKey, {
    ...merchantState,
    userRole: merchantState.userRole || merchantState.user_role || 'merchant',
    user_role: merchantState.user_role || merchantState.userRole || 'merchant',
    merchantProfileComplete: false,
    merchantStore: merchantStoreStub,
    adminPreRegisteredMerchant: true,
    adminPreRegisteredAt: nowIso(),
    adminPreRegisteredBy: adminPhone,
    multiRoleAccount: true,
  });

  const refreshed = await getMerchantProfile(phoneKey);
  const user = await getAppUser(phoneKey);

  return {
    success: true,
    phone: phoneKey,
    fullName: String(user?.full_name ?? fullName).trim(),
    professionId,
    storeName: String(refreshed?.store_name ?? fullName).trim(),
    isApproved: true,
    approvalStatus: 'approved',
    merchantProfileComplete: false,
  };
}

const BEAUTY_SUB_CATEGORIES = new Set(['أطباء وعيادات', 'صيدلية']);

const {
  isValidDoctorSpecialty,
} = require('../constants/doctor_specialties');

const BEAUTY_SUB_CATEGORY_NAMES = {
  'أطباء وعيادات': { ar: 'أطباء وعيادات', en: 'Doctors & Clinics' },
  'صيدلية': { ar: 'صيدلية', en: 'Pharmacy' },
};

async function preRegisterBeautyAccount(adminPhone, payload = {}) {
  await assertAdminAccess(adminPhone);

  const rawPhone = String(payload.subscriberPhone ?? payload.phone ?? '').trim();
  if (!rawPhone) throw new Error('رقم الهاتف مطلوب.');

  const phoneKey = await resolvePhoneKey(rawPhone);
  const fullName = String(payload.fullName ?? payload.full_name ?? '').trim();
  if (!fullName) throw new Error('الاسم مطلوب.');

  const subCategoryId = String(payload.subCategoryId ?? payload.sub_category_id ?? '').trim();
  if (!subCategoryId || !BEAUTY_SUB_CATEGORIES.has(subCategoryId)) {
    throw new Error('يرجى اختيار تصنيف صحيح (طبيب/صيدلية).');
  }

  const catNames = BEAUTY_SUB_CATEGORY_NAMES[subCategoryId] || { ar: '', en: '' };
  const description = String(payload.description ?? '').trim();
  const address = String(payload.address ?? '').trim();
  const phone = String(payload.phone ?? payload.contactPhone ?? '').trim();
  const whatsapp = String(payload.whatsapp ?? '').trim();
  const specialty = String(payload.specialty ?? '').trim();
  const doctorPhone = String(payload.doctorPhone ?? payload.doctor_phone ?? '').trim();
  const clinicPhone = String(payload.clinicPhone ?? payload.clinic_phone ?? '').trim();
  if (subCategoryId === 'أطباء وعيادات') {
    if (!specialty) {
      throw new Error('يرجى اختيار التخصص الطبي.');
    }
    if (!isValidDoctorSpecialty(specialty)) {
      throw new Error('التخصص الطبي غير صالح.');
    }
  }
  const openTime = String(payload.openTime ?? payload.open_time ?? '').trim();
  const closeTime = String(payload.closeTime ?? payload.close_time ?? '').trim();
  const profileImageUrl = String(payload.profileImageUrl ?? payload.profile_image_url ?? '').trim();
  const clinicImageUrl = String(payload.clinicImageUrl ?? payload.clinic_image_url ?? '').trim();

  const existingUser = await getAppUser(phoneKey);
  if (existingUser && String(existingUser.role ?? '').trim() === 'admin') {
    throw new Error('لا يمكن تسجيل رقم المشرف.');
  }

  const existingProfile = await getMerchantProfile(phoneKey);
  if (existingProfile) {
    const existingState = (await getUserState(phoneKey)) || {};
    if (existingState.merchantProfileComplete === true) {
      throw new Error('يوجد ملف مكتمل لهذا الرقم بالفعل.');
    }
  }

  if (!existingUser) {
    await saveAppUser(phoneKey, {
      role: 'merchant',
      account_type: 'marketplace',
      full_name: fullName,
    });
  } else {
    const patch = {};
    const existingName = String(existingUser.full_name ?? '').trim();
    if (!existingName) patch.full_name = fullName;
    if (!String(existingUser.account_type ?? '').trim()) patch.account_type = 'marketplace';
    if (Object.keys(patch).length > 0) await saveAppUser(phoneKey, patch);
  }

  await saveMerchantProfile(phoneKey, {
    store_name: fullName,
    primary_service_id: 'beauty',
    service_ids: ['beauty'],
    active_service_id: 'beauty',
    is_approved: true,
    approval_status: 'approved',
    is_open: true,
    admin_pre_registered: true,
    _adminModerationBypass: true,
    address: address || undefined,
    whatsapp: whatsapp || undefined,
    open_time: openTime || undefined,
    close_time: closeTime || undefined,
    service_sub_category: subCategoryId,
    serviceSubCategory: subCategoryId,
    subCategoryId,
    doctor_phone: doctorPhone || undefined,
    clinic_phone: clinicPhone || undefined,
    profile_image_url: profileImageUrl || undefined,
    profileImageUrl: profileImageUrl || undefined,
    cover_image_url: clinicImageUrl || undefined,
    coverImageUrl: clinicImageUrl || undefined,
    logo_image_url: profileImageUrl || undefined,
    logoImageUrl: profileImageUrl || undefined,
    ...(subCategoryId === 'أطباء وعيادات' ? {
      professional_info: {
        specialty,
        doctorPhone: doctorPhone || undefined,
        clinicPhone: clinicPhone || undefined,
        profileImageUrl: profileImageUrl || undefined,
        clinicImageUrl: clinicImageUrl || undefined,
        description: description || fullName,
        openTime: openTime || undefined,
        closeTime: closeTime || undefined,
      },
    } : {}),
  });

  await saveMerchantProfile(phoneKey, {
    primary_service_id: 'beauty',
    service_ids: ['beauty'],
    active_service_id: 'beauty',
    service_sub_category: subCategoryId,
    serviceSubCategory: subCategoryId,
    subCategoryId,
    is_approved: true,
    approval_status: 'approved',
    is_open: true,
  });

  const merchantState = (await getUserState(phoneKey)) || {};
  await saveUserState(phoneKey, {
    ...merchantState,
    userRole: merchantState.userRole || merchantState.user_role || 'merchant',
    user_role: merchantState.user_role || merchantState.userRole || 'merchant',
    merchantProfileComplete: false,
    merchantStore: {
      category: 'beauty',
      serviceIds: ['beauty'],
      service_ids: ['beauty'],
      activeServiceId: 'beauty',
      active_service_id: 'beauty',
      primary_service_id: 'beauty',
      subCategoryId,
      sub_category_id: subCategoryId,
      serviceSubCategory: subCategoryId,
      service_sub_category: subCategoryId,
      isApproved: true,
      approvalStatus: 'approved',
      adminPreRegistered: true,
      name: fullName,
      store_name: fullName,
      description: description || undefined,
      address: address || undefined,
      phone: doctorPhone || phone || undefined,
      whatsapp: whatsapp || undefined,
      ...(subCategoryId === 'أطباء وعيادات' ? {
        specialty,
        doctorPhone: doctorPhone || undefined,
        clinicPhone: clinicPhone || undefined,
        profileImageUrl: profileImageUrl || undefined,
        clinicImageUrl: clinicImageUrl || undefined,
        openTime: openTime || undefined,
        closeTime: closeTime || undefined,
        professionalInfo: {
          specialty,
          doctorPhone: doctorPhone || undefined,
          clinicPhone: clinicPhone || undefined,
          profileImageUrl: profileImageUrl || undefined,
          clinicImageUrl: clinicImageUrl || undefined,
          description: description || fullName,
          openTime: openTime || undefined,
          closeTime: closeTime || undefined,
        },
      } : {
        phone: phone || undefined,
        profileImageUrl: profileImageUrl || undefined,
        clinicImageUrl: clinicImageUrl || undefined,
        openTime: openTime || undefined,
        closeTime: closeTime || undefined,
        professionalInfo: {
          phone: phone || undefined,
          profileImageUrl: profileImageUrl || undefined,
          clinicImageUrl: clinicImageUrl || undefined,
          openTime: openTime || undefined,
          closeTime: closeTime || undefined,
        },
      }),
    },
    adminPreRegisteredMerchant: true,
    adminPreRegisteredAt: nowIso(),
    adminPreRegisteredBy: adminPhone,
    multiRoleAccount: true,
  });

  return {
    success: true,
    phone: phoneKey,
    fullName,
    subCategoryId,
    storeName: fullName,
    isApproved: true,
    approvalStatus: 'approved',
    merchantProfileComplete: false,
  };
}

const DEFAULT_APP_UPDATE_POLICY = Object.freeze({
  minBuildNumber: 1,
  minVersionName: '1.0.0',
  latestBuildNumber: 0,
  latestVersionName: '',
  messageAr:
    'يجب تحديث التطبيق للمتابعة. الرجاء التحديث من المتجر للاستمرار في استخدام الغيث.',
  androidStoreUrl:
    'https://play.google.com/store/apps/details?id=com.alghaith.app',
  iosStoreUrl: 'https://apps.apple.com/app/id6776741811',
});

async function getPlatformSettingsState() {
  const row = await selectSingleByPhone('app_state', PLATFORM_SETTINGS_PHONE);
  return normalizeObject(row?.state);
}

async function savePlatformSettingsState(patch = {}) {
  const phoneKey = await resolvePhoneKey(PLATFORM_SETTINGS_PHONE);
  await ensureAppUser(phoneKey);
  const current = await getPlatformSettingsState();
  const next = { ...current, ...normalizeObject(patch) };
  await saveRow(
    'app_state',
    { phone: phoneKey, state: next, updated_at: nowIso() },
    'phone',
  );
  return next;
}

function readOptionalBool(value) {
  if (value === true) return true;
  if (value === false) return false;
  return null;
}

function normalizeHomeCategoryOverrides(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return {};
  const out = {};
  for (const [categoryId, value] of Object.entries(raw)) {
    const id = String(categoryId || '').trim();
    if (!id) continue;

    if (typeof value === 'boolean') {
      out[id] = { default: value };
      continue;
    }
    if (!value || typeof value !== 'object' || Array.isArray(value)) continue;

    const entry = {};
    for (const key of ['default', 'android', 'ios', 'web']) {
      const parsed = readOptionalBool(value[key]);
      if (parsed != null) entry[key] = parsed;
    }
    if (Object.keys(entry).length > 0) out[id] = entry;
  }
  return out;
}

function normalizeAppUpdatePolicy(raw = {}) {
  const source = normalizeObject(raw);
  const minBuildNumber = Number(
    source.minBuildNumber ?? source.min_build_number ?? DEFAULT_APP_UPDATE_POLICY.minBuildNumber,
  );
  const latestBuildNumber = Number(
    source.latestBuildNumber ??
      source.latest_build_number ??
      DEFAULT_APP_UPDATE_POLICY.latestBuildNumber,
  );

  return {
    minBuildNumber:
      Number.isFinite(minBuildNumber) && minBuildNumber >= 1
        ? Math.trunc(minBuildNumber)
        : DEFAULT_APP_UPDATE_POLICY.minBuildNumber,
    minVersionName:
      String(
        source.minVersionName ??
          source.min_version_name ??
          DEFAULT_APP_UPDATE_POLICY.minVersionName,
      ).trim() || DEFAULT_APP_UPDATE_POLICY.minVersionName,
    latestBuildNumber:
      Number.isFinite(latestBuildNumber) && latestBuildNumber >= 0
        ? Math.trunc(latestBuildNumber)
        : DEFAULT_APP_UPDATE_POLICY.latestBuildNumber,
    latestVersionName: String(
      source.latestVersionName ??
        source.latest_version_name ??
        DEFAULT_APP_UPDATE_POLICY.latestVersionName,
    ).trim(),
    messageAr:
      String(
        source.messageAr ?? source.message_ar ?? DEFAULT_APP_UPDATE_POLICY.messageAr,
      ).trim() || DEFAULT_APP_UPDATE_POLICY.messageAr,
    androidStoreUrl:
      String(
        source.androidStoreUrl ??
          source.android_store_url ??
          DEFAULT_APP_UPDATE_POLICY.androidStoreUrl,
      ).trim() || DEFAULT_APP_UPDATE_POLICY.androidStoreUrl,
    iosStoreUrl:
      String(
        source.iosStoreUrl ??
          source.ios_store_url ??
          DEFAULT_APP_UPDATE_POLICY.iosStoreUrl,
      ).trim() || DEFAULT_APP_UPDATE_POLICY.iosStoreUrl,
  };
}

async function getHomeCategoriesConfig() {
  const state = await getPlatformSettingsState();
  const stored = normalizeObject(
    state.homeCategories || state.home_category_overrides || {},
  );
  const overrides = normalizeHomeCategoryOverrides(stored.overrides || stored);
  const updatedAt =
    stored.updatedAt ||
    stored.updated_at ||
    state.homeCategoriesUpdatedAt ||
    null;
  return { overrides, updatedAt };
}

async function saveAdminHomeCategoriesConfig(phone, overrides) {
  await assertAdminAccess(phone);
  const normalized = normalizeHomeCategoryOverrides(overrides);
  const updatedAt = nowIso();
  await savePlatformSettingsState({
    homeCategories: {
      overrides: normalized,
      updatedAt,
    },
    homeCategoriesUpdatedAt: updatedAt,
  });
  try {
    const { invalidateCache } = require('../lib/response_cache');
    if (typeof invalidateCache === 'function') invalidateCache('app:home-categories');
  } catch (_) {}
  return { overrides: normalized, updatedAt };
}

async function getAppUpdatePolicy() {
  const state = await getPlatformSettingsState();
  const stored = normalizeObject(
    state.appUpdatePolicy || state.app_update_policy || {},
  );
  const { updatedAt, updated_at: updatedAtSnake, ...policyFields } = stored;
  const policy = normalizeAppUpdatePolicy({
    ...DEFAULT_APP_UPDATE_POLICY,
    ...policyFields,
  });
  return {
    ...policy,
    updatedAt:
      updatedAt ||
      updatedAtSnake ||
      state.appUpdatePolicyUpdatedAt ||
      null,
  };
}

async function saveAdminAppUpdatePolicy(phone, patch = {}) {
  await assertAdminAccess(phone);
  const current = await getAppUpdatePolicy();
  const { updatedAt: _ignored, ...currentPolicy } = current;
  const policy = normalizeAppUpdatePolicy({ ...currentPolicy, ...patch });
  const updatedAt = nowIso();
  await savePlatformSettingsState({
    appUpdatePolicy: {
      ...policy,
      updatedAt,
    },
    appUpdatePolicyUpdatedAt: updatedAt,
  });
  return { ...policy, updatedAt };
}

const DEFAULT_MAINTENANCE_POLICY = Object.freeze({
  enabled: false,
  messageAr:
    'المنصة قيد الصيانة حالياً. نعمل على تحسين الخدمة ونعود قريباً. شكراً لصبركم.',
  messageEn: 'The platform is under maintenance. We will be back soon.',
  allowAdminBypass: true,
});

function normalizeMaintenancePolicy(raw = {}) {
  const source = normalizeObject(raw);
  return {
    enabled: source.enabled === true || source.enabled === 'true' || source.enabled === 1,
    messageAr: String(
      source.messageAr ?? source.message_ar ?? DEFAULT_MAINTENANCE_POLICY.messageAr,
    ).trim() || DEFAULT_MAINTENANCE_POLICY.messageAr,
    messageEn: String(
      source.messageEn ?? source.message_en ?? DEFAULT_MAINTENANCE_POLICY.messageEn,
    ).trim() || DEFAULT_MAINTENANCE_POLICY.messageEn,
    allowAdminBypass:
      source.allowAdminBypass !== false &&
      source.allow_admin_bypass !== false &&
      source.allowAdminBypass !== 'false' &&
      source.allow_admin_bypass !== 'false',
  };
}

async function getMaintenancePolicy() {
  const state = await getPlatformSettingsState();
  const stored = normalizeObject(
    state.maintenancePolicy || state.maintenance_policy || {},
  );
  const { updatedAt, updated_at: updatedAtSnake, ...policyFields } = stored;
  const policy = normalizeMaintenancePolicy({
    ...DEFAULT_MAINTENANCE_POLICY,
    ...policyFields,
  });
  return {
    ...policy,
    updatedAt:
      updatedAt ||
      updatedAtSnake ||
      state.maintenancePolicyUpdatedAt ||
      null,
  };
}

async function saveAdminMaintenancePolicy(phone, patch = {}) {
  await assertAdminAccess(phone);
  const current = await getMaintenancePolicy();
  const { updatedAt: _ignored, ...currentPolicy } = current;
  const policy = normalizeMaintenancePolicy({ ...currentPolicy, ...patch });
  const updatedAt = nowIso();
  await savePlatformSettingsState({
    maintenancePolicy: {
      ...policy,
      updatedAt,
    },
    maintenancePolicyUpdatedAt: updatedAt,
  });
  return { ...policy, updatedAt };
}

async function getPendingProductsForAdmin(adminPhone, filters = {}) {
  await assertAdminAccess(adminPhone);

  const categoryFilter = String(filters.category || '').trim();
  const products = await selectMany(
    'merchant_products',
    [],
    { column: 'created_at', ascending: false },
    3000
  );

  const pending = products.filter((row) => !isProductApproved(row));
  const scoped = categoryFilter
    ? pending.filter((row) => String(row.category || '').trim() === categoryFilter)
    : pending;

  const phones = [...new Set(scoped.map((row) => String(row.phone || '').trim()).filter(Boolean))];
  const profileByPhone = new Map();
  for (const phone of phones) {
    const profile = await getMerchantProfile(phone);
    if (profile) profileByPhone.set(phone, profile);
  }

  return scoped.map((row) => {
    const phone = String(row.phone || '').trim();
    const profile = profileByPhone.get(phone) || null;
    const serialized = serializeProductRowForClient(row);
    return {
      ...serialized,
      isApproved: isProductApproved(row),
      is_approved: isProductApproved(row),
      approvalStatus: productApprovalStatus(row),
      approval_status: productApprovalStatus(row),
      merchantPhone: phone,
      merchantStoreName: merchantProfileDisplayName(profile),
      merchantCategory: String(profile?.primary_service_id || profile?.primaryServiceId || '').trim(),
      rejectionMessageAr: String(row.rejection_message_ar || '').trim(),
    };
  });
}

async function toggleProductApprovalStatus(
  adminPhone,
  merchantPhone,
  productId,
  isApproved,
  rejectionMessageAr = ''
) {
  await assertAdminAccess(adminPhone);

  const phoneKey = await resolvePhoneKey(merchantPhone);
  const id = String(productId || '').trim();
  if (!id) throw new Error('productId is required.');

  const existing = await selectSingle('merchant_products', 'id', id);
  if (!existing) throw new Error('Product not found.');
  if (String(existing.phone || '').trim() !== phoneKey) {
    throw new Error('Product does not belong to this merchant.');
  }

  const approved = Boolean(isApproved);
  const patch = {
    id,
    phone: phoneKey,
    updated_at: nowIso(),
  };

  if (await hasColumn('merchant_products', 'is_approved')) {
    patch.is_approved = approved;
  }
  if (await hasColumn('merchant_products', 'approval_status')) {
    patch.approval_status = approved ? 'approved' : 'rejected';
  }
  if (await hasColumn('merchant_products', 'rejection_message_ar')) {
    patch.rejection_message_ar = approved
      ? null
      : String(rejectionMessageAr || 'تم رفض المحتوى من الإدارة.').trim();
  }
  if (await hasColumn('merchant_products', 'rejected_at')) {
    patch.rejected_at = approved ? null : nowIso();
  }

  const saved = await saveRow('merchant_products', patch, 'id');
  const productName = String(existing.name_ar ?? existing.nameAr ?? '').trim();

  try {
    if (approved) {
      const { onProductApproved } = require('../push_events');
      await onProductApproved(phoneKey, productName);
    } else {
      const { onProductRejected } = require('../push_events');
      await onProductRejected(
        phoneKey,
        String(rejectionMessageAr || 'تم رفض المحتوى من الإدارة.').trim(),
        productName
      );
    }
  } catch (error) {
    console.error('push product approval error:', error?.message || error);
  }

  return {
    success: true,
    product: serializeProductRowForClient(saved),
  };
}

module.exports = {
  getAdminReports,
  getAllMerchants,
  getAllProfessionals,
  getAllCouriers,
  getAllDrivers,
  getAdminMerchantDetails,
  getAdminProfessionalDetails,
  toggleBazaarMemberStatus,
  toggleCourierApprovalStatus,
  rejectCourierApplication,
  toggleMerchantApprovalStatus,
  rejectMerchantApplication,
  toggleMerchantFreezeStatus,
  updateAccountRole,
  isProtectedAdminAccount,
  toggleDriverApprovalStatus,
  rejectDriverApplication,
  resolveAccountApproval,
  classifyAdminAccountKind,
  accountDisplayName,
  resolveAccountSuspended,
  mapAdminAccountSummary,
  resolveRejectionMessage,
  getAllAdminAccounts,
  purgeAccountData,
  adminDeleteAccount,
  deleteDriverAccount,
  adminSuspendAccount,
  isPlatformAdminPhone,
  ensurePlatformAdminAccess,
  preRegisterMerchantAccount,
  updateMerchantCategoryByAdmin,
  preRegisterCustomerAccount,
  preRegisterDriverAccount,
  preRegisterCourierAccount,
  preRegisterProfessionalAccount,
  preRegisterBeautyAccount,
  PROFESSIONAL_CATEGORIES,
  PROFESSIONAL_CATEGORY_NAMES,
  getHomeCategoriesConfig,
  saveAdminHomeCategoriesConfig,
  getAppUpdatePolicy,
  saveAdminAppUpdatePolicy,
  getMaintenancePolicy,
  saveAdminMaintenancePolicy,
  getPendingProductsForAdmin,
  toggleProductApprovalStatus,
  mapAdminProductRow,
};
