const {
  assertSupabaseAdmin,
  nowIso,
  normalizeObject,
  getPhoneVariants,
  phonesOverlap,
  selectSingleByPhone,
  resolvePhoneKey,
  selectSingle,
  selectMany,
  hasColumn,
  saveRow,
} = require('./common');
const {
  ensureAppUser,
  getAppUser,
  getUserState,
  saveUserState,
} = require('./users');
const {
  getMerchantProfile,
  isMerchantFrozen,
  isMerchantApproved,
} = require('./merchants');

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
/**
 * تحويل صف الطلب الخام من قاعدة البيانات إلى كائن camelCase مُسطّح
 * لاستخدامه في نقاط API المخصصة للمستخدم (مثل /customer-orders بحيث
 * تكون الحقول camelCase على المستوى الأعلى بدلاً من داخل order_payload).
 */
function mapOrderRow(row) {
  const meta = readOrderMeta(row);
  const p = meta.payload || {};
  return {
    id: meta.id,
    phone: meta.customerPhone,
    orderNumber: p.orderNumber ?? row.order_number ?? '',
    statusKey: meta.statusKey || 'pending',
    statusAr: p.statusAr ?? '',
    statusEn: p.statusEn ?? '',
    deliveryStatusKey: meta.deliveryStatusKey || '',
    deliveryStatusAr: p.deliveryStatusAr ?? '',
    deliveryStatusEn: p.deliveryStatusEn ?? '',
    merchantPhone: meta.merchantPhone || '',
    courierPhone: meta.courierPhone || '',
    merchantStoreName: p.merchantStoreName ?? '',
    customerNameAr: p.customerNameAr ?? '',
    customerNameEn: p.customerNameEn ?? '',
    customerPhone: meta.customerPhone,
    items: Array.isArray(p.items) ? p.items : [],
    itemsNameAr: p.itemsNameAr ?? '',
    itemsNameEn: p.itemsNameEn ?? '',
    itemsCount: p.itemsCount ?? (Array.isArray(p.items) ? p.items.length : 0),
    price: Number(p.price ?? 0),
    originalPrice: Number(p.originalPrice ?? 0),
    itemsSubtotalIqd: Number(p.itemsSubtotalIqd ?? 0),
    deliveryFeeIqd: Number(p.deliveryFeeIqd ?? 0),
    promoDiscountIqd: Number(p.promoDiscountIqd ?? 0),
    deliveryFee: Number(p.deliveryFee ?? 0),
    noteAr: p.noteAr ?? '',
    noteEn: p.noteEn ?? '',
    rejectionReason: p.rejectionReason ?? '',
    rejectedAt: p.rejectedAt ?? null,
    completedAt: p.completedAt ?? null,
    deliveredAt: p.deliveredAt ?? null,
    isPriceLocked: p.isPriceLocked === true,
    assignedCourierName: p.assignedCourierName ?? '',
    codConfirmed: p.codConfirmed === true,
    latitude: p.latitude ?? null,
    longitude: p.longitude ?? null,
    address: p.address ?? '',
    area: p.area ?? '',
    createdAt: row.created_at ?? p.createdAt ?? null,
    updatedAt: row.updated_at ?? p.updatedAt ?? null,
  };
}
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

    const { data: allReviews, error: fetchError } = await supabase
      .from('merchant_reviews')
      .select('stars')
      .eq('merchant_phone', mPhone);

    if (!fetchError && allReviews.length > 0) {
      const totalStars = allReviews.reduce((sum, r) => sum + (Number(r.stars) || 0), 0);
      const avgRating = (totalStars / allReviews.length).toFixed(1);

      await supabase
        .from('merchant_profiles')
        .update({ rating: parseFloat(avgRating) })
        .eq('phone', mPhone);
    }

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
    return { success: false, error: error.message };
  }
}

module.exports = {
  listAllCustomerOrders,
  getCustomerOrders,
  saveCustomerOrder,
  readOrderMeta,
  mapOrderRow,
  isDeliveryPoolOrder,
  getDeliveryPoolOrders,
  getCourierAssignedOrders,
  acceptDeliveryOrder,
  updateCourierDeliveryStatus,
  rejectDeliveryOrder,
  getMerchantIncomingOrders,
  updateIncomingOrderStatus,
  saveMerchantReview,
};
