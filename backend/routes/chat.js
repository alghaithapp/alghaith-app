const express = require('express');
const router = express.Router();
const { getChatMessages, saveChatMessage } = require('../supabase_repo');
const { requireOptionalAuthorizedPhone } = require('./_middleware');
const { notifyChatMessage } = require('../push_events');

router.get('/:orderId', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const orderId = req.params.orderId;
    if (!orderId) return res.status(400).json({ message: 'Order ID is required.' });
    const messages = await getChatMessages(orderId);
    return res.json(messages);
  } catch (error) {
    console.error('get chat error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load chat messages.' });
  }
});

router.post('/:orderId', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const orderId = req.params.orderId;
    if (!orderId) return res.status(400).json({ message: 'Order ID is required.' });
    const payload = req.body;
    payload.senderPhone = phone;
    payload.orderId = orderId;
    const savedMessage = await saveChatMessage(payload);
    if (payload.receiverPhone) {
      notifyChatMessage(payload.receiverPhone, {
        ...payload,
        senderName: payload.senderName || null,
        orderId,
      }).catch((err) => console.error('chat push error:', err?.message || err));
    }
    return res.json(savedMessage);
  } catch (error) {
    console.error('save chat error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to send chat message.' });
  }
});

module.exports = router;
