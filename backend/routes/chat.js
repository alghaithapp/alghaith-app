const express = require('express');
const router = express.Router();
const { getChatMessages, getChatInbox, saveChatMessage } = require('../supabase_repo');
const { requireOptionalAuthorizedPhone } = require('./_middleware');
const { notifyChatMessage } = require('../push_events');

router.get('/inbox/threads', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const threads = await getChatInbox(phone);
    return res.json(threads);
  } catch (error) {
    console.error('get chat inbox error:', error);
    const status = String(error?.message || '').includes('Unauthorized') ? 403 : 500;
    return res.status(status).json({ message: error?.message || 'Failed to load chat inbox.' });
  }
});

async function handleGet(req, res, threadType, threadId) {
  const phone = requireOptionalAuthorizedPhone(req, res);
  if (!phone) return;
  if (!threadType || !threadId) {
    return res.status(400).json({ message: 'Thread type and id are required.' });
  }
  const messages = await getChatMessages(threadType, threadId, phone);
  return res.json(messages);
}

async function handlePost(req, res, threadType, threadId) {
  const phone = requireOptionalAuthorizedPhone(req, res);
  if (!phone) return;
  if (!threadType || !threadId) {
    return res.status(400).json({ message: 'Thread type and id are required.' });
  }
  const payload = { ...(req.body || {}) };
  payload.senderPhone = phone;
  payload.threadType = threadType;
  payload.threadId = threadId;
  payload.orderId = threadType === 'order' ? threadId : payload.orderId;

  const savedMessage = await saveChatMessage(payload);
  const receiverPhone = savedMessage.receiver_phone;
  if (receiverPhone) {
    notifyChatMessage(receiverPhone, {
      ...payload,
      ...savedMessage,
      senderName: payload.senderName || savedMessage.sender_name || null,
      threadType,
      threadId,
      orderId: threadType === 'order' ? threadId : '',
    }).catch((err) => console.error('chat push error:', err?.message || err));
  }
  return res.json(savedMessage);
}

router.get('/:threadType/:threadId', async (req, res) => {
  try {
    return await handleGet(req, res, req.params.threadType, req.params.threadId);
  } catch (error) {
    console.error('get chat error:', error);
    const status = String(error?.message || '').includes('Unauthorized') ? 403 : 500;
    return res.status(status).json({ message: error?.message || 'Failed to load chat messages.' });
  }
});

router.post('/:threadType/:threadId', async (req, res) => {
  try {
    return await handlePost(req, res, req.params.threadType, req.params.threadId);
  } catch (error) {
    console.error('save chat error:', error);
    const status = String(error?.message || '').includes('Unauthorized') ? 403 : 500;
    return res.status(status).json({ message: error?.message || 'Failed to send chat message.' });
  }
});

// توافق قديم: /db/chat/:orderId
router.get('/:orderId', async (req, res) => {
  try {
    return await handleGet(req, res, 'order', req.params.orderId);
  } catch (error) {
    console.error('get chat legacy error:', error);
    const status = String(error?.message || '').includes('Unauthorized') ? 403 : 500;
    return res.status(status).json({ message: error?.message || 'Failed to load chat messages.' });
  }
});

router.post('/:orderId', async (req, res) => {
  try {
    return await handlePost(req, res, 'order', req.params.orderId);
  } catch (error) {
    console.error('save chat legacy error:', error);
    const status = String(error?.message || '').includes('Unauthorized') ? 403 : 500;
    return res.status(status).json({ message: error?.message || 'Failed to send chat message.' });
  }
});

module.exports = router;
