const {
  listAllCustomerOrders,
  readOrderMeta,
  saveCustomerOrder,
  listPushInboxStatesNeedingReminder,
  markPushInboxReminderSent,
  getDeviceTokensForPhone,
} = require('./supabase_repo');
const {
  sendPushToPhone,
  buildPushPayload,
  displayOrderNumber,
} = require('./push_events');

const PENDING_REMINDER_MS = 15 * 60 * 1000;
const PENDING_TIMEOUT_MS = 20 * 60 * 1000;
const RATING_REMINDER_MS = 30 * 60 * 1000;
const COURIER_PICKUP_REMINDER_MS = 20 * 60 * 1000;
const SCHEDULER_INTERVAL_MS = 60 * 1000;

let schedulerRunning = false;

function parseIso(value) {
  const raw = String(value || '').trim();
  if (!raw) return null;
  const date = new Date(raw);
  return Number.isNaN(date.getTime()) ? null : date;
}

function orderCreatedAt(meta) {
  return (
    parseIso(meta.payload?.createdAt) ||
    parseIso(meta.row?.created_at) ||
    parseIso(meta.row?.updated_at)
  );
}

function courierAcceptedAt(meta) {
  return parseIso(meta.payload?.courierAcceptedAt);
}

function deliveredAt(meta) {
  return parseIso(meta.payload?.deliveredAt) || parseIso(meta.row?.updated_at);
}

async function processPendingOrderReminders(nowMs) {
  const rows = await listAllCustomerOrders();
  for (const row of rows) {
    const meta = readOrderMeta(row);
    if (meta.statusKey !== 'pending' || !meta.merchantPhone) continue;

    const createdAt = orderCreatedAt(meta);
    if (!createdAt) continue;

    const ageMs = nowMs - createdAt.getTime();
    const orderNumber = displayOrderNumber(meta);

    if (ageMs >= PENDING_TIMEOUT_MS) {
      const nextOrder = {
        ...meta.payload,
        statusKey: 'cancelled',
        statusAr: 'ملغي تلقائيًا',
        statusEn: 'Auto cancelled',
        noteAr: 'انتهت مهلة قبول التاجر (20 دقيقة) وتم إلغاء الطلب تلقائيًا.',
        noteEn: 'Order cancelled automatically after 20 minutes timeout.',
      };
      await saveCustomerOrder(meta.customerPhone, {
        order: nextOrder,
        merchant_phone: meta.merchantPhone,
      });
      continue;
    }

    if (ageMs >= PENDING_REMINDER_MS && !meta.payload?.pushPendingReminderSentAt) {
      await sendPushToPhone(
        meta.merchantPhone,
        buildPushPayload({
          title: 'تذكير: طلب معلّق',
          body: `الطلب ${orderNumber} بانتظار موافقتك منذ 15 دقيقة`,
          audience: 'merchant',
          orderId: meta.id,
          eventKey: `merchant:${meta.id}:pending_reminder`,
        })
      );

      const nextOrder = {
        ...meta.payload,
        pushPendingReminderSentAt: new Date(nowMs).toISOString(),
      };
      await saveCustomerOrder(
        meta.customerPhone,
        {
          order: nextOrder,
          merchant_phone: meta.merchantPhone,
        },
        { skipPush: true }
      );
    }
  }
}

