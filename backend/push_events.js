const {
  getDeviceTokensForPhone,
  removeDeviceTokens,
  getActiveCourierPhones,
  getActiveDriverPhones,
  recordPushInboxDelivered,
} = require('./supabase_repo');
const { sendPushToTokens } = require('./push_notifications');

function displayOrderNumber(meta) {
  const raw = String(meta?.payload?.orderNumber ?? meta?.row?.order_number ?? '').trim();
  if (raw && raw.length <= 14) return raw;
  const idSeed = String(meta?.id ?? '').split('-')[0];
  const seed = Number.parseInt(idSeed, 10);
  if (!Number.isFinite(seed)) return raw || 'طلبك';
  return `#${String(seed % 1000000).padStart(6, '0')}`;
}

function noteText(meta) {
  return {
    ar: String(meta?.payload?.noteAr ?? '').trim(),
    en: String(meta?.payload?.noteEn ?? '').trim(),
  };
}

function isCustomerCancelledBeforeApproval(meta) {
  const { ar, en } = noteText(meta);
  return (
    en.includes('Cancelled by customer before merchant') ||
    ar.includes('ألغى الطلب من الزبون قبل موافقة')
  );
}

function isOrderRejected(meta) {
  if (meta.statusKey === 'rejected') return true;
  const { ar, en } = noteText(meta);
  return (
    en.includes('Rejected reason') ||
    ar.includes('سبب الرفض') ||
    String(meta?.payload?.statusEn ?? '').trim() === 'Rejected'
  );
}

function isTimeoutCancellation(meta) {
  const { ar, en } = noteText(meta);
  return en.toLowerCase().includes('timeout') || ar.includes('مهلة');
}

function isMerchantApprovedCancellation(meta) {
  const { ar, en } = noteText(meta);
  return (
    en.includes('Merchant approved cancellation') ||
    ar.includes('موافقة التاجر على إلغاء') ||
    ar.includes('تمت الموافقة على إلغاء')
  );
}

function isCustomerRejectedAdjustment(meta) {
  const { ar, en } = noteText(meta);
  return (
    ar.includes('رفض الزبون الطلب المعدّل') ||
    en.includes('Customer rejected adjusted order')
  );
}

function isCustomerApprovedAdjustment(meta) {
  const { ar, en } = noteText(meta);
  return (
    ar.includes('وافق الزبون على الطلب المعدّل') ||
    en.includes('Customer approved adjusted order')
  );
}

function isDeliveryPool(meta) {
  return (
    meta?.statusKey === 'delivering' &&
    meta?.deliveryStatusKey === 'waiting' &&
    !meta?.courierPhone
  );
}

function shouldTrackPushInbox(payload, options = {}) {
  if (options.skipInboxTracking) return false;
  const category = String(payload?.data?.category ?? '').trim();
  if (category === 'inbox_reminder') return false;
  const eventKey = String(payload?.data?.eventKey ?? '').trim();
  return !eventKey.includes(':unread_reminder');
}

async function sendPushToPhone(phone, payload, options = {}) {
  const normalizedPhone = String(phone || '').trim();
  if (!normalizedPhone) return;

  const rows = await getDeviceTokensForPhone(normalizedPhone);
  const tokens = rows.map((row) => row.token).filter(Boolean);
  if (!tokens.length) {
    const eventKey = String(payload?.data?.eventKey ?? '').trim();
    console.warn(
      `push: no device tokens for phone=${normalizedPhone}${eventKey ? ` event=${eventKey}` : ''}`
    );
    return;
  }

  const showSystemBanner =
    options.showSystemBanner === true ||
    String(payload?.data?.category ?? '').trim() === 'account';
  const result = await sendPushToTokens(tokens, { ...payload, showSystemBanner });
  if (result.invalidTokens?.length) {
    await removeDeviceTokens(result.invalidTokens);
  }

  if (result.sent > 0 && shouldTrackPushInbox(payload, options)) {
    try {
      await recordPushInboxDelivered(normalizedPhone);
    } catch (error) {
      console.error('push inbox track error:', error?.message || error);
    }
  }
}

async function notifyPhones(phones, payload) {
  const uniquePhones = [
    ...new Set((phones || []).map((item) => String(item || '').trim()).filter(Boolean)),
  ];
  await Promise.all(uniquePhones.map((phone) => sendPushToPhone(phone, payload)));
}

