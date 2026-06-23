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
    });
  } catch (error) {
    console.error('agora call error:', error);
    const message = String(error?.message || 'Failed to start call.');
    const status = message.includes('not configured') ? 503 : 500;
    return res.status(status).json({ message });
  }
});

module.exports = router;