async function processRatingReminders(nowMs) {
  const rows = await listAllCustomerOrders();
  for (const row of rows) {
    const meta = readOrderMeta(row);
    if (!meta.customerPhone) continue;
    if (meta.payload?.isRated === true) continue;
    if (meta.payload?.pushRatingReminderSentAt) continue;

    const delivered =
      meta.deliveryStatusKey === 'delivered' ||
      meta.statusKey === 'completed' ||
      meta.payload?.deliveredAt;
    if (!delivered) continue;

    const deliveredTime = deliveredAt(meta);
    if (!deliveredTime) continue;
    if (nowMs - deliveredTime.getTime() < RATING_REMINDER_MS) continue;

    const orderNumber = displayOrderNumber(meta);
    await sendPushToPhone(
      meta.customerPhone,
      buildPushPayload({
        title: 'قيّم تجربتك',
        body: `كيف كانت تجربتك مع الطلب ${orderNumber}؟`,
        audience: 'customer',
        orderId: meta.id,
        eventKey: `customer:${meta.id}:rating_reminder`,
        category: 'engagement',
      })
    );

    const nextOrder = {
      ...meta.payload,
      pushRatingReminderSentAt: new Date(nowMs).toISOString(),
    };
    await saveCustomerOrder(
      meta.customerPhone,
      {
        order: nextOrder,
        merchant_phone: meta.merchantPhone || null,
        courier_phone: meta.courierPhone || null,
      },
      { skipPush: true }
    );
  }
}

async function processCourierPickupReminders(nowMs) {
  const rows = await listAllCustomerOrders();
  for (const row of rows) {
    const meta = readOrderMeta(row);
    if (meta.deliveryStatusKey !== 'accepted' || !meta.courierPhone) continue;
    if (meta.payload?.pushCourierPickupReminderSentAt) continue;

    const acceptedAt = courierAcceptedAt(meta) || parseIso(meta.row?.updated_at);
    if (!acceptedAt) continue;
    if (nowMs - acceptedAt.getTime() < COURIER_PICKUP_REMINDER_MS) continue;

    const orderNumber = displayOrderNumber(meta);
    await sendPushToPhone(
      meta.courierPhone,
      buildPushPayload({
        title: 'تذكير: استلم الطلب',
        body: `الطلب ${orderNumber} بانتظار الاستلام من المتجر`,
        audience: 'courier',
        orderId: meta.id,
        eventKey: `courier:${meta.id}:pickup_reminder`,
      })
    );

    const nextOrder = {
      ...meta.payload,
      pushCourierPickupReminderSentAt: new Date(nowMs).toISOString(),
    };
    await saveCustomerOrder(
      meta.customerPhone,
      {
        order: nextOrder,
        merchant_phone: meta.merchantPhone || null,
        courier_phone: meta.courierPhone,
      },
      { skipPush: true }
    );
  }
}

async function processUnreadInboxReminders() {
  const rows = await listPushInboxStatesNeedingReminder();
  for (const row of rows) {
    const phone = String(row.phone || '').trim();
    if (!phone) continue;

    const tokens = await getDeviceTokensForPhone(phone);
    if (!tokens.length) continue;

    const unreadCount = Number(row.unread_count || 0);
    const body =
      unreadCount <= 1
        ? 'لديك إشعار جديد لم تقرأه في الغيث'
        : `لديك ${unreadCount} إشعارات لم تقرأها في الغيث`;

    await sendPushToPhone(
      phone,
      buildPushPayload({
        title: 'تذكير: إشعارات الغيث',
        body,
        audience: 'user',
        orderId: '',
        eventKey: `inbox:${phone}:unread_reminder`,
        category: 'inbox_reminder',
      }),
      { skipInboxTracking: true }
    );

    await markPushInboxReminderSent(phone);
  }
}

async function runPushSchedulerTick() {
  if (schedulerRunning) return;
  schedulerRunning = true;
  try {
    const nowMs = Date.now();
    await processPendingOrderReminders(nowMs);
    await processRatingReminders(nowMs);
    await processCourierPickupReminders(nowMs);
    await processUnreadInboxReminders();
  } catch (error) {
    console.error('push scheduler error:', error?.message || error);
  } finally {
    schedulerRunning = false;
  }
}

function startPushScheduler() {
  setTimeout(() => {
    runPushSchedulerTick();
  }, 15 * 1000);
  setInterval(runPushSchedulerTick, SCHEDULER_INTERVAL_MS);
}

module.exports = {
  startPushScheduler,
  runPushSchedulerTick,
};
