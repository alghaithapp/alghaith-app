const {
  assertSupabaseAdmin,
  selectSingle,
  selectSingleByPhone,
  selectMany,
  resolvePhoneKey,
  getPhoneVariants,
  phonesOverlap,
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

function shortThreadId(value) {
  const trimmed = String(value || '').trim();
  if (trimmed.length <= 8) return trimmed;
  return trimmed.slice(-8);
}

function orderDisplayNumber(row) {
  const payload = normalizeObject(row?.payload ?? row?.order_payload);
  const explicit =
    payload.orderNumber ||
    payload.order_number ||
    row?.order_number ||
    row?.orderNumber;
  if (explicit) return String(explicit).trim();
  return shortThreadId(row?.id || '');
}

async function resolveOtherPartyName(threadType, threadId, otherPartyPhone, fallbackName) {
  const name = String(fallbackName || '').trim();
  if (name) return name;

  const phone = String(otherPartyPhone || '').trim();
  if (!phone) return null;

  const merchant = await selectSingleByPhone('merchant_profiles', phone);
  if (merchant?.store_name) return String(merchant.store_name).trim();

  const user = await selectSingleByPhone('app_users', phone);
  if (user?.full_name) return String(user.full_name).trim();

  if (threadType === 'store') {
    return merchant?.store_name ? String(merchant.store_name).trim() : 'متجر';
  }

  return null;
}

async function buildThreadContext(threadType, threadId, myPhone, otherPartyPhone, fallbackName) {
  const trimmedId = String(threadId || '').trim();
  let contextLabel = 'محادثة داخل التطبيق';
  let threadTitle = null;

  switch (threadType) {
    case 'order': {
      const row = await selectSingle('customer_orders', 'id', trimmedId);
      const orderNo = row ? orderDisplayNumber(row) : shortThreadId(trimmedId);
      contextLabel = row ? `طلب #${orderNo}` : `طلب #${shortThreadId(trimmedId)}`;
      const payload = normalizeObject(row?.payload);
      const customerPhone =
        row?.customer_phone || payload.customerPhone || payload.customer_phone || '';
      const merchantPhone =
        row?.merchant_phone || payload.merchantPhone || payload.merchant_phone || '';
      if (phonesOverlap(myPhone, customerPhone)) {
        const merchant = merchantPhone
          ? await selectSingleByPhone('merchant_profiles', merchantPhone)
          : null;
        threadTitle = merchant?.store_name
          ? String(merchant.store_name).trim()
          : 'التاجر';
      } else {
        const customer = customerPhone
          ? await selectSingleByPhone('app_users', customerPhone)
          : null;
        threadTitle = customer?.full_name
          ? String(customer.full_name).trim()
          : 'الزبون';
      }
      break;
    }
    case 'taxi': {
      contextLabel = `رحلة تكسي #${shortThreadId(trimmedId)}`;
      const row = await selectSingle('taxi_requests', 'id', trimmedId);
      const meta = row ? readTaxiMeta(row) : {};
      const customerPhone = meta.customerPhone || row?.customer_phone || '';
      const driverPhone = meta.driverPhone || row?.driver_phone || '';
      if (phonesOverlap(myPhone, customerPhone)) {
        threadTitle = 'السائق';
      } else if (phonesOverlap(myPhone, driverPhone)) {
        const customer = customerPhone
          ? await selectSingleByPhone('app_users', customerPhone)
          : null;
        threadTitle = customer?.full_name
          ? String(customer.full_name).trim()
          : 'الزبون';
      } else {
        threadTitle = 'رحلة تكسي';
      }
      break;
    }
    case 'store': {
      const merchant = await selectSingleByPhone('merchant_profiles', trimmedId);
      threadTitle = merchant?.store_name
        ? String(merchant.store_name).trim()
        : 'متجر';
      contextLabel = 'محادثة متجر';
      break;
    }
    default:
      break;
  }

  const resolvedName = await resolveOtherPartyName(
    threadType,
    trimmedId,
    otherPartyPhone,
    threadTitle || fallbackName
  );

  return {
    context_label: contextLabel,
    thread_title: resolvedName || threadTitle || fallbackName || null,
    other_party_name: resolvedName || fallbackName || null,
  };
}

function formatThreadSummary(row, myPhone) {
  const mine = phonesOverlap(row.sender_phone, myPhone);
  return {
    thread_type: row.thread_type,
    thread_id: row.thread_id,
    other_party_phone: mine ? row.receiver_phone : row.sender_phone,
    other_party_name: mine ? null : row.sender_name,
    last_message: row.content,
    last_at: row.created_at,
  };
}

function mapChatDbError(error) {
  const message = String(error?.message || error || '').trim();
  const code = String(error?.code || '').trim();

  const tableMissing =
    code === '42P01' ||
    message.includes('Could not find the table') ||
    (message.includes('relation') &&
      message.includes('chat_messages') &&
      message.includes('does not exist'));

  if (tableMissing) {
    return 'جدول المحادثات غير منشأ في Supabase. نفّذ ملف supabase/chat_messages.sql ثم أعد المحاولة.';
  }

  const schemaOutdated =
    code === '42703' ||
    (message.includes('chat_messages') && message.includes('does not exist'));

  if (schemaOutdated) {
    return 'جدول المحادثات يحتاج تحديثاً. نفّذ ملف supabase/chat_messages.sql ثم أعد المحاولة.';
  }

  return message || 'Failed to save chat message.';
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
      // الزبون يتواصل قبل الطلب؛ التاجر يصل عبر thread_id = رقم متجره.
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
    100
  );
  return rows.map(formatMessage);
}

