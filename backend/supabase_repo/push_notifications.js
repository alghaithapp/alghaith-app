const {
  nowIso,
  getPhoneVariants,
  resolvePhoneKey,
  selectMany,
  assertSupabaseAdmin,
} = require('./common');
const {
  ensureAppUser,
} = require('./users');

async function saveDeviceToken(phone, data = {}) {
  const phoneKey = await resolvePhoneKey(phone);
  await ensureAppUser(phoneKey);
  const token = String(data.token ?? '').trim();
  if (!token) {
    throw new Error('Device token is required.');
  }
  const platform = String(data.platform ?? 'unknown').trim() || 'unknown';
  const supabase = assertSupabaseAdmin();
  const existing = await supabase
    .from('device_tokens')
    .select('id')
    .eq('phone', phoneKey)
    .eq('token', token)
    .maybeSingle();
  if (existing.error) {
    throw new Error(existing.error.message);
  }

  const payload = {
    phone: phoneKey,
    token,
    platform,
    updated_at: nowIso(),
  };

  if (existing.data?.id) {
    const { data: updated, error } = await supabase
      .from('device_tokens')
      .update(payload)
      .eq('id', existing.data.id)
      .select();
    if (error) throw new Error(error.message);
    return Array.isArray(updated) ? updated[0] || null : updated || null;
  }

  const { data: inserted, error } = await supabase
    .from('device_tokens')
    .insert(payload)
    .select();
  if (error) throw new Error(error.message);
  return Array.isArray(inserted) ? inserted[0] || null : inserted || null;
}

async function deleteDeviceToken(phone, token) {
  const phoneKey = await resolvePhoneKey(phone);
  const normalizedToken = String(token || '').trim();
  if (!normalizedToken) {
    throw new Error('Device token is required.');
  }
  const supabase = assertSupabaseAdmin();
  const { error } = await supabase
    .from('device_tokens')
    .delete()
    .eq('phone', phoneKey)
    .eq('token', normalizedToken);
  if (error) throw new Error(error.message);
  return { success: true };
}

async function deleteAllDeviceTokens(phone) {
  const phoneKey = await resolvePhoneKey(phone);
  const supabase = assertSupabaseAdmin();
  const { error } = await supabase.from('device_tokens').delete().eq('phone', phoneKey);
  if (error) throw new Error(error.message);
  return { success: true };
}

async function getDeviceTokensForPhone(phone) {
  const variants = getPhoneVariants(phone);
  if (variants.length === 0) return [];
  return selectMany(
    'device_tokens',
    [{ method: 'in', column: 'phone', value: variants }],
    { column: 'updated_at', ascending: false }
  );
}

async function recordPushInboxDelivered(phone) {
  const phoneKey = await resolvePhoneKey(phone);
  const supabase = assertSupabaseAdmin();
  const now = nowIso();
  const { data: existing, error: readError } = await supabase
    .from('push_inbox_state')
    .select('*')
    .eq('phone', phoneKey)
    .maybeSingle();

  if (readError && !/does not exist/i.test(readError.message || '')) {
    throw new Error(readError.message);
  }
  if (readError && /does not exist/i.test(readError.message || '')) {
    return { skipped: true };
  }

  const nextCount = Number(existing?.unread_count || 0) + 1;
  const payload = {
    phone: phoneKey,
    unread_count: nextCount,
    last_push_at: now,
    updated_at: now,
  };

  if (existing) {
    const { error } = await supabase
      .from('push_inbox_state')
      .update(payload)
      .eq('phone', phoneKey);
    if (error) throw new Error(error.message);
  } else {
    const { error } = await supabase.from('push_inbox_state').insert(payload);
    if (error) throw new Error(error.message);
  }

  return { success: true, unreadCount: nextCount };
}

async function markPushInboxOpened(phone) {
  const phoneKey = await resolvePhoneKey(phone);
  const supabase = assertSupabaseAdmin();
  const now = nowIso();
  const { data: existing, error: readError } = await supabase
    .from('push_inbox_state')
    .select('phone')
    .eq('phone', phoneKey)
    .maybeSingle();

  if (readError && !/does not exist/i.test(readError.message || '')) {
    throw new Error(readError.message);
  }
  if (readError && /does not exist/i.test(readError.message || '')) {
    return { success: true, skipped: true };
  }

  const payload = {
    unread_count: 0,
    last_opened_at: now,
    updated_at: now,
  };

  if (existing) {
    const { error } = await supabase
      .from('push_inbox_state')
      .update(payload)
      .eq('phone', phoneKey);
    if (error) throw new Error(error.message);
  } else {
    const { error } = await supabase.from('push_inbox_state').insert({
      phone: phoneKey,
      ...payload,
    });
    if (error) throw new Error(error.message);
  }

  return { success: true };
}

async function markPushInboxReminderSent(phone) {
  const phoneKey = await resolvePhoneKey(phone);
  const supabase = assertSupabaseAdmin();
  const now = nowIso();
  const { error } = await supabase
    .from('push_inbox_state')
    .update({
      last_reminder_at: now,
      updated_at: now,
    })
    .eq('phone', phoneKey);
  if (error && !/does not exist/i.test(error.message || '')) {
    throw new Error(error.message);
  }
  return { success: true };
}

async function listPushInboxStatesNeedingReminder() {
  const supabase = assertSupabaseAdmin();
  const { data, error } = await supabase.from('push_inbox_state').select('*');
  if (error) {
    if (/does not exist/i.test(error.message || '')) return [];
    throw new Error(error.message);
  }

  const reminderAfterMs = 2 * 60 * 60 * 1000;
  const nowMs = Date.now();

  return (data || []).filter((row) => {
    const unreadCount = Number(row.unread_count || 0);
    if (unreadCount <= 0) return false;

    const lastPush = new Date(row.last_push_at || 0);
    if (Number.isNaN(lastPush.getTime()) || nowMs - lastPush.getTime() < reminderAfterMs) {
      return false;
    }

    const lastOpened = row.last_opened_at ? new Date(row.last_opened_at) : null;
    if (
      lastOpened &&
      !Number.isNaN(lastOpened.getTime()) &&
      lastOpened.getTime() >= lastPush.getTime()
    ) {
      return false;
    }

    const lastReminder = row.last_reminder_at ? new Date(row.last_reminder_at) : null;
    if (
      lastReminder &&
      !Number.isNaN(lastReminder.getTime()) &&
      lastReminder.getTime() >= lastPush.getTime()
    ) {
      return false;
    }

    return true;
  });
}

async function removeDeviceTokens(tokens = []) {
  const normalized = [...new Set(tokens.map((item) => String(item || '').trim()).filter(Boolean))];
  if (!normalized.length) return { success: true };
  const supabase = assertSupabaseAdmin();
  const { error } = await supabase.from('device_tokens').delete().in('token', normalized);
  if (error) throw new Error(error.message);
  return { success: true };
}

module.exports = {
  saveDeviceToken,
  deleteDeviceToken,
  deleteAllDeviceTokens,
  getDeviceTokensForPhone,
  removeDeviceTokens,
  recordPushInboxDelivered,
  markPushInboxOpened,
  markPushInboxReminderSent,
  listPushInboxStatesNeedingReminder,
};
