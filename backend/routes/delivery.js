const express = require('express');
const router = express.Router();
const {
  getDeliveryPoolOrders,
  getCourierAssignedOrders,
  acceptDeliveryOrder,
  rejectDeliveryOrder,
  updateCourierDeliveryStatus,
} = require('../supabase_repo');
const {
  requireOptionalAuthorizedPhone,
} = require('./_middleware');

router.get('/delivery-pool', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const rows = await getDeliveryPoolOrders(phone);
    return res.json(rows);
  } catch (error) {
    console.error('get delivery-pool error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load delivery pool.' });
  }
});

router.get('/courier-orders', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const rows = await getCourierAssignedOrders(phone);
    return res.json(rows);
  } catch (error) {
    console.error('get courier-orders error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load courier orders.' });
  }
});

router.put('/delivery-order/accept', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const orderId = String(req.body?.orderId || req.body?.id || '').trim();
    if (!orderId) {
      return res.status(400).json({ message: 'Order id is required.' });
    }
    const row = await acceptDeliveryOrder(phone, orderId, req.body || {});
    return res.json(row);
  } catch (error) {
    console.error('accept delivery-order error:', error);
    const message = error?.message || 'Failed to accept delivery order.';
    const status = message.includes('not available') ? 409 : 500;
    return res.status(status).json({ message });
  }
});

router.put('/delivery-order/reject', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const orderId = String(req.body?.orderId || req.body?.id || '').trim();
    if (!orderId) {
      return res.status(400).json({ message: 'Order id is required.' });
    }
    const row = await rejectDeliveryOrder(phone, orderId);
    return res.json(row);
  } catch (error) {
    console.error('reject delivery-order error:', error);
    const message = error?.message || 'Failed to reject delivery order.';
    const status = message.includes('not available') ? 409 : 500;
    return res.status(status).json({ message });
  }
});

router.put('/delivery-order/status', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const orderId = String(req.body?.orderId || req.body?.id || '').trim();
    if (!orderId) {
      return res.status(400).json({ message: 'Order id is required.' });
    }
    const row = await updateCourierDeliveryStatus(phone, orderId, {
      deliveryStatusKey: req.body?.deliveryStatusKey,
      deliveryStatusAr: req.body?.deliveryStatusAr,
      deliveryStatusEn: req.body?.deliveryStatusEn,
    });
    return res.json(row);
  } catch (error) {
    console.error('update delivery-order status error:', error);
    const message = error?.message || 'Failed to update delivery status.';
    const status = message.includes('not assigned') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

module.exports = router;