async function notifyActiveCouriers(payload, excludePhones = []) {
  const excluded = new Set(
    (excludePhones || []).map((item) => String(item || '').trim()).filter(Boolean)
  );
  const courierPhones = await getActiveCourierPhones();
  const targets = courierPhones.filter((phone) => !excluded.has(phone));
  await notifyPhones(targets, payload);
}

async function notifyActiveDrivers(payload, excludePhones = []) {
  const excluded = new Set(
    (excludePhones || []).map((item) => String(item || '').trim()).filter(Boolean)
  );
  const driverPhones = await getActiveDriverPhones();
  const targets = driverPhones.filter((phone) => !excluded.has(phone));
  await notifyPhones(targets, payload);
}

function displayTaxiRequestNumber(meta) {
  const raw = String(
    meta?.payload?.requestNumber ?? meta?.row?.request_number ?? ''
  ).trim();
  if (raw) return raw;
  const idSeed = String(meta?.id ?? '').split('-')[0];
  const seed = Number.parseInt(idSeed, 10);
  if (!Number.isFinite(seed)) return raw || 'طلب تكسي';
  return `TX-${String(seed % 1000000).padStart(6, '0')}`;
}

function isTaxiPool(meta) {
  const status = meta?.statusKey || '';
  return (status === 'pending' || status === 'new') && !meta?.driverPhone;
}

function buildPushPayload({ title, body, audience, orderId, eventKey, category = 'order' }) {
  return {
    title,
    body,
    data: {
      audience,
      orderId: orderId || '',
      eventKey: eventKey || '',
      category,
    },
  };
}

