/**
 * Taxi Push Events
 * 
 * دوال إرسال الإشعارات الخاصة بخدمة التكسي.
 */

const { sendPushToPhone } = require('../push_events');
const { getActiveDriverPhonesByTaxiType } = require('../supabase_repo/taxi');
const { getDeviceTokensForPhone, removeDeviceTokens } = require('../supabase_repo');
const { sendPushToTokensDirect } = require('../services/notification_delivery');

/**
 * بناء payload موحد للإشعارات
 */
function buildPushPayload({ title, body, data = {} }) {
  return {
    title,
    body,
    data: {
      category: 'taxi',
      ...data,
    },
  };
}

async function collectTokensForPhones(phones) {
  const uniquePhones = [...new Set(phones.map((p) => String(p || '').trim()).filter(Boolean))];
  if (uniquePhones.length === 0) return { tokens: [], phonesWithoutTokens: [] };

  const { getPhoneVariants } = require('../supabase_repo/common');
  const allVariants = uniquePhones.flatMap((phone) => getPhoneVariants(phone));
  const uniqueVariants = [...new Set(allVariants)];

  if (uniqueVariants.length === 0) return { tokens: [], phonesWithoutTokens: uniquePhones };

  try {
    const { selectMany } = require('../supabase_repo');
    const rows = await selectMany(
      'device_tokens',
      [{ method: 'in', column: 'phone', value: uniqueVariants }],
      { column: 'updated_at', ascending: false }
    );

    const tokens = [];
    const phonesWithoutTokens = [];

    const variantToTokens = {};
    for (const row of rows) {
      const token = String(row.token || '').trim();
      const phoneVal = String(row.phone || '').trim();
      if (token && phoneVal) {
        if (!variantToTokens[phoneVal]) variantToTokens[phoneVal] = [];
        variantToTokens[phoneVal].push(token);
      }
    }

    for (const phone of uniquePhones) {
      const variants = getPhoneVariants(phone);
      const phoneTokens = [];
      for (const variant of variants) {
        if (variantToTokens[variant]) {
          phoneTokens.push(...variantToTokens[variant]);
        }
      }
      if (phoneTokens.length === 0) {
        phonesWithoutTokens.push(phone);
      } else {
        tokens.push(...phoneTokens);
      }
    }

    return { tokens: [...new Set(tokens)], phonesWithoutTokens };
  } catch (error) {
    console.error('taxi batch push token lookup error:', error?.message || error);
    // Fallback to legacy loop if batch fails
    const results = await Promise.allSettled(
      uniquePhones.map(async (phone) => {
        const rows = await getDeviceTokensForPhone(phone);
        const phoneTokens = rows.map((row) => String(row.token || '').trim()).filter(Boolean);
        return { phone, tokens: phoneTokens };
      })
    );

    const tokens = [];
    const phonesWithoutTokens = [];
    for (const result of results) {
      if (result.status === 'fulfilled') {
        if (result.value.tokens.length === 0) {
          phonesWithoutTokens.push(result.value.phone);
        }
        tokens.push(...result.value.tokens);
      } else {
        phonesWithoutTokens.push('unknown');
      }
    }
    return { tokens: [...new Set(tokens)], phonesWithoutTokens };
  }
}

/**
 * إرسال إشعار لكل السائقين المتصلين من نفس النوع.
 * الأولوية للأقرب جغرافياً، ثم بقية السائقين المتصلين.
 */
