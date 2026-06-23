const {
  assertSupabaseAdmin,
  resolvePhoneKey,
  phonesOverlap,
} = require('./common');

function formatCallLog(row) {
  return {
    id: row.id,
    thread_type: row.thread_type,
    thread_id: row.thread_id,
    caller_phone: row.caller_phone,
    receiver_phone: row.receiver_phone,
    caller_name: row.caller_name,
    channel_name: row.channel_name,
    direction: row.direction,
    status: row.status,
    duration_seconds: row.duration_seconds ?? 0,
    started_at: row.started_at,
    ended_at: row.ended_at,
  };
}

function mapCallDbError(error) {
  const message = String(error?.message || error || '').trim();
  if (
    message.includes('voice_call_logs') &&
    (message.includes('does not exist') ||
      message.includes('schema cache') ||
      message.includes('Could not find'))
  ) {
    return 'جدول سجل المكالمات غير منشأ في Supabase. نفّذ ملف supabase/voice_call_logs.sql.';
  }
  return message || 'Failed to save call log.';
}

async function createOutgoingCallLog({
  threadType,
  threadId,
  callerPhone,
  receiverPhone,
  callerName,
  channelName,
}) {
  const supabase = assertSupabaseAdmin();
  const payload = {
    thread_type: threadType,
    thread_id: threadId,
    caller_phone: await resolvePhoneKey(callerPhone),
    receiver_phone: await resolvePhoneKey(receiverPhone),
    caller_name: String(callerName || '').trim() || null,
    channel_name: String(channelName || '').trim() || null,
    direction: 'outgoing',
    status: 'ringing',
  };

  const { data, error } = await supabase
    .from('voice_call_logs')
    .insert(payload)
    .select()
    .single();

  if (error) throw new Error(mapCallDbError(error));
  return formatCallLog(data);
}

async function completeCallLog({
  callLogId,
  requestPhone,
  threadType,
  threadId,
  otherPartyPhone,
  direction,
  status,
  durationSeconds,
  channelName,
}) {
  const phone = await resolvePhoneKey(requestPhone);
  const supabase = assertSupabaseAdmin();
  const normalizedStatus = String(status || 'ended').trim();
  const duration = Math.max(0, Number.parseInt(String(durationSeconds ?? 0), 10) || 0);
  const endedAt = new Date().toISOString();

  if (callLogId) {
    const { data: existing, error: readError } = await supabase
      .from('voice_call_logs')
      .select('*')
      .eq('id', callLogId)
      .maybeSingle();
    if (readError) throw new Error(mapCallDbError(readError));
    if (!existing) throw new Error('Call log not found.');
    const allowed =
      phonesOverlap(phone, existing.caller_phone) ||
      phonesOverlap(phone, existing.receiver_phone);
    if (!allowed) throw new Error('Unauthorized call log access.');

    const { data, error } = await supabase
      .from('voice_call_logs')
      .update({
        status: normalizedStatus,
        duration_seconds: duration,
        ended_at: endedAt,
      })
      .eq('id', callLogId)
      .select()
      .single();
    if (error) throw new Error(mapCallDbError(error));
    return formatCallLog(data);
  }

  const other = await resolvePhoneKey(otherPartyPhone);
  const isIncoming = String(direction || '').trim() === 'incoming';
  const payload = {
    thread_type: String(threadType || 'order').trim(),
    thread_id: String(threadId || '').trim(),
    caller_phone: isIncoming ? other : phone,
    receiver_phone: isIncoming ? phone : other,
    channel_name: String(channelName || '').trim() || null,
    direction: isIncoming ? 'incoming' : 'outgoing',
    status: normalizedStatus,
    duration_seconds: duration,
    ended_at: endedAt,
  };

  const { data, error } = await supabase
    .from('voice_call_logs')
    .insert(payload)
    .select()
    .single();
  if (error) throw new Error(mapCallDbError(error));
  return formatCallLog(data);
}

async function getCallHistory(requestPhone, { threadType, threadId, limit = 50 } = {}) {
  const phone = await resolvePhoneKey(requestPhone);
  const supabase = assertSupabaseAdmin();
  const max = Math.min(Math.max(Number.parseInt(String(limit || 50), 10) || 50, 1), 200);

  let sentQuery = supabase
    .from('voice_call_logs')
    .select('*')
    .eq('caller_phone', phone)
    .order('started_at', { ascending: false })
    .limit(max);

  let receivedQuery = supabase
    .from('voice_call_logs')
    .select('*')
    .eq('receiver_phone', phone)
    .order('started_at', { ascending: false })
    .limit(max);

  if (threadType && threadId) {
    const type = String(threadType).trim();
    const id = String(threadId).trim();
    sentQuery = sentQuery.eq('thread_type', type).eq('thread_id', id);
    receivedQuery = receivedQuery.eq('thread_type', type).eq('thread_id', id);
  }

  const [sentResult, receivedResult] = await Promise.all([sentQuery, receivedQuery]);
  const error = sentResult.error || receivedResult.error;
  if (error) throw new Error(mapCallDbError(error));

  const combined = [...(sentResult.data || []), ...(receivedResult.data || [])];
  combined.sort(
    (a, b) => new Date(b.started_at).getTime() - new Date(a.started_at).getTime()
  );

  const seen = new Set();
  const unique = [];
  for (const row of combined) {
    if (seen.has(row.id)) continue;
    seen.add(row.id);
    unique.push(formatCallLog(row));
    if (unique.length >= max) break;
  }
  return unique;
}

module.exports = {
  createOutgoingCallLog,
  completeCallLog,
  getCallHistory,
};
