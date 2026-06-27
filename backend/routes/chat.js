const express = require('express');
const router = express.Router();
const { getChatMessages, getChatInbox, saveChatMessage, markThreadAsRead, deleteChatThread, mapChatAccessError } = require('../supabase_repo');
const { requireOptionalAuthorizedPhone } = require('./_middleware');
const { notifyChatMessage } = require('../push_events');

function chatErrorStatus(message) {
  const text = String(message || '');
  if (text.includes('Unauthorized') || text.includes('غير مصرّح')) return 403;
  if (
    text.includes('not found') ||
    text.includes('غير موجود')
  ) {
    return 404;
  }
  return 500;
}

function chatErrorMessage(error) {
  return mapChatAccessError(error?.message) || 'تعذّر إكمال طلب المحادثة.';
}

router.get('/inbox/threads', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const threads = await getChatInbox(phone);
    return res.json(threads);
  } catch (error) {
    console.error('get chat inbox error:', error);
    const message = chatErrorMessage(error);
    return res.status(chatErrorStatus(message)).json({ message });
  }
});

router.post('/:threadType/:threadId/read', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const threadType = String(req.params.threadType || '').trim();
    const threadId = String(req.params.threadId || '').trim();
    if (!threadType || !threadId) {
      return res.status(400).json({ message: 'Thread type and id are required.' });
    }
    const result = await markThreadAsRead(
      threadType,
      threadId,
      phone,
      req.body?.otherPartyPhone ?? req.body?.other_party_phone,
    );
    return res.json(result);
  } catch (error) {
    console.error('mark chat read error:', error);
    const message = chatErrorMessage(error);
    return res.status(chatErrorStatus(message)).json({ message });
  }
});

router.delete('/:threadType/:threadId', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const threadType = String(req.params.threadType || '').trim();
    const threadId = String(req.params.threadId || '').trim();
    if (!threadType || !threadId) {
      return res.status(400).json({ message: 'Thread type and id are required.' });
    }
    const otherPartyPhone =
      req.query?.otherPartyPhone ??
      req.query?.other_party_phone ??
      req.body?.otherPartyPhone ??
      req.body?.other_party_phone;
    const result = await deleteChatThread(threadType, threadId, phone, otherPartyPhone);
    return res.json(result);
  } catch (error) {
    console.error('delete chat thread error:', error);
    const message = chatErrorMessage(error);
    return res.status(chatErrorStatus(message)).json({ message });
  }
});

async function handleGet(req, res, threadType, threadId) {
  const phone = requireOptionalAuthorizedPhone(req, res);
  if (!phone) return;
  if (!threadType || !threadId) {
    return res.status(400).json({ message: 'Thread type and id are required.' });
  }
  const messages = await getChatMessages(threadType, threadId, phone, {
    limit: Number(req.query.limit) || undefined,
    offset: Number(req.query.offset) || undefined,
    after: String(req.query.after || '').trim() || undefined,
  });
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
    const message = chatErrorMessage(error);
    return res.status(chatErrorStatus(message)).json({ message });
  }
});

router.post('/:threadType/:threadId', async (req, res) => {
  try {
    return await handlePost(req, res, req.params.threadType, req.params.threadId);
  } catch (error) {
    console.error('save chat error:', error);
    const message = chatErrorMessage(error);
    return res.status(chatErrorStatus(message)).json({ message });
  }
});

// توافق قديم: /db/chat/:orderId
router.get('/:orderId', async (req, res) => {
  try {
    return await handleGet(req, res, 'order', req.params.orderId);
  } catch (error) {
    console.error('get chat legacy error:', error);
    const message = chatErrorMessage(error);
    return res.status(chatErrorStatus(message)).json({ message });
  }
});

router.post('/:orderId', async (req, res) => {
  try {
    return await handlePost(req, res, 'order', req.params.orderId);
  } catch (error) {
    console.error('save chat legacy error:', error);
    const message = chatErrorMessage(error);
    return res.status(chatErrorStatus(message)).json({ message });
  }
});

module.exports = router;