async function onOrderSaved({ previousMeta, nextMeta, isNew }) {
  if (!nextMeta) return;

  const orderId = nextMeta.id;
  const orderNumber = displayOrderNumber(nextMeta);
  const previousStatus = previousMeta?.statusKey || '';
  const nextStatus = nextMeta.statusKey || '';
  const previousDelivery = previousMeta?.deliveryStatusKey || '';
  const nextDelivery = nextMeta.deliveryStatusKey || '';
  const previousCourier = previousMeta?.courierPhone || '';
  const nextCourier = nextMeta.courierPhone || '';

  if (isNew && nextStatus === 'pending' && nextMeta.merchantPhone) {
    await sendPushToPhone(
      nextMeta.merchantPhone,
      buildPushPayload({
        title: 'طلب جديد',
        body: `لديك طلب جديد ${orderNumber}`,
        audience: 'merchant',
        orderId,
        eventKey: `merchant:${orderId}:new`,
      })
    );
    return;
  }

  if (!previousMeta) return;

  if (previousStatus !== nextStatus) {
    if (nextStatus === 'cancel_requested' && nextMeta.merchantPhone) {
      await sendPushToPhone(
        nextMeta.merchantPhone,
        buildPushPayload({
          title: 'طلب إلغاء من الزبون',
          body: `الزبون يطلب إلغاء الطلب ${orderNumber}`,
          audience: 'merchant',
          orderId,
          eventKey: `merchant:${orderId}:cancel_requested`,
        })
      );
    }

    if (
      previousStatus === 'pending' &&
      nextStatus === 'cancelled' &&
      isCustomerCancelledBeforeApproval(nextMeta) &&
      nextMeta.merchantPhone
    ) {
      await sendPushToPhone(
        nextMeta.merchantPhone,
        buildPushPayload({
          title: 'ألغى الزبون الطلب',
          body: `الزبون ألغى الطلب ${orderNumber} قبل القبول`,
          audience: 'merchant',
          orderId,
          eventKey: `merchant:${orderId}:customer_cancelled_pending`,
        })
      );
    }

    if (nextStatus === 'adjustment_pending' && nextMeta.customerPhone) {
      await sendPushToPhone(
        nextMeta.customerPhone,
        buildPushPayload({
          title: 'تعديل على طلبك',
          body: `التاجر عدّل الطلب ${orderNumber} — راجع ووافق أو ألغِ`,
          audience: 'customer',
          orderId,
          eventKey: `customer:${orderId}:adjustment_pending`,
        })
      );
    } else if (nextStatus === 'accepted' && nextMeta.customerPhone) {
      await sendPushToPhone(
        nextMeta.customerPhone,
        buildPushPayload({
          title: 'تم قبول طلبك',
          body: `الطلب ${orderNumber} قيد التجهيز`,
          audience: 'customer',
          orderId,
          eventKey: `customer:${orderId}:accepted`,
        })
      );
      if (
        previousStatus === 'adjustment_pending' &&
        nextMeta.merchantPhone
      ) {
        await sendPushToPhone(
          nextMeta.merchantPhone,
          buildPushPayload({
            title: 'وافق الزبون على التعديل',
            body: `الطلب ${orderNumber} قيد التجهيز`,
            audience: 'merchant',
            orderId,
            eventKey: `merchant:${orderId}:adjustment_accepted`,
          })
        );
      }
    } else if (nextStatus === 'preparing' && nextMeta.customerPhone) {
      await sendPushToPhone(
        nextMeta.customerPhone,
        buildPushPayload({
          title: 'طلبك قيد التحضير',
          body: `المتجر يجهّز طلبك ${orderNumber}`,
          audience: 'customer',
          orderId,
          eventKey: `customer:${orderId}:preparing`,
        })
      );
    } else if (
      previousStatus === 'cancel_requested' &&
      nextStatus !== 'cancel_requested' &&
      nextStatus !== 'cancelled' &&
      nextMeta.customerPhone
    ) {
      await sendPushToPhone(
        nextMeta.customerPhone,
        buildPushPayload({
          title: 'رفض التاجر إلغاء الطلب',
          body: `سيستمر تنفيذ طلبك ${orderNumber}`,
          audience: 'customer',
          orderId,
          eventKey: `customer:${orderId}:cancel_rejected`,
        })
      );
    } else if (
      previousStatus === 'cancel_requested' &&
      nextStatus === 'cancelled' &&
      isMerchantApprovedCancellation(nextMeta) &&
      nextMeta.customerPhone
    ) {
      await sendPushToPhone(
        nextMeta.customerPhone,
        buildPushPayload({
          title: 'تم إلغاء طلبك',
          body: `وافق التاجر على إلغاء الطلب ${orderNumber}`,
          audience: 'customer',
          orderId,
          eventKey: `customer:${orderId}:cancel_approved`,
        })
      );
    } else if (nextStatus === 'cancelled' && nextMeta.customerPhone) {
      if (isTimeoutCancellation(nextMeta)) {
        await sendPushToPhone(
          nextMeta.customerPhone,
          buildPushPayload({
            title: 'انتهت مهلة الطلب',
            body: `لم يرد التاجر خلال 20 دقيقة وأُلغي الطلب ${orderNumber}`,
            audience: 'customer',
            orderId,
            eventKey: `customer:${orderId}:timeout`,
          })
        );
      } else if (isOrderRejected(nextMeta)) {
        const { ar } = noteText(nextMeta);
        await sendPushToPhone(
          nextMeta.customerPhone,
          buildPushPayload({
            title: 'تم رفض طلبك',
            body: ar || `التاجر رفض الطلب ${orderNumber}`,
            audience: 'customer',
            orderId,
            eventKey: `customer:${orderId}:rejected`,
          })
        );
      } else if (
        previousStatus === 'adjustment_pending' &&
        isCustomerRejectedAdjustment(nextMeta) &&
        nextMeta.merchantPhone
      ) {
        await sendPushToPhone(
          nextMeta.merchantPhone,
          buildPushPayload({
            title: 'رفض الزبون التعديل',
            body: `ألغى الزبون الطلب ${orderNumber} بعد التعديل`,
            audience: 'merchant',
            orderId,
            eventKey: `merchant:${orderId}:adjustment_rejected`,
          })
        );
        if (nextMeta.customerPhone) {
          await sendPushToPhone(
            nextMeta.customerPhone,
            buildPushPayload({
              title: 'تم إلغاء الطلب',
              body: `ألغيت الطلب المعدّل ${orderNumber}`,
              audience: 'customer',
              orderId,
              eventKey: `customer:${orderId}:adjustment_rejected`,
            })
          );
        }
      } else if (!isMerchantApprovedCancellation(nextMeta)) {
        await sendPushToPhone(
          nextMeta.customerPhone,
          buildPushPayload({
            title: 'تم إلغاء الطلب',
            body: `الطلب ${orderNumber} أُلغي`,
            audience: 'customer',
            orderId,
            eventKey: `customer:${orderId}:cancelled`,
          })
        );
      }
    } else if (nextStatus === 'delivering' && nextMeta.customerPhone) {
      await sendPushToPhone(
        nextMeta.customerPhone,
        buildPushPayload({
          title: 'طلبك جاهز للتوصيل',
          body: `الطلب ${orderNumber} في انتظار مندوب التوصيل`,
          audience: 'customer',
          orderId,
          eventKey: `customer:${orderId}:delivering`,
        })
      );
    } else if (nextStatus === 'completed' && nextMeta.customerPhone) {
      await sendPushToPhone(
        nextMeta.customerPhone,
        buildPushPayload({
          title: 'تم إكمال الطلب',
          body: `الطلب ${orderNumber} اكتمل بنجاح`,
          audience: 'customer',
          orderId,
          eventKey: `customer:${orderId}:completed`,
        })
      );

      if (nextMeta.merchantPhone) {
        await sendPushToPhone(
          nextMeta.merchantPhone,
          buildPushPayload({
            title: 'اكتمل الطلب',
            body: `الطلب ${orderNumber} اكتمل`,
            audience: 'merchant',
            orderId,
            eventKey: `merchant:${orderId}:completed`,
          })
        );
      }
    }

    if (
      nextStatus === 'cancelled' &&
      previousStatus !== 'cancelled' &&
      previousCourier
    ) {
      await sendPushToPhone(
        previousCourier,
        buildPushPayload({
          title: 'تم إلغاء الطلب',
          body: `الطلب ${orderNumber} أُلغي بعد تعيينك`,
          audience: 'courier',
          orderId,
          eventKey: `courier:${orderId}:cancelled`,
        })
      );
    }
  }

  if (previousDelivery !== nextDelivery) {
    if (nextDelivery === 'accepted') {
      await notifyPhones(
        [nextMeta.customerPhone, nextMeta.merchantPhone],
        buildPushPayload({
          title: 'مندوب في الطريق',
          body: `تم تعيين مندوب لطلب ${orderNumber}`,
          audience: 'customer',
          orderId,
          eventKey: `shared:${orderId}:courier_accepted`,
        })
      );

      if (nextCourier) {
        await sendPushToPhone(
          nextCourier,
          buildPushPayload({
            title: 'تم قبول طلب التوصيل',
            body: `أنت المندوب المعيّن لطلب ${orderNumber}`,
            audience: 'courier',
            orderId,
            eventKey: `courier:${orderId}:accepted`,
          })
        );
      }
    } else if (nextDelivery === 'picked_up' && nextMeta.customerPhone) {
      await sendPushToPhone(
        nextMeta.customerPhone,
        buildPushPayload({
          title: 'تم استلام الطلب',
          body: `المندوب استلم طلبك ${orderNumber} من المتجر`,
          audience: 'customer',
          orderId,
          eventKey: `customer:${orderId}:picked_up`,
        })
      );

      if (nextMeta.merchantPhone) {
        await sendPushToPhone(
          nextMeta.merchantPhone,
          buildPushPayload({
            title: 'استلم المندوب الطلب',
            body: `المندوب استلم الطلب ${orderNumber} من متجرك`,
            audience: 'merchant',
            orderId,
            eventKey: `merchant:${orderId}:picked_up`,
          })
        );
      }
    } else if (nextDelivery === 'on_way' && nextMeta.customerPhone) {
      await sendPushToPhone(
        nextMeta.customerPhone,
        buildPushPayload({
          title: 'المندوب في الطريق إليك',
          body: `طلبك ${orderNumber} في الطريق`,
          audience: 'customer',
          orderId,
          eventKey: `customer:${orderId}:on_way`,
        })
      );
    } else if (nextDelivery === 'delivered') {
      if (nextMeta.customerPhone) {
        await sendPushToPhone(
          nextMeta.customerPhone,
          buildPushPayload({
            title: 'تم التسليم',
            body: `تم تسليم طلبك ${orderNumber}`,
            audience: 'customer',
            orderId,
            eventKey: `customer:${orderId}:delivered`,
          })
        );
      }

      if (nextMeta.merchantPhone) {
        await sendPushToPhone(
          nextMeta.merchantPhone,
          buildPushPayload({
            title: 'تم تسليم الطلب',
            body: `تم تسليم الطلب ${orderNumber} للزبون`,
            audience: 'merchant',
            orderId,
            eventKey: `merchant:${orderId}:delivered`,
          })
        );
      }
    }
  }

  const enteredPool = isDeliveryPool(nextMeta) && !isDeliveryPool(previousMeta);
  if (enteredPool) {
    await notifyActiveCouriers(
      buildPushPayload({
        title: 'طلب توصيل جديد',
        body: `طلب ${orderNumber} متاح للتوصيل الآن`,
        audience: 'courier',
        orderId,
        eventKey: `courier:${orderId}:pool_new`,
      }),
      nextMeta.payload?.rejectedByCouriers || []
    );
  }

  const returnedToPool =
    isDeliveryPool(nextMeta) &&
    isDeliveryPool(previousMeta) &&
    previousCourier &&
    !nextCourier;
  if (returnedToPool) {
    await notifyActiveCouriers(
      buildPushPayload({
        title: 'طلب عاد لقائمة التوصيل',
        body: `الطلب ${orderNumber} متاح مجدداً للمندوبين`,
        audience: 'courier',
        orderId,
        eventKey: `courier:${orderId}:pool_returned`,
      }),
      nextMeta.payload?.rejectedByCouriers || []
    );
  }
}

