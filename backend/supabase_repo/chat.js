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
const { deleteChatImageByUrl, purgeExpiredChatImages } = require('../services/chat_media_cleanup');

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

function formatLastMessagePreview(row) {
  const type = String(row.message_type || 'text').trim();
  if (type === 'call') {
    try {
      const parsed = JSON.parse(String(row.content || '{}'));
      const status = String(parsed.status || 'ended').trim();
      if (status === 'missed' || status === 'no_answer') return 'مكالمة فائتة';
      if (status === 'failed') return 'مكالمة · فشل الاتصال';
      const duration = Number.parseInt(String(parsed.durationSeconds ?? 0), 10) || 0;
      if (duration > 0) {
        const minutes = Math.floor(duration / 60);
        const seconds = duration % 60;
        const clock =
          minutes > 0
            ? `${minutes}:${String(seconds).padStart(2, '0')}`
            : `${seconds} ث`;
        return `مكالمة صوتية · ${clock}`;
      }
      return 'مكالمة صوتية';
    } catch (_) {
      return 'مكالمة صوتية';
    }
  }
  if (type === 'sticker') return 'ملصق';
  if (type === 'image') return 'صورة';
  return row.content;
}

function inboxThreadKey(row, myPhone) {
  const type = String(row.thread_type || '').trim();
  const id = String(row.thread_id || '').trim();
  if (type === 'store' && phonesOverlap(id, myPhone)) {
    const other = phonesOverlap(row.sender_phone, myPhone)
      ? String(row.receiver_phone || '').trim()
      : String(row.sender_phone || '').trim();
    if (other) return `${type}:${id}:${other}`;
  }
  return `${type}:${id}`;
}

function summaryThreadKey(summary, myPhone) {
  const type = String(summary.thread_type || '').trim();
  const id = String(summary.thread_id || '').trim();
  if (type === 'store' && phonesOverlap(id, myPhone)) {
    const other = String(summary.other_party_phone || '').trim();
    if (other) return `${type}:${id}:${other}`;
  }
  return `${type}:${id}`;
}

function isUnreadIncoming(row, myPhone) {
  if (phonesOverlap(row.sender_phone, myPhone)) return false;
  if (!phonesOverlap(row.receiver_phone, myPhone)) return false;
  return !row.read_at;
}

function formatThreadSummary(row, myPhone) {
  const mine = phonesOverlap(row.sender_phone, myPhone);
  return {
    thread_type: row.thread_type,
    thread_id: row.thread_id,
    other_party_phone: mine ? row.receiver_phone : row.sender_phone,
    other_party_name: mine ? null : row.sender_name,
    last_message: formatLastMessagePreview(row),
    last_at: row.created_at,
  };
}

function mapChatAccessError(message) {
  const text = String(message || '').trim();
  if (text === 'Store not found.') {
    return 'المتجر غير موجود أو غير مسجّل في التطبيق.';
  }
  if (text === 'Order not found.') {
    return 'الطلب غير موجود على السيرفر.';
  }
  if (text === 'Taxi request not found.') {
    return 'رحلة التكسي غير موجودة.';
  }
  if (text === 'Unauthorized chat access.') {
    return 'غير مصرّح لك بفتح هذه المحادثة.';
  }
  return text;
}

