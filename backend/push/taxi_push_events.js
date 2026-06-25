/**
 * Taxi Push Events
 * 
 * دوال إرسال الإشعارات الخاصة بخدمة التكسي.
 */

const { sendPushToPhone } = require('../push_events');
const { getActiveDriverPhonesByTaxiType } = require('../supabase_repo/taxi');

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

/**
 * إرسال إشعار لأقرب 5 سائقين بوجود طلب تكسي جديد
 * 
 * @param {object} requestMeta - بيانات الطلب (تحتوي على requestId, pickupAddress, dropoffAddress, fare, distanceKm)
 * @param {object[]} nearbyDrivers - قائمة السائقين القريبين
 */
async function notifyNewTaxiRequest(requestMeta, nearbyDrivers = []) {
  const requestId = String(requestMeta?.id || requestMeta?.requestId || '').trim();
  if (!requestId) return;

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

  const driverPayload = {
    ...payload,
    data: {
      ...payload.data,
      audience: 'driver',
    },
  };

  const seenPhones = new Set();
  const targetDrivers = Array.isArray(nearbyDrivers) ? nearbyDrivers.slice(0, 5) : [];

  for (const driver of targetDrivers) {
    const phone = String(driver?.driverPhone || driver?.phone || '').trim();
    if (!phone || seenPhones.has(phone)) continue;
    seenPhones.add(phone);
    try {
      await sendPushToPhone(phone, driverPayload);
    } catch (error) {
      console.error(`taxi push notifyNewTaxiRequest error for ${phone}:`, error?.message || error);
    }
  }

  if (seenPhones.size > 0) return;

  const taxiType = String(requestMeta.taxiType || 'economic').trim();
  const fallbackPhones = await getActiveDriverPhonesByTaxiType(taxiType);
  for (const phone of fallbackPhones.slice(0, 5)) {
    const normalized = String(phone || '').trim();
    if (!normalized || seenPhones.has(normalized)) continue;
    seenPhones.add(normalized);
    try {
      await sendPushToPhone(normalized, driverPayload);
    } catch (error) {
      console.error(`taxi push notifyNewTaxiRequest fallback error for ${normalized}:`, error?.message || error);
    }
  }
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

  await sendPushToPhone(customerPhone, payload);
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