async function onTaxiRequestSaved({ previousMeta, nextMeta, isNew }) {
  if (!nextMeta) return;

  const requestId = nextMeta.id;
  const requestNumber = displayTaxiRequestNumber(nextMeta);
  const previousStatus = previousMeta?.statusKey || '';
  const nextStatus = nextMeta.statusKey || '';
  const previousDriver = previousMeta?.driverPhone || '';
  const nextDriver = nextMeta.driverPhone || '';

  // استخراج تفاصيل الرحلة من الـ payload
  const pickupAr = String(nextMeta.payload?.pickupAddressAr || nextMeta.payload?.pickupAddress || '').trim();
  const pickupEn = String(nextMeta.payload?.pickupAddressEn || nextMeta.payload?.pickupAddressEnglish || '').trim();
  const dropoffAr = String(nextMeta.payload?.dropoffAddressAr || nextMeta.payload?.dropoffAddress || '').trim();
  const dropoffEn = String(nextMeta.payload?.dropoffAddressEn || nextMeta.payload?.dropoffAddressEnglish || '').trim();
  const fare = Number(nextMeta.payload?.fare || 0);
  const rideTypeAr = String(nextMeta.payload?.rideTypeAr || '').trim();
  const customerName = String(nextMeta.payload?.customerNameAr || '').trim() || 'زبون الغيث';

  // بناء نص الإشعار بالعربية
  const bodyAr = [
    `🚕 طلب تكسي جديد #${requestNumber}`,
    pickupAr ? `📍 من: ${pickupAr}` : '',
    dropoffAr ? `🏁 إلى: ${dropoffAr}` : '',
    fare > 0 ? `💰 المبلغ: ${fare.toLocaleString('ar-IQ')} د.ع` : '',
    rideTypeAr ? `🚗 ${rideTypeAr}` : '',
  ].filter(Boolean).join('\n');

  // بناء نص الإشعار بالإنجليزية
  const bodyEn = [
    `🚕 New Taxi Request #${requestNumber}`,
    pickupEn ? `📍 From: ${pickupEn}` : pickupAr ? `📍 From: ${pickupAr}` : '',
    dropoffEn ? `🏁 To: ${dropoffEn}` : dropoffAr ? `🏁 To: ${dropoffAr}` : '',
    fare > 0 ? `💰 Fare: ${fare.toLocaleString('en-US')} IQD` : '',
  ].filter(Boolean).join('\n');

  // النص الأساسي في الإشعار (عربي لتطبيق عربي)
  const body = bodyAr || bodyEn || `طلب ${requestNumber} متاح للقبول الآن`;

  if (isNew && (nextStatus === 'pending' || nextStatus === 'new')) {
    await notifyActiveDrivers(
      buildPushPayload({
        title: '🚕 طلب تكسي جديد',
        body,
        audience: 'driver',
        orderId: requestId,
        eventKey: `driver:${requestId}:pool_new`,
        category: 'taxi',
      }),
      nextMeta.payload?.rejectedByDrivers || []
    );
    return;
  }

  if (!previousMeta) return;

  if (
    (previousStatus === 'pending' || previousStatus === 'new') &&
    nextStatus === 'accepted' &&
    nextMeta.customerPhone
  ) {
    const driverName =
      String(nextMeta.payload?.assignedDriverName ?? '').trim() || 'السائق';
    await sendPushToPhone(
      nextMeta.customerPhone,
      buildPushPayload({
        title: 'تم قبول طلب التكسي',
        body: `${driverName} قبل طلبك ${requestNumber}`,
        audience: 'customer',
        orderId: requestId,
        eventKey: `customer:${requestId}:accepted`,
        category: 'taxi',
      })
    );
  }

  if (previousStatus !== nextStatus && nextMeta.customerPhone) {
    if (nextStatus === 'on_way') {
      await sendPushToPhone(
        nextMeta.customerPhone,
        buildPushPayload({
          title: 'السائق في الطريق',
          body: `السائق متجه إليك — ${requestNumber}`,
          audience: 'customer',
          orderId: requestId,
          eventKey: `customer:${requestId}:on_way`,
          category: 'taxi',
        })
      );
    } else if (nextStatus === 'arrived') {
      await sendPushToPhone(
        nextMeta.customerPhone,
        buildPushPayload({
          title: 'وصل السائق',
          body: `السائق وصل لنقطة الانطلاق — ${requestNumber}`,
          audience: 'customer',
          orderId: requestId,
          eventKey: `customer:${requestId}:arrived`,
          category: 'taxi',
        })
      );
    } else if (nextStatus === 'picked_up') {
      await sendPushToPhone(
        nextMeta.customerPhone,
        buildPushPayload({
          title: 'بدأت الرحلة',
          body: `تم استلامك — ${requestNumber}`,
          audience: 'customer',
          orderId: requestId,
          eventKey: `customer:${requestId}:picked_up`,
          category: 'taxi',
        })
      );
    } else if (nextStatus === 'completed') {
      await sendPushToPhone(
        nextMeta.customerPhone,
        buildPushPayload({
          title: 'اكتملت الرحلة',
          body: `شكراً لاستخدامك الغيث — ${requestNumber}`,
          audience: 'customer',
          orderId: requestId,
          eventKey: `customer:${requestId}:completed`,
          category: 'taxi',
        })
      );
    } else if (nextStatus === 'cancel_requested' && nextDriver) {
      await sendPushToPhone(
        nextDriver,
        buildPushPayload({
          title: 'طلب إلغاء من الزبون',
          body: `الزبون يطلب إلغاء الرحلة ${requestNumber}`,
          audience: 'driver',
          orderId: requestId,
          eventKey: `driver:${requestId}:cancel_requested`,
          category: 'taxi',
        })
      );
    } else if (nextStatus === 'cancelled') {
      await sendPushToPhone(
        nextMeta.customerPhone,
        buildPushPayload({
          title: 'تم إلغاء الرحلة',
          body: `أُلغي طلب التكسي ${requestNumber}`,
          audience: 'customer',
          orderId: requestId,
          eventKey: `customer:${requestId}:cancelled`,
          category: 'taxi',
        })
      );
      if (nextDriver || previousDriver) {
        await sendPushToPhone(
          nextDriver || previousDriver,
          buildPushPayload({
            title: 'تم إلغاء الرحلة',
            body: `أُلغي طلب التكسي ${requestNumber}`,
            audience: 'driver',
            orderId: requestId,
            eventKey: `driver:${requestId}:cancelled`,
            category: 'taxi',
          })
        );
      }
    }
  }

  const enteredPool = isTaxiPool(nextMeta) && !isTaxiPool(previousMeta);
  if (enteredPool) {
    const poolBody = bodyAr || bodyEn || `طلب ${requestNumber} متاح للقبول الآن`;
    await notifyActiveDrivers(
      buildPushPayload({
        title: '🚕 طلب تكسي جديد',
        body: poolBody,
        audience: 'driver',
        orderId: requestId,
        eventKey: `driver:${requestId}:pool_new`,
        category: 'taxi',
      }),
      nextMeta.payload?.rejectedByDrivers || []
    );
  }

  const returnedToPool =
    isTaxiPool(nextMeta) &&
    isTaxiPool(previousMeta) &&
    previousDriver &&
    !nextDriver;
  if (returnedToPool) {
    const poolBody = bodyAr || bodyEn || `طلب ${requestNumber} متاح مجدداً للسائقين`;
    await notifyActiveDrivers(
      buildPushPayload({
        title: '🚕 طلب تكسي عاد للقائمة',
        body: poolBody,
        audience: 'driver',
        orderId: requestId,
        eventKey: `driver:${requestId}:pool_returned`,
        category: 'taxi',
      }),
      nextMeta.payload?.rejectedByDrivers || []
    );
  }
}

