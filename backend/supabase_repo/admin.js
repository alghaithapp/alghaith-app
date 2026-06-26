const {
  nowIso,
  normalizeObject,
  getPhoneVariants,
  resolvePhoneKey,
  normalizeArray,
  selectMany,
  selectManyColumns,
  selectSingleByPhone,
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
  merchantRejectionMessage,
  MERCHANT_REJECTION_REASONS,
  mapMerchantApprovalFields,
  syncMerchantProductsForBazaar,
  updateMerchantApprovalRecord,
  evaluateBazaarCustomerVisibility,
  ensureMerchantProfileRecord,
  syncMissingMerchantProfilesFromAppState,
  saveMerchantProfile,
} = require('./merchants');
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
  getMerchantProducts,
  deleteMerchantProfile,
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

  const [orders, merchants, totalProducts, totalUsers, driverRows, courierRows] = await Promise.all([
    selectMany('customer_orders', [], { column: 'updated_at', ascending: false }, 100),
    selectMany('merchant_profiles', [], { column: 'store_name', ascending: true }, 500),
    supabase.from('merchant_products').select('*', { count: 'exact', head: true }).then((r) => r.count || 0),
    supabase.from('app_users').select('*', { count: 'exact', head: true }).then((r) => r.count || 0),
    supabase.from('driver_profiles').select('phone, display_name', { count: 'exact' }).then((r) => r.data || []),
    supabase.from('courier_profiles').select('phone, display_name', { count: 'exact' }).then((r) => r.data || []),
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

  let courierCount = 0;
  let driverCount = 0;
  for (const row of courierRows) {
    if (String(row.display_name || '').trim()) courierCount += 1;
  }
  for (const row of driverRows) {
    if (String(row.display_name || '').trim()) driverCount += 1;
  }

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

async function getAllMerchants(adminPhone) {
  await assertAdminAccess(adminPhone);
  await syncMissingMerchantProfilesFromAppState();

  const [merchants, orders, products] = await Promise.all([
    selectMany('merchant_profiles', [], { column: 'store_name', ascending: true }),
    // تحديث: نحدد عدد الطلبات إلى 500 لتقليل وقت التحميل مع الاحتفاظ بإحصائيات كافية
    selectMany('customer_orders', [], { column: 'updated_at', ascending: false }, 500),
    selectMany('merchant_products', [], { column: 'created_at', ascending: false }),
  ]);
  const userPhones = merchants.map((m) => m.phone).filter(Boolean);

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
      storeName:
        merchantProfileDisplayName(m) ||
        String(m.store_name || '').trim() ||
        String(userByPhone[m.phone]?.full_name || '').trim() ||
        `تاجر ${String(m.phone || '').slice(-4)}`,
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

async function getAllCouriers(adminPhone) {
  await assertAdminAccess(adminPhone);

  const [users, states] = await Promise.all([
    selectMany('app_users', [], { column: 'updated_at', ascending: false }, 3000),
    selectManyColumns(
      'app_state',
      'phone, state',
      [],
      { column: 'updated_at', ascending: false },
      2500
    ),
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

async function getAllDrivers(adminPhone) {
  await assertAdminAccess(adminPhone);

  const [users, states] = await Promise.all([
    selectMany('app_users', [], { column: 'updated_at', ascending: false }, 3000),
    selectManyColumns(
      'app_state',
      'phone, state',
      [],
      { column: 'updated_at', ascending: false },
      2500
    ),
  ]);

  const stateByPhone = {};
  for (const row of states) {
    const phone = String(row.phone || '').trim();
    if (!phone) continue;
    stateByPhone[phone] = row.state || {};
  }

  const drivers = [];
  const seen = new Set();

  for (const user of users) {
    const phone = String(user.phone || '').trim();
    if (!phone || seen.has(phone)) continue;

    const state = stateByPhone[phone] || {};
    const profile = readDriverProfileFromState(state);
    if (!profile || !isDriverProfileComplete(profile)) continue;

    const role = String(user.role ?? '').trim();
    const accountType = String(user.account_type ?? '').trim();
    const name = String(profile.name ?? '').trim();
    const isDriverAccount =
      role === 'driver' || accountType === 'driver' || name.length > 0;

    if (!isDriverAccount) continue;

    seen.add(phone);
    drivers.push(mapDriverForAdmin(phone, user, profile));
  }

  return drivers;
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
          const { onCourierApproved } = require('./push_events');
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
      const { onCourierApproved } = require('./push_events');
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
        const { onCourierRejected } = require('./push_events');
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
    const { onCourierRejected } = require('./push_events');
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
  await ensureMerchantProfileRecord(phoneKey);

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
        const { onMerchantFrozen } = require('./push_events');
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
    const { onMerchantFrozen } = require('./push_events');
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
          const { onDriverApproved } = require('./push_events');
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
      const { onDriverApproved } = require('./push_events');
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
        const { onDriverRejected } = require('./push_events');
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
    const { onDriverRejected } = require('./push_events');
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
  const approval = resolveAccountApproval(state, merchantProfile, kind);

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
    updatedAt: user?.updated_at ?? merchantProfile?.updated_at ?? null,
    createdAt: user?.created_at ?? merchantProfile?.created_at ?? null,
    hasMerchantProfile: Boolean(merchantProfile),
    hasCourierProfile: isCourierProfileComplete(courierProfile),
    hasDriverProfile: isDriverProfileComplete(driverProfile),
  };
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
  if (existingUser) {
    const accountType = String(existingUser.account_type ?? '').trim();
    if (accountType === 'delivery' || accountType === 'driver') {
      throw new Error(
        'هذا الرقم مرتبط بحساب مندوب أو سائق ولا يمكن تحويله لتاجر.'
      );
    }
    if (String(existingUser.role ?? '').trim() === 'admin') {
      throw new Error('لا يمكن تسجيل رقم المشرف كتاجر.');
    }
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

  await saveAppUser(phoneKey, {
    role: 'merchant',
    account_type: 'marketplace',
    full_name: fullName || undefined,
  });

  await saveMerchantProfile(phoneKey, {
    store_name: placeholderStoreName,
    primary_service_id: primary,
    service_ids: serviceIds,
    active_service_id: primary,
    is_approved: false,
    approval_status: 'pending',
    is_open: false,
    description: note || undefined,
  });

  const merchantStoreStub = {
    category: primary,
    serviceIds,
    service_ids: serviceIds,
    activeServiceId: primary,
    active_service_id: primary,
    primary_service_id: primary,
    isApproved: false,
    approvalStatus: 'pending',
    adminPreRegistered: true,
    name: placeholderStoreName,
    store_name: placeholderStoreName,
  };

  await saveUserState(phoneKey, {
    userRole: 'merchant',
    user_role: 'merchant',
    merchantProfileComplete: false,
    merchantStore: merchantStoreStub,
    adminPreRegisteredMerchant: true,
    adminPreRegisteredAt: nowIso(),
    adminPreRegisteredBy: adminPhone,
  });

  const refreshed = await getMerchantProfile(phoneKey);
  const user = await getAppUser(phoneKey);

  return {
    success: true,
    phone: phoneKey,
    fullName: String(user?.full_name ?? fullName ?? '').trim(),
    primaryServiceId: primary,
    serviceIds,
    isApproved: false,
    approvalStatus: 'pending',
    merchantProfileComplete: false,
    storeName: String(refreshed?.store_name ?? '').trim(),
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

module.exports = {
  getAdminReports,
  getAllMerchants,
  getAllCouriers,
  getAllDrivers,
  getAdminMerchantDetails,
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
  adminSuspendAccount,
  isPlatformAdminPhone,
  ensurePlatformAdminAccess,
  preRegisterMerchantAccount,
  getHomeCategoriesConfig,
  saveAdminHomeCategoriesConfig,
  getAppUpdatePolicy,
  saveAdminAppUpdatePolicy,
  getMaintenancePolicy,
  saveAdminMaintenancePolicy,
};
