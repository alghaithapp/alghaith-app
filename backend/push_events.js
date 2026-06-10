const { getDeviceTokensForPhone, removeDeviceTokens } = require('./supabase_repo');
const { sendPushToTokens } = require('./push_notifications');

function displayOrderNumber(meta) {
  const raw = String(meta?.payload?.orderNumber ?? meta?.row?.order_number ?? '').trim();
  if (raw && raw.length <= 14) return raw;
  const idSeed = String(meta?.id ?? '').split('-')[0];
  const seed = Number.parseInt(idSeed, 10);
  if (!Number.isFinite(seed)) return raw || 'طلبك';
  return `#${String(seed % 1000000).padStart(6, '0')}`;
}

async function sendPushToPhone(phone, payload) {
  const normalizedPhone = String(phone || '').trim();
  if (!normalizedPhone) return;

  const rows = await getDeviceTokensForPhone(normalizedPhone);
  const tokens = rows.map((row) => row.token).filter(Boolean);
  if (!tokens.length) return;

  const result = await sendPushToTokens(tokens, payload);
  if (result.invalidTokens?.length) {
    await removeDeviceTokens(result.invalidTokens);
  }
}

async function notifyPhones(phones, payload) {
  const uniquePhones = [...new Set((phones || []).map((item) => String(item || '').trim()).filter(Boolean))];
  await Promise.all(uniquePhones.map((phone) => sendPushToPhone(phone, payload)));
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
    if (nextStatus === 'accepted' && nextMeta.customerPhone) {
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
    } else if (nextStatus === 'cancelled' && nextMeta.customerPhone) {
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
          eventKey: `customer:${orderId}:courier_accepted`,
        })
      );
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
    } else if (nextDelivery === 'delivered' && nextMeta.customerPhone) {
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
  }
}

module.exports = {
  onOrderSaved,
  sendPushToPhone,
};