const INBOX_COLUMNS_BASE =
  'id, thread_type, thread_id, sender_phone, receiver_phone, sender_name, content, message_type, created_at';

function isMissingColumnError(error, column) {
  const message = String(error?.message || '');
  return String(error?.code || '') === '42703' && message.includes(column);
}

async function fetchInboxSide(supabase, phoneColumn, variants) {
  const run = (select) =>
    supabase
      .from('chat_messages')
      .select(select)
      .in(phoneColumn, variants)
      .order('created_at', { ascending: false })
      .limit(80);

  let result = await run(`${INBOX_COLUMNS_BASE}, read_at`);
  if (result.error && isMissingColumnError(result.error, 'read_at')) {
    result = await run(INBOX_COLUMNS_BASE);
  }
  if (result.error && isMissingColumnError(result.error, 'sender_name')) {
    result = await run(
      'id, thread_type, thread_id, sender_phone, receiver_phone, content, message_type, created_at'
    );
  }
  return result;
}

async function getChatInbox(requestPhone) {
  const phone = await resolvePhoneKey(requestPhone);
  const variants = getPhoneVariants(phone);
  if (variants.length === 0) return [];

  const supabase = assertSupabaseAdmin();

  const [sentResult, receivedResult] = await Promise.all([
    fetchInboxSide(supabase, 'sender_phone', variants),
    fetchInboxSide(supabase, 'receiver_phone', variants),
  ]);

  const error = sentResult.error || receivedResult.error;
  if (error) throw new Error(mapChatDbError(error));

  const combined = [...(sentResult.data || []), ...(receivedResult.data || [])];
  combined.sort(
    (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
  );

  const threads = new Map();
  for (const row of combined) {
    const key = `${row.thread_type}:${row.thread_id}`;
    if (!threads.has(key)) {
      threads.set(key, formatThreadSummary(row, phone));
    }
  }

  const summaries = Array.from(threads.values());
  const enriched = await Promise.all(
    summaries.map(async (summary) => {
      const context = await buildThreadContext(
        summary.thread_type,
        summary.thread_id,
        phone,
        summary.other_party_phone,
        summary.other_party_name
      );
      return { ...summary, ...context };
    })
  );

  return enriched.sort(
    (a, b) => new Date(b.last_at).getTime() - new Date(a.last_at).getTime()
  );
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

  if (error) throw new Error(mapChatDbError(error));
  return formatMessage(data);
}

module.exports = {
  getChatMessages,
  getChatInbox,
  saveChatMessage,
  SUPPORT_PLATFORM_PHONE,
};