async function resolveStoreContact(phone) {
  const merchant = await selectSingleByPhone('merchant_profiles', phone);
  if (merchant) return merchant;
  return selectSingleByPhone('app_users', phone);
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
      const contact = await resolveStoreContact(trimmedId);
      if (!contact) throw new Error('Store not found.');
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

async function getChatMessages(threadType, threadId, requestPhone, options = {}) {
  purgeExpiredChatImages({ batchSize: 50 }).catch(() => {});
  const phone = await resolvePhoneKey(requestPhone);
  const trimmedType = String(threadType || '').trim();
  const trimmedId = String(threadId || '').trim();
  await assertCanAccessThread(trimmedType, trimmedId, phone);

  const limitNum = Math.min(Math.max(Number(options.limit) || 30, 1), 100);
  const offsetNum = Math.max(Number(options.offset) || 0, 0);
  const afterTimestamp = String(options.after || '').trim();

  const supabase = assertSupabaseAdmin();

  let query = supabase
    .from('chat_messages')
    .select('*')
    .eq('thread_type', trimmedType)
    .eq('thread_id', trimmedId)
    .order('created_at', { ascending: false })
    .limit(limitNum);

  if (offsetNum > 0) {
    query = query.range(offsetNum, offsetNum + limitNum - 1);
  }

  if (afterTimestamp) {
    query = query.gt('created_at', afterTimestamp);
  }

  const { data, error } = await query;
  if (error) throw new Error(error.message);

  const rows = data || [];

  if (trimmedType === 'store' && !phonesOverlap(phone, trimmedId)) {
    return rows
      .filter(
        (row) =>
          phonesOverlap(phone, row.sender_phone) ||
          phonesOverlap(phone, row.receiver_phone)
      )
      .map(formatMessage);
  }
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
  purgeExpiredChatImages({ batchSize: 50 }).catch(() => {});
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
  const unreadCounts = new Map();
  for (const row of combined) {
    const key = inboxThreadKey(row, phone);
    if (!threads.has(key)) {
      threads.set(key, formatThreadSummary(row, phone));
    }
    if (isUnreadIncoming(row, phone)) {
      unreadCounts.set(key, (unreadCounts.get(key) || 0) + 1);
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
      const key = summaryThreadKey(summary, phone);
      const unreadCount = unreadCounts.get(key) || 0;
      return {
        ...summary,
        ...context,
        unread_count: unreadCount,
        has_unread: unreadCount > 0,
      };
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

async function appendCallChatEvent(callLogRow) {
  const row = callLogRow || {};
  const threadType = String(row.thread_type || '').trim();
  const threadId = String(row.thread_id || '').trim();
  const callLogId = String(row.id || '').trim();
  if (!threadType || !threadId || !callLogId) return null;

  const status = String(row.status || '').trim();
  if (!['ended', 'missed', 'no_answer', 'failed'].includes(status)) return null;

  const supabase = assertSupabaseAdmin();
  const { data: recent, error: readError } = await supabase
    .from('chat_messages')
    .select('id, content')
    .eq('thread_type', threadType)
    .eq('thread_id', threadId)
    .eq('message_type', 'call')
    .order('created_at', { ascending: false })
    .limit(30);
  if (readError) throw new Error(mapChatDbError(readError));

  for (const item of recent || []) {
    try {
      const parsed = JSON.parse(String(item.content || '{}'));
      if (String(parsed.callLogId || '') === callLogId) return null;
    } catch (_) {}
  }

  const content = JSON.stringify({
    callLogId,
    status,
    durationSeconds: row.duration_seconds ?? 0,
    direction: row.direction || 'outgoing',
  });

  return saveChatMessage({
    threadType,
    threadId,
    senderPhone: row.caller_phone,
    receiverPhone: row.receiver_phone,
    senderName: row.caller_name,
    messageType: 'call',
    content,
  });
}

async function markThreadAsRead(threadType, threadId, requestPhone, otherPartyPhone) {
  const phone = await resolvePhoneKey(requestPhone);
  const trimmedType = String(threadType || '').trim();
  const trimmedId = String(threadId || '').trim();
  if (!trimmedId) throw new Error('Thread id is required.');

  await assertCanAccessThread(trimmedType, trimmedId, phone);

  const supabase = assertSupabaseAdmin();
  const receiverVariants = getPhoneVariants(phone);
  if (receiverVariants.length === 0) return { success: true, updated: 0 };

  let query = supabase
    .from('chat_messages')
    .update({ read_at: new Date().toISOString() })
    .eq('thread_type', trimmedType)
    .eq('thread_id', trimmedId)
    .in('receiver_phone', receiverVariants)
    .is('read_at', null);

  if (trimmedType === 'store' && phonesOverlap(trimmedId, phone)) {
    const other = String(otherPartyPhone || '').trim();
    if (other) {
      const senderVariants = getPhoneVariants(await resolvePhoneKey(other));
      if (senderVariants.length > 0) {
        query = query.in('sender_phone', senderVariants);
      }
    }
  }

  const { data, error } = await query.select('id');
  if (error) {
    if (isMissingColumnError(error, 'read_at')) {
      return { success: true, updated: 0, read_at_supported: false };
    }
    throw new Error(mapChatDbError(error));
  }

  return {
    success: true,
    updated: Array.isArray(data) ? data.length : 0,
    read_at_supported: true,
  };
}

function threadRowMatchesDeleteScope(row, phone, threadType, threadId, otherPartyPhone) {
  if (String(row.thread_type || '').trim() !== String(threadType || '').trim()) {
    return false;
  }
  if (String(row.thread_id || '').trim() !== String(threadId || '').trim()) {
    return false;
  }

  if (threadType === 'store') {
    const merchantPhone = String(threadId).trim();
    if (phonesOverlap(merchantPhone, phone)) {
      const other = String(otherPartyPhone || '').trim();
      if (!other) return false;
      return (
        (phonesOverlap(row.sender_phone, phone) && phonesOverlap(row.receiver_phone, other)) ||
        (phonesOverlap(row.receiver_phone, phone) && phonesOverlap(row.sender_phone, other))
      );
    }
    return phonesOverlap(row.sender_phone, phone) || phonesOverlap(row.receiver_phone, phone);
  }

  return true;
}

function callLogMatchesDeleteScope(row, phone, threadType, threadId, otherPartyPhone) {
  if (threadType !== 'store') return true;
  if (phonesOverlap(threadId, phone)) {
    const other = String(otherPartyPhone || '').trim();
    if (!other) return false;
    return (
      (phonesOverlap(row.caller_phone, phone) && phonesOverlap(row.receiver_phone, other)) ||
      (phonesOverlap(row.receiver_phone, phone) && phonesOverlap(row.caller_phone, other))
    );
  }
  return phonesOverlap(row.caller_phone, phone) || phonesOverlap(row.receiver_phone, phone);
}

async function deleteChatThread(threadType, threadId, requestPhone, otherPartyPhone) {
  const phone = await resolvePhoneKey(requestPhone);
  const trimmedType = String(threadType || '').trim();
  const trimmedId = String(threadId || '').trim();
  if (!trimmedId) throw new Error('Thread id is required.');

  await assertCanAccessThread(trimmedType, trimmedId, phone);

  const supabase = assertSupabaseAdmin();
  const { data: rows, error: readError } = await supabase
    .from('chat_messages')
    .select('id, content, message_type, sender_phone, receiver_phone, thread_type, thread_id')
    .eq('thread_type', trimmedType)
    .eq('thread_id', trimmedId);

  if (readError) throw new Error(mapChatDbError(readError));

  const toDelete = (rows || []).filter((row) =>
    threadRowMatchesDeleteScope(row, phone, trimmedType, trimmedId, otherPartyPhone)
  );

  for (const row of toDelete) {
    if (String(row.message_type || '').trim() === 'image') {
      try {
        await deleteChatImageByUrl(row.content);
      } catch (cleanupError) {
        console.warn('delete chat image:', cleanupError?.message || cleanupError);
      }
    }
  }

  const ids = toDelete.map((row) => row.id);
  if (ids.length > 0) {
    const { error: deleteMessagesError } = await supabase
      .from('chat_messages')
      .delete()
      .in('id', ids);
    if (deleteMessagesError) throw new Error(mapChatDbError(deleteMessagesError));
  }

  let callLogsDeleted = 0;
  try {
    const { data: callRows, error: callReadError } = await supabase
      .from('voice_call_logs')
      .select('id, caller_phone, receiver_phone')
      .eq('thread_type', trimmedType)
      .eq('thread_id', trimmedId);
    if (!callReadError && Array.isArray(callRows)) {
      const callIds = callRows
        .filter((row) =>
          callLogMatchesDeleteScope(row, phone, trimmedType, trimmedId, otherPartyPhone)
        )
        .map((row) => row.id);
      if (callIds.length > 0) {
        const { error: callDeleteError } = await supabase
          .from('voice_call_logs')
          .delete()
          .in('id', callIds);
        if (!callDeleteError) callLogsDeleted = callIds.length;
      }
    }
  } catch (_) {}

  return {
    success: true,
    deleted_messages: ids.length,
    deleted_call_logs: callLogsDeleted,
  };
}

module.exports = {
  getChatMessages,
  getChatInbox,
  saveChatMessage,
  appendCallChatEvent,
  markThreadAsRead,
  deleteChatThread,
  resolveReceiverPhone,
  assertCanAccessThread,
  mapChatAccessError,
  SUPPORT_PLATFORM_PHONE,
};