async function notifyNewTaxiRequest(requestMeta, nearbyDrivers = []) {
  const requestId = String(requestMeta?.id || requestMeta?.requestId || '').trim();
  if (!requestId) return;

  const taxiTypeAr = { economic: 'تكسي', tuktuk: 'تكتك', wazz: 'واز' }[requestMeta.taxiType] || 'تكسي';

  const driverPayload = buildPushPayload({
    title: `🚕 طلب ${taxiTypeAr}`,
    body: 'لديك طلب خدمة توصيل، افتح التطبيق لعرض التفاصيل.',
    data: {
      audience: 'driver',
      eventKey: 'taxi:pool_new',
      orderId: requestId,
      requestId,
      pickupAddress: String(requestMeta.pickupAddress || '').trim(),
      dropoffAddress: String(requestMeta.dropoffAddress || '').trim(),
      fare: String(requestMeta.fare || '0'),
      distanceKm: String(requestMeta.distanceKm || '0'),
      taxiType: String(requestMeta.taxiType || 'economic').trim(),
    },
  });

  const taxiType = String(requestMeta.taxiType || 'economic').trim();
  const excludePhones = Array.isArray(requestMeta.excludePhones) ? requestMeta.excludePhones : [];
  const excludeSet = new Set(excludePhones.map((p) => String(p || '').trim()).filter(Boolean));
  const seenPhones = new Set(excludeSet);
  const orderedPhones = [];

  const nearbyList = Array.isArray(nearbyDrivers) ? nearbyDrivers : [];
  for (const driver of nearbyList) {
    const phone = String(driver?.driverPhone || driver?.phone || '').trim();
    if (!phone || seenPhones.has(phone)) continue;
    seenPhones.add(phone);
    orderedPhones.push(phone);
  }

  const activePhones = await getActiveDriverPhonesByTaxiType(taxiType);
  for (const phone of activePhones) {
    const normalized = String(phone || '').trim();
    if (!normalized || seenPhones.has(normalized)) continue;
    seenPhones.add(normalized);
    orderedPhones.push(normalized);
  }

  if (orderedPhones.length === 0) {
    for (const fallbackType of ['economic', 'tuktuk', 'wazz', 'super']) {
      if (fallbackType === taxiType) continue;
      const fallbackPhones = await getActiveDriverPhonesByTaxiType(fallbackType);
      for (const phone of fallbackPhones) {
        const normalized = String(phone || '').trim();
        if (!normalized || seenPhones.has(normalized)) continue;
        seenPhones.add(normalized);
        orderedPhones.push(normalized);
      }
    }
  }

  const maxTargets = 40;
  const targetPhones = orderedPhones.slice(0, maxTargets);
  const { tokens, phonesWithoutTokens } = await collectTokensForPhones(targetPhones);

  const result = await sendPushToTokensDirect(tokens, {
    title: driverPayload.title,
    body: driverPayload.body,
    data: driverPayload.data,
    showSystemBanner: true,
  });
  if (result.invalidTokens?.length) {
    await removeDeviceTokens(result.invalidTokens);
  }

  console.log('taxi push notifyNewTaxiRequest summary:', {
    requestId,
    taxiType,
    targets: targetPhones.length,
    tokenCount: [...new Set(tokens)].length,
    sent: Number(result?.sent || 0),
    failed: Number(result?.failed || 0),
    noTokens: phonesWithoutTokens.length,
    phonesWithoutTokens,
    targetPhones,
  });
}

/**
 * إرسال إشعار لسائق واحد محدد (بعد رفض سابق أو مطابقة تلقائية).
 * لا يبحث عن سائقين إضافيين  Avoids notifying all active drivers on rejection.
 */
async function notifySingleDriver(requestMeta, driverPhone) {
  const requestId = String(requestMeta?.id || requestMeta?.requestId || '').trim();
  const phone = String(driverPhone || '').trim();
  if (!requestId || !phone) return;

  const payload = buildPushPayload({
    title: '🚕 طلب تكسي جديد',
    body: `من: ${requestMeta.pickupAddress || 'غير محدد'} → إلى: ${requestMeta.dropoffAddress || 'غير محدد'}`,
    data: {
      audience: 'driver',
      eventKey: 'taxi:pool_new',
      orderId: requestId,
      requestId,
      pickupAddress: String(requestMeta.pickupAddress || '').trim(),
      dropoffAddress: String(requestMeta.dropoffAddress || '').trim(),
      fare: String(requestMeta.fare || '0'),
      distanceKm: String(requestMeta.distanceKm || '0'),
      taxiType: String(requestMeta.taxiType || 'economic').trim(),
    },
  });

  const { tokens } = await collectTokensForPhones([phone]);
  if (tokens.length === 0) return;

  const result = await sendPushToTokensDirect(tokens, {
    title: payload.title,
    body: payload.body,
    data: payload.data,
    showSystemBanner: true,
  });
  if (result.invalidTokens?.length) {
    await removeDeviceTokens(result.invalidTokens);
  }

  console.log('taxi push notifySingleDriver:', { requestId, driverPhone: phone, sent: result.sent });
}

/**
 * إشعار الزبون بقبول السائق
 */
async function notifyDriverAccepted(customerPhone, driverName, vehicleInfo) {
  if (!customerPhone) return;

  const payload = buildPushPayload({
    title: '✅ تم قبول طلبك',
    body: `السائق ${driverName || 'سائق'} في الطريق إليك`,
    data: {
      eventKey: 'taxi:driver_accepted',
      driverName: String(driverName || '').trim(),
      vehicleInfo: String(vehicleInfo || '').trim(),
    },
  });

  await sendPushToPhone(customerPhone, payload, { showSystemBanner: true, immediate: true });
}

