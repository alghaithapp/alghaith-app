const express = require('express');
const router = express.Router();
const { requireOptionalAuthorizedPhone } = require('./_middleware');
const {
  getZegoConfig,
  buildRoomId,
  userIdFromPhone,
  buildRtcToken,
  buildCallSession,
} = require('../services/zego');
const {
  createOutgoingCallLog,
  completeCallLog,
  getCallHistory,
  getCallLogStatus,
  markCallConnected,
  rejectCallLog,
} = require('../supabase_repo');
const { getMerchantProfile } = require('../supabase_repo/merchants');
const { merchantAcceptsCustomerCalls } = require('../services/merchant_working_hours');
const { notifyIncomingCall } = require('../push_events');
const { resolveReceiverPhone, assertCanAccessThread } = require('../supabase_repo/chat');
const { getPhoneVariants, assertSupabaseAdmin, resolvePhoneKey } = require('../supabase_repo/common');

router.get('/config', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const { appId, enabled } = getZegoConfig();
    return res.json({
      enabled,
      appId: enabled ? appId : 0,
    });
  } catch (error) {
    console.error('voice config error:', error);
    return res.status(500).json({ message: 'Failed to load voice call config.' });
  }
});

router.get('/pending', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;

    const phoneKey = await resolvePhoneKey(phone);
    const variants = getPhoneVariants(phoneKey);
    if (!variants.length) return res.json([]);

    const supabase = assertSupabaseAdmin();
    const since = new Date(Date.now() - 120_000).toISOString();
    const { data, error } = await supabase
      .from('voice_call_logs')
      .select('*')
      .in('receiver_phone', variants)
      .eq('status', 'ringing')
      .gte('started_at', since)
      .order('started_at', { ascending: false })
      .limit(5);

    if (error) {
      const status = String(error.message || '').includes('does not exist') ? 503 : 500;
      return res.status(status).json({ message: error.message });
    }

    return res.json((data || []).map((row) => ({
      id: row.id,
      thread_type: row.thread_type,
      thread_id: row.thread_id,
      caller_phone: row.caller_phone,
      receiver_phone: row.receiver_phone,
      caller_name: row.caller_name,
      channel_name: row.channel_name,
      status: row.status,
      started_at: row.started_at,
    })));
  } catch (error) {
    console.error('voice pending error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load pending calls.' });
  }
});

router.get('/history', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const threadType = String(req.query.threadType || '').trim();
    const threadId = String(req.query.threadId || '').trim();
    const limit = req.query.limit;
    if (threadType && threadId) {
      await assertCanAccessThread(threadType, threadId, phone);
    }
    const logs = await getCallHistory(phone, {
      threadType: threadType || undefined,
      threadId: threadId || undefined,
      limit,
    });
    return res.json(logs);
  } catch (error) {
    console.error('voice history error:', error);
    const status = String(error?.message || '').includes('Unauthorized') ? 403 : 500;
    return res.status(status).json({ message: error?.message || 'Failed to load call history.' });
  }
});

router.get('/call/status', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const callLogId = String(req.query.callLogId || '').trim();
    if (!callLogId) {
      return res.status(400).json({ message: 'callLogId is required.' });
    }
    const status = await getCallLogStatus({ callLogId, requestPhone: phone });
    return res.json(status);
  } catch (error) {
    console.error('voice call status error:', error);
    const statusCode = String(error?.message || '').includes('Unauthorized') ? 403 : 500;
    return res.status(statusCode).json({ message: error?.message || 'Failed to load call status.' });
  }
});

router.post('/call/reject', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const threadType = String(req.body?.threadType || '').trim();
    const threadId = String(req.body?.threadId || '').trim();
    if (threadType && threadId) {
      await assertCanAccessThread(threadType, threadId, phone);
    }
    const saved = await rejectCallLog({
      callLogId: req.body?.callLogId,
      channelName: req.body?.channelName,
      requestPhone: phone,
      threadType,
      threadId,
    });
    if (!saved) {
      return res.status(404).json({ message: 'لا توجد مكالمة قيد الرنين.' });
    }
    return res.json(saved);
  } catch (error) {
    console.error('voice call reject error:', error);
    const status = String(error?.message || '').includes('Unauthorized') ? 403 : 500;
    return res.status(status).json({ message: error?.message || 'Failed to reject call.' });
  }
});