async function onCourierRejected(courierPhone, message, reasonKey = '') {
  const phone = String(courierPhone || '').trim();
  const body = String(message || '').trim();
  if (!phone || !body) return;

  await sendPushToPhone(
    phone,
    buildPushPayload({
      title: 'طلب المندوب يحتاج تعديلاً',
      body,
      audience: 'courier',
      orderId: '',
      eventKey: `courier:${phone}:rejected:${reasonKey || 'general'}`,
      category: 'account',
    })
  );
}

async function onCourierApproved(courierPhone) {
  const phone = String(courierPhone || '').trim();
  if (!phone) return;

  await sendPushToPhone(
    phone,
    buildPushPayload({
      title: 'تم تفعيل حساب المندوب',
      body: 'وافقت الإدارة على طلبك. يمكنك الآن استقبال طلبات التوصيل.',
      audience: 'courier',
      orderId: '',
      eventKey: `courier:${phone}:approved`,
      category: 'account',
    })
  );
}

async function onMerchantRejected(merchantPhone, message, reasonKey = '') {
  const phone = String(merchantPhone || '').trim();
  const body = String(message || '').trim();
  if (!phone || !body) return;

  await sendPushToPhone(
    phone,
    buildPushPayload({
      title: 'طلب التاجر يحتاج تعديلاً',
      body,
      audience: 'merchant',
      orderId: '',
      eventKey: `merchant:${phone}:rejected:${reasonKey || 'general'}`,
      category: 'account',
    })
  );
}

