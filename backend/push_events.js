const {
  getDeviceTokensForPhone,
  removeDeviceTokens,
  getActiveCourierPhones,
  getActiveDriverPhones,
  recordPushInboxDelivered,
} = require('./supabase_repo');
const { resolvePhoneKey } = require('./supabase_repo/common');
const { enqueuePushNotification } = require('./services/notification_queue');
const { sendPushToTokensDirect } = require('./services/notification_delivery');

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
  let phoneKey = String(phone || '').trim();
  if (!phoneKey) return { sent: 0, failed: 0, invalidTokens: [], reason: 'no_phone' };

  try {
    phoneKey = await resolvePhoneKey(phoneKey);
  } catch (_) {
    // keep trimmed input when phone is not in DB yet
  }

  const rows = await getDeviceTokensForPhone(phoneKey);
  const tokens = rows.map((row) => row.token).filter(Boolean);
  if (!tokens.length) {
    const eventKey = String(payload?.data?.eventKey ?? '').trim();
    console.warn(
      `push: no device tokens for phone=${phoneKey}${eventKey ? ` event=${eventKey}` : ''}`
    );
    return { sent: 0, failed: 0, invalidTokens: [], reason: 'no_tokens' };
  }

  const showSystemBanner =
    options.showSystemBanner === true ||
    String(payload?.data?.category ?? '').trim() === 'account' ||
    String(payload?.data?.category ?? '').trim() === 'call';

  if (options.immediate === true) {
    const result = await sendPushToTokensDirect(tokens, {
      title: payload?.title,
      body: payload?.body,
      data: payload?.data || {},
      showSystemBanner,
      dataOnly: options.dataOnly === true,
    });
    if (result.invalidTokens?.length) {
      await removeDeviceTokens(result.invalidTokens);
    }
    return { ...result, phoneKey, immediate: true };
  }

  const result = await enqueuePushNotification({
    tokens,
    title: payload?.title,
    body: payload?.body,
    data: payload?.data || {},
    targetPhone: phoneKey,
    audienceRole: String(payload?.data?.audience ?? 'customer').trim(),
    eventKey: String(payload?.data?.eventKey ?? '').trim(),
    showSystemBanner,
    skipInboxTracking: !shouldTrackPushInbox(payload, options),
  });
  if (result?.invalidTokens?.length) {
    await removeDeviceTokens(result.invalidTokens);
  }

  if (result?.sent > 0 && shouldTrackPushInbox(payload, options)) {
    try {
      await recordPushInboxDelivered(phoneKey);
    } catch (error) {
      console.error('push inbox track error:', error?.message || error);
    }
  }

  return { ...result, phoneKey };
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

async function notifyChatMessage(receiverPhone, customerMessage) {
  const messageType = String(
    customerMessage?.messageType || customerMessage?.message_type || 'text',
  ).trim();
  const rawContent = String(customerMessage?.content || customerMessage?.text || '').trim();
  let body = rawContent.substring(0, 100);
  if (messageType === 'sticker') {
    body = 'أرسل ملصقاً';
  } else if (messageType === 'call') {
    body = 'مكالمة صوتية';
  } else if (messageType === 'image') {
    body = 'أرسل صورة';
  }
  const customerName = String(customerMessage?.senderName || customerMessage?.customerName || customerMessage?.sender_name || 'مستخدم').trim();
  const threadType = String(customerMessage?.threadType || customerMessage?.thread_type || 'order').trim();
  const threadId = String(customerMessage?.threadId || customerMessage?.thread_id || customerMessage?.orderId || '').trim();

  await sendPushToPhone(
    receiverPhone,
    {
      title: `رسالة جديدة من ${customerName}`,
      body: body || 'وصلتك رسالة جديدة داخل التطبيق',
      data: {
        eventKey: 'chat:new',
        threadType,
        threadId,
        senderName: customerName,
        senderPhone: String(
          customerMessage?.senderPhone || customerMessage?.sender_phone || ''
        ).trim(),
        orderId: threadType === 'order' ? threadId : '',
        category: 'chat',
      },
    },
    { showSystemBanner: true }
  );
}

async function notifyIncomingCall(receiverPhone, callInfo) {
  const callerName = String(callInfo?.callerName || 'مستخدم').trim();
  const threadType = String(callInfo?.threadType || 'order').trim();
  const threadId = String(callInfo?.threadId || '').trim();
  const channelName = String(callInfo?.channelName || '').trim();
  const callerPhone = String(callInfo?.callerPhone || '').trim();
  const callLogId = String(callInfo?.callLogId || '').trim();

  const payload = {
    title: `مكالمة واردة من ${callerName}`,
    body: 'اضغط للرد على المكالمة داخل التطبيق',
    data: {
      eventKey: 'call:incoming',
      threadType,
      threadId,
      channelName,
      callerName,
      callerPhone,
      callLogId,
      orderId: threadType === 'order' ? threadId : '',
      category: 'call',
    },
  };

  // رسالة بيانات فقط — تصل للتطبيق المفتوح عبر onMessage دون الاعتماد على شريط النظام.
  let result = await sendPushToPhone(receiverPhone, payload, {
    immediate: true,
    skipInboxTracking: true,
    dataOnly: true,
  });

  if ((result?.sent || 0) === 0) {
    result = await sendPushToPhone(receiverPhone, payload, {
      immediate: true,
      skipInboxTracking: true,
    });
  } else {
    await sendPushToPhone(receiverPhone, payload, {
      immediate: true,
      skipInboxTracking: true,
    }).catch(() => {});
  }

  if ((result?.sent || 0) === 0 && result?.reason !== 'no_tokens' && result?.reason !== 'no_phone') {
    await new Promise((resolve) => setTimeout(resolve, 400));
    result = await sendPushToPhone(receiverPhone, payload, {
      immediate: true,
      skipInboxTracking: true,
    });
  }

  return result;
}

module.exports = {
  onOrderSaved,
  onCourierApproved,
  onCourierRejected,
  onMerchantApproved,
  onMerchantRejected,
  onDriverApproved,
  onDriverRejected,
  onMerchantFrozen,
  sendPushToPhone,
  notifyChatMessage,
  notifyIncomingCall,
  notifyActiveCouriers,
  notifyActiveDrivers,
  buildPushPayload,
  displayOrderNumber,
};