/**
 * إشعار الزبون بوصول السائق
 */
async function notifyDriverArrived(customerPhone) {
  if (!customerPhone) return;

  const payload = buildPushPayload({
    title: '🚗 وصل السائق',
    body: 'السائق في مكان الالتقاء',
    data: {
      eventKey: 'taxi:driver_arrived',
    },
  });

  await sendPushToPhone(customerPhone, payload);
}

/**
 * إشعار الطرفين باكتمال الرحلة
 */
async function notifyTripCompleted(customerPhone, driverPhone, fare) {
  const payload = buildPushPayload({
    title: '✅ اكتملت الرحلة',
    body: `شكراً لك. الأجرة: ${Number(fare || 0).toLocaleString()} د.ع`,
    data: {
      eventKey: 'taxi:trip_completed',
      fare: String(fare || '0'),
    },
  });

  const targets = [customerPhone, driverPhone].filter(Boolean);
  for (const phone of targets) {
    try {
      await sendPushToPhone(phone, payload);
    } catch (error) {
      console.error(`taxi push notifyTripCompleted error for ${phone}:`, error?.message || error);
    }
  }
}

/**
 * إشعار السائق بأنه تم رفضه (لن يُستخدم حالياً ولكن للتوثيق)
 */
async function notifyDriverRejected(driverPhone) {
  if (!driverPhone) return;

  const payload = buildPushPayload({
    title: '❌ تم رفضك',
    body: 'عذراً، تم تعيين سائق آخر لهذا الطلب',
    data: {
      audience: 'driver',
      eventKey: 'taxi:driver_rejected',
    },
  });

  await sendPushToPhone(driverPhone, payload);
}

async function notifyCancelRequested(driverPhone, customerPhone) {
  if (!driverPhone) return;
  const payload = buildPushPayload({
    title: 'طلب إلغاء من الزبون',
    body: 'يرجى الموافقة أو رفض طلب الإلغاء',
    data: {
      audience: 'driver',
      eventKey: 'taxi:cancel_requested',
    },
  });
  await sendPushToPhone(driverPhone, payload);
}

async function notifyCancellationApproved(customerPhone) {
  if (!customerPhone) return;
  const payload = buildPushPayload({
    title: 'تم إلغاء الرحلة',
    body: 'وافق السائق على إلغاء الرحلة',
    data: { eventKey: 'taxi:cancel_approved' },
  });
  await sendPushToPhone(customerPhone, payload);
}

async function notifyCancellationRejected(customerPhone) {
  if (!customerPhone) return;
  const payload = buildPushPayload({
    title: 'استمرار الرحلة',
    body: 'رفض السائق طلب الإلغاء — الرحلة مستمرة',
    data: { eventKey: 'taxi:cancel_rejected' },
  });
  await sendPushToPhone(customerPhone, payload);
}

async function notifyTripCancelled(customerPhone, driverPhone) {
  const payload = buildPushPayload({
    title: 'تم إلغاء الرحلة',
    body: 'تم إلغاء طلب التكسي',
    data: { eventKey: 'taxi:cancelled' },
  });
  const targets = [customerPhone, driverPhone].filter(Boolean);
  for (const phone of targets) {
    await sendPushToPhone(phone, payload);
  }
}

async function notifyDriverApproaching(customerPhone, distanceMeters) {
  if (!customerPhone) return;
  const payload = buildPushPayload({
    title: '🚗 السائق يقترب',
    body: `السائق على بعد نحو ${distanceMeters} متر منك`,
    data: { eventKey: 'taxi:driver_approaching' },
  });
  await sendPushToPhone(customerPhone, payload);
}

async function notifyDriverLate(customerPhone, minutesLate) {
  if (!customerPhone) return;
  const payload = buildPushPayload({
    title: 'تأخر السائق',
    body: `نعتذر عن التأخير — السائق متأخر نحو ${minutesLate} دقيقة`,
    data: { eventKey: 'taxi:driver_late' },
  });
  await sendPushToPhone(customerPhone, payload);
}

module.exports = {
  notifyNewTaxiRequest,
  notifySingleDriver,
  notifyDriverAccepted,
  notifyDriverArrived,
  notifyTripCompleted,
  notifyDriverRejected,
  notifyCancelRequested,
  notifyCancellationApproved,
  notifyCancellationRejected,
  notifyTripCancelled,
  notifyDriverApproaching,
  notifyDriverLate,
};