async function onMerchantApproved(merchantPhone) {
  const phone = String(merchantPhone || '').trim();
  if (!phone) return;

  await sendPushToPhone(
    phone,
    buildPushPayload({
      title: 'تم تفعيل حساب التاجر',
      body: 'وافقت الإدارة على طلبك. يمكنك الآن إدارة متجرك واستقبال الطلبات.',
      audience: 'merchant',
      orderId: '',
      eventKey: `merchant:${phone}:approved`,
      category: 'account',
    })
  );
}

async function onDriverRejected(driverPhone, message, reasonKey = '') {
  const phone = String(driverPhone || '').trim();
  const body = String(message || '').trim();
  if (!phone || !body) return;

  await sendPushToPhone(
    phone,
    buildPushPayload({
      title: 'طلب التكسي يحتاج تعديلاً',
      body,
      audience: 'driver',
      orderId: '',
      eventKey: `driver:${phone}:rejected:${reasonKey || 'general'}`,
      category: 'account',
    })
  );
}

async function onDriverApproved(driverPhone) {
  const phone = String(driverPhone || '').trim();
  if (!phone) return;

  await sendPushToPhone(
    phone,
    buildPushPayload({
      title: 'تم تفعيل حساب التكسي',
      body: 'وافقت الإدارة على طلبك. يمكنك الآن استقبال طلبات الركوب.',
      audience: 'driver',
      orderId: '',
      eventKey: `driver:${phone}:approved`,
      category: 'account',
    })
  );
}

async function onMerchantFrozen(merchantPhone, isFrozen) {
  if (!isFrozen) return;
  const phone = String(merchantPhone || '').trim();
  if (!phone) return;

  await sendPushToPhone(
    phone,
    buildPushPayload({
      title: 'تم تجميد حسابك',
      body: 'حساب المتجر مجمّد ولا يستقبل طلبات جديدة. تواصل مع الإدارة.',
      audience: 'merchant',
      orderId: '',
      eventKey: `merchant:${phone}:frozen`,
      category: 'account',
    })
  );
}

module.exports = {
  onOrderSaved,
  onTaxiRequestSaved,
  onCourierApproved,
  onCourierRejected,
  onMerchantApproved,
  onMerchantRejected,
  onDriverApproved,
  onDriverRejected,
  onMerchantFrozen,
  sendPushToPhone,
  notifyActiveCouriers,
  notifyActiveDrivers,
  buildPushPayload,
  displayOrderNumber,
};
