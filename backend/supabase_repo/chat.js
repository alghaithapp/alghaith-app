const {
  assertSupabaseAdmin,
  selectSingle,
  selectMany,
  resolvePhoneKey,
  phonesOverlap,
  canonicalPhone,
  normalizeObject,
  PLATFORM_ADMIN_PHONES,
} = require('./common');
const { readTaxiMeta } = require('./taxi');

const SUPPORT_PLATFORM_PHONE = '+9647830889994';

function formatMessage(row) {
  return {
    id: row.id,
    thread_type: row.thread_type,
    thread_id: row.thread_id,
    order_id: row.thread_type === 'order' ? row.thread_id : null,
    sender_phone: row.sender_phone,
    receiver_phone: row.receiver_phone,
    sender_name: row.sender_name,
    message_type: row.message_type || 'text',
    content: row.content,
    created_at: row.created_at,
  };
}

async function assertCanAccessThread(threadType, threadId, requestPhone) {
  const phone = await resolvePhoneKey(requestPhone);
  const trimmedId = String(threadId || '').trim();
  if (!trimmedId) {
    throw new Error('Thread id is required.');
  }

  switch (threadType) {
    case 'order': {
      const row = await selectSingle('customer_orders', 'id', trimmedId);
      if (!row) throw new Error('Order not found.');
      const payload = normalizeObject(row.payload);
      const customerPhone =
        row.customer_phone || payload.customerPhone || payload.customer_phone || '';
      const merchantPhone =
        row.merchant_phone || payload.merchantPhone || payload.merchant_phone || '';
      const courierPhone =
        row.courier_phone || payload.courierPhone || payload.courier_phone || '';
      const allowed = [customerPhone, merchantPhone, courierPhone].some((candidate) =>
        phonesOverlap(phone, candidate)
      );
      if (!allowed) throw new Error('Unauthorized chat access.');
      return;
    }
    case 'taxi': {
      const row = await selectSingle('taxi_requests', 'id', trimmedId);
      if (!row) throw new Error('Taxi request not found.');
      const meta = readTaxiMeta(row);
      const customerPhone = meta.customerPhone || row.customer_phone || '';
      const driverPhone = meta.driverPhone || row.driver_phone || '';
      const allowed = phonesOverlap(phone, customerPhone) || phonesOverlap(phone, driverPhone);
      if (!allowed) throw new Error('Unauthorized chat access.');
      return;
    }
    case 'store': {
      if (phonesOverlap(phone, trimmedId)) return;
      return;
    }
    case 'support': {
      if (phonesOverlap(phone, trimmedId)) return;
      const isAdmin = PLATFORM_ADMIN_PHONES.some((adminPhone) =>
        phonesOverlap(phone, adminPhone)
      );
      if (isAdmin) return;
      throw new Error('Unauthorized chat access.');
    }
    default:
      throw new Error('Invalid thread type.');
  }
}

async function resolveReceiverPhone(threadType, threadId, senderPhone, explicitReceiver) {
  const explicit = String(explicitReceiver || '').trim();
  if (explicit) return await resolvePhoneKey(explicit);

  const sender = await resolvePhoneKey(senderPhone);
  const trimmedId = String(threadId || '').trim();

  switch (threadType) {
    case 'order': {
      const row = await selectSingle('customer_orders', 'id', trimmedId);
      if (!row) return null;
      const payload = normalizeObject(row.payload);
      const customerPhone =
        row.customer_phone || payload.customerPhone || payload.customer_phone || '';
      const merchantPhone =
        row.merchant_phone || payload.merchantPhone || payload.merchant_phone || '';
      if (phonesOverlap(sender, customerPhone)) return merchantPhone || null;
      if (phonesOverlap(sender, merchantPhone)) return customerPhone || null;
      const courierPhone =
        row.courier_phone || payload.courierPhone || payload.courier_phone || '';
      if (phonesOverlap(sender, courierPhone)) {
        return customerPhone || merchantPhone || null;
      }
      return merchantPhone || customerPhone || null;
    }
    case 'taxi': {
      const row = await selectSingle('taxi_requests', 'id', trimmedId);
      if (!row) return null;
      const meta = readTaxiMeta(row);
      const customerPhone = meta.customerPhone || row.customer_phone || '';
      const driverPhone = meta.driverPhone || row.driver_phone || '';
      if (phonesOverlap(sender, customerPhone)) return driverPhone || null;
      if (phonesOverlap(sender, driverPhone)) return customerPhone || null;
      return driverPhone || customerPhone || null;
    }
    case 'store':
      return trimmedId;
    case 'support':
      return SUPPORT_PLATFORM_PHONE;
    default:
      return null;
  }
}

async function getChatMessages(threadType, threadId, requestPhone) {
  await assertCanAccessThread(threadType, threadId, requestPhone);
  const rows = await selectMany(
    'chat_messages',
    [
      { method: 'eq', column: 'thread_type', value: threadType },
      { method: 'eq', column: 'thread_id', value: String(threadId).trim() },
    ],
    { column: 'created_at', ascending: true },
    500
  );
  return rows.map(formatMessage);
}

async function saveChatMessage(payload) {
  const threadType = String(payload.threadType || payload.thread_type || 'order').trim();
  const threadId = String(payload.threadId || payload.thread_id || payload.orderId || '').trim();
  const senderPhone = await resolvePhoneKey(payload.senderPhone);
  const content = String(payload.content || '').trim();
  const messageType = String(payload.messageType || payload.message_type || 'text').trim();

  if (!threadId) throw new Error('Thread id is required.');
  if (!content) throw new Error('Message content is required.');

  await assertCanAccessThread(threadType, threadId, senderPhone);

  const receiverPhone = await resolveReceiverPhone(
    threadType,
    threadId,
    senderPhone,
    payload.receiverPhone
  );

  const supabase = assertSupabaseAdmin();
  const insertPayload = {
    thread_type: threadType,
    thread_id: threadId,
    sender_phone: senderPhone,
    receiver_phone: receiverPhone ? await resolvePhoneKey(receiverPhone) : null,
    sender_name: String(payload.senderName || payload.sender_name || '').trim() || null,
    message_type: messageType || 'text',
    content,
  };

  const { data, error } = await supabase
    .from('chat_messages')
    .insert(insertPayload)
    .select()
    .single();

  if (error) throw new Error(error.message);
  return formatMessage(data);
}

module.exports = {
  getChatMessages,
  saveChatMessage,
  SUPPORT_PLATFORM_PHONE,
};