router.post('/call/complete', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const threadType = String(req.body?.threadType || '').trim();
    const threadId = String(req.body?.threadId || '').trim();
    if (threadType && threadId) {
      await assertCanAccessThread(threadType, threadId, phone);
    }
    const saved = await completeCallLog({
      callLogId: req.body?.callLogId,
      requestPhone: phone,
      threadType: req.body?.threadType,
      threadId: req.body?.threadId,
      otherPartyPhone: req.body?.otherPartyPhone,
      direction: req.body?.direction,
      status: req.body?.status,
      durationSeconds: req.body?.durationSeconds,
      channelName: req.body?.channelName,
    });
    return res.json(saved);
  } catch (error) {
    console.error('voice call complete error:', error);
    const status = String(error?.message || '').includes('Unauthorized') ? 403 : 500;
    return res.status(status).json({ message: error?.message || 'Failed to complete call log.' });
  }
});

router.post('/token', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;

    const threadType = String(req.body?.threadType || 'order').trim();
    const threadId = String(req.body?.threadId || '').trim();
    if (!threadId) {
      return res.status(400).json({ message: 'threadId is required.' });
    }

    await assertCanAccessThread(threadType, threadId, phone);

    const roomId =
      String(req.body?.channelName || req.body?.roomId || '').trim() ||
      buildRoomId(threadType, threadId);
    const userId = userIdFromPhone(phone);
    const session = buildRtcToken(roomId, userId);

    try {
      await markCallConnected({
        channelName: roomId,
        requestPhone: phone,
      });
    } catch (markError) {
      console.warn('mark call connected:', markError?.message || markError);
    }

    return res.json({
      ...session,
      threadType,
      threadId,
    });
  } catch (error) {
    console.error('voice token error:', error);
    const message = String(error?.message || 'Failed to create ZEGO token.');
    const status = message.includes('Unauthorized')
      ? 403
      : message.includes('not configured')
        ? 503
        : 500;
    return res.status(status).json({ message });
  }
});

router.post('/call', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;

    const threadType = String(req.body?.threadType || 'order').trim();
    const threadId = String(req.body?.threadId || '').trim();
    let receiverPhone = String(req.body?.receiverPhone || '').trim();
    const callerName = String(req.body?.callerName || 'مستخدم').trim();

    if (!threadId) {
      return res.status(400).json({ message: 'threadId is required.' });
    }

    await assertCanAccessThread(threadType, threadId, phone);

    if (!receiverPhone) {
      const resolved = await resolveReceiverPhone(threadType, threadId, phone, '');
      receiverPhone = String(resolved || '').trim();
    }
    if (!receiverPhone) {
      return res.status(400).json({ message: 'receiverPhone is required.' });
    }

    receiverPhone = await resolvePhoneKey(receiverPhone);

    const merchantProfile = await getMerchantProfile(receiverPhone);
    if (merchantProfile) {
      const callCheck = merchantAcceptsCustomerCalls(merchantProfile);
      if (!callCheck.allowed) {
        return res.status(403).json({ message: callCheck.messageAr });
      }
    }

    const session = buildCallSession(threadType, threadId, phone);

    let callLog = null;
    let callLogError = null;
    try {
      callLog = await createOutgoingCallLog({
        threadType,
        threadId,
        callerPhone: phone,
        receiverPhone,
        callerName,
        channelName: session.channelName,
      });
    } catch (logError) {
      callLogError = String(logError?.message || logError || 'call_log_failed');
      console.error('call log create error:', callLogError);
    }

    let pushResult = { sent: 0, reason: 'not_sent' };
    try {
      pushResult = await notifyIncomingCall(receiverPhone, {
        threadType,
        threadId,
        channelName: session.channelName,
        callerName,
        callerPhone: phone,
        callLogId: callLog?.id || null,
      });
      if (!pushResult?.sent) {
        console.warn(
          'incoming call push not delivered:',
          receiverPhone,
          pushResult?.reason || 'unknown'
        );
      }
    } catch (err) {
      console.error('incoming call push error:', err?.message || err);
      pushResult = { sent: 0, reason: err?.message || 'push_error' };
    }

    return res.json({
      ...session,
      receiverPhone,
      callerName,
      callLogId: callLog?.id || null,
      callLogCreated: Boolean(callLog?.id),
      callLogError: callLog?.id ? null : callLogError,
      pushDelivered: (pushResult?.sent || 0) > 0,
      pushReason: pushResult?.sent ? null : pushResult?.reason || 'no_tokens',
      pushTokenCount: pushResult?.sent || 0,
    });
  } catch (error) {
    console.error('voice call error:', error);
    const message = String(error?.message || 'Failed to start call.');
    const status = message.includes('Unauthorized')
      ? 403
      : message.includes('not configured')
        ? 503
        : 500;
    return res.status(status).json({ message });
  }
});

module.exports = router;
