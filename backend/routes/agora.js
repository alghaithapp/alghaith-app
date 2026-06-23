const express = require('express');
const router = express.Router();
const { requireOptionalAuthorizedPhone } = require('./_middleware');
const {
  getAgoraConfig,
  buildChannelName,
  uidFromPhone,
  buildRtcToken,
  buildCallSession,
} = require('../services/agora');
const {
  createOutgoingCallLog,
  completeCallLog,
  getCallHistory,
} = require('../supabase_repo');
const { notifyIncomingCall } = require('../push_events');

router.get('/config', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const { appId, enabled } = getAgoraConfig();
    return res.json({
      enabled,
      appId: enabled ? appId : '',
    });
  } catch (error) {
    console.error('agora config error:', error);
    return res.status(500).json({ message: 'Failed to load Agora config.' });
  }
});

router.get('/history', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const threadType = String(req.query.threadType || '').trim();
    const threadId = String(req.query.threadId || '').trim();
    const limit = req.query.limit;
    const logs = await getCallHistory(phone, {
      threadType: threadType || undefined,
      threadId: threadId || undefined,
      limit,
    });
    return res.json(logs);
  } catch (error) {
    console.error('agora history error:', error);
    const status = String(error?.message || '').includes('Unauthorized') ? 403 : 500;
    return res.status(status).json({ message: error?.message || 'Failed to load call history.' });
  }
});

router.post('/call/complete', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
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
    console.error('agora call complete error:', error);
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

    const channelName =
      String(req.body?.channelName || '').trim() ||
      buildChannelName(threadType, threadId);
    const uid = uidFromPhone(phone);
    const session = buildRtcToken(channelName, uid);

    return res.json({
      ...session,
      threadType,
      threadId,
    });
  } catch (error) {
    console.error('agora token error:', error);
    const message = String(error?.message || 'Failed to create Agora token.');
    const status = message.includes('not configured') ? 503 : 500;
    return res.status(status).json({ message });
  }
});

router.post('/call', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;

    const threadType = String(req.body?.threadType || 'order').trim();
    const threadId = String(req.body?.threadId || '').trim();
    const receiverPhone = String(req.body?.receiverPhone || '').trim();
    const callerName = String(req.body?.callerName || 'مستخدم').trim();

    if (!threadId) {
      return res.status(400).json({ message: 'threadId is required.' });
    }
    if (!receiverPhone) {
      return res.status(400).json({ message: 'receiverPhone is required.' });
    }

    const session = buildCallSession(threadType, threadId, phone);

    let callLog = null;
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
      console.error('call log create error:', logError?.message || logError);
    }

    notifyIncomingCall(receiverPhone, {
      threadType,
      threadId,
      channelName: session.channelName,
      callerName,
      callerPhone: phone,
    }).catch((err) =>
      console.error('incoming call push error:', err?.message || err)
    );

    return res.json({
      ...session,
      receiverPhone,
      callerName,
      callLogId: callLog?.id || null,
    });
  } catch (error) {
    console.error('agora call error:', error);
    const message = String(error?.message || 'Failed to start call.');
    const status = message.includes('not configured') ? 503 : 500;
    return res.status(status).json({ message });
  }
});

module.exports = router;
