const express = require('express');
const router = express.Router();
const {
  getCustomerTaxiRequests,
  saveTaxiRequest,
  getTaxiPoolOrders,
  getDriverTaxiOrders,
  acceptTaxiRequest,
  updateTaxiRequestStatus,
  rejectTaxiRequest,
  driverCancelTaxiRequest,
} = require('../supabase_repo');
const {
  requireAuthorizedPhone,
  requireOptionalAuthorizedPhone,
} = require('./_middleware');

router.get('/customer-taxi-requests', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const rows = await getCustomerTaxiRequests(phone);
    return res.json(rows);
  } catch (error) {
    console.error('get customer-taxi-requests error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load taxi requests.' });
  }
});

router.put('/taxi-request', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await saveTaxiRequest(phone, req.body || {});
    return res.json(row);
  } catch (error) {
    console.error('save taxi-request error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to save taxi request.' });
  }
});

router.get('/taxi-pool', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const rows = await getTaxiPoolOrders(phone);
    return res.json(rows);
  } catch (error) {
    console.error('get taxi-pool error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load taxi pool.' });
  }
});

router.get('/driver-taxi-orders', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const rows = await getDriverTaxiOrders(phone);
    return res.json(rows);
  } catch (error) {
    console.error('get driver-taxi-orders error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load driver taxi orders.' });
  }
});

router.put('/taxi-request/accept', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const requestId = String(
      req.body?.requestId || req.body?.orderId || req.body?.id || ''
    ).trim();
    if (!requestId) {
      return res.status(400).json({ message: 'Request id is required.' });
    }
    const row = await acceptTaxiRequest(phone, requestId, req.body || {});
    return res.json(row);
  } catch (error) {
    console.error('accept taxi-request error:', error);
    const message = error?.message || 'Failed to accept taxi request.';
    const status = message.includes('not available') ? 409 : 500;
    return res.status(status).json({ message });
  }
});

router.put('/taxi-request/status', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const requestId = String(
      req.body?.requestId || req.body?.orderId || req.body?.id || ''
    ).trim();
    if (!requestId) {
      return res.status(400).json({ message: 'Request id is required.' });
    }
    const row = await updateTaxiRequestStatus(phone, requestId, {
      statusKey: req.body?.statusKey,
      statusAr: req.body?.statusAr,
      statusEn: req.body?.statusEn,
      assignedDriverName: req.body?.assignedDriverName,
      vehicleType: req.body?.vehicleType,
    });
    return res.json(row);
  } catch (error) {
    console.error('update taxi-request status error:', error);
    const message = error?.message || 'Failed to update taxi status.';
    const status =
      message.includes('not assigned') || message.includes('not authorized')
        ? 403
        : 500;
    return res.status(status).json({ message });
  }
});

router.put('/taxi-request/reject', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const requestId = String(
      req.body?.requestId || req.body?.orderId || req.body?.id || ''
    ).trim();
    if (!requestId) {
      return res.status(400).json({ message: 'Request id is required.' });
    }
    const row = await rejectTaxiRequest(phone, requestId);
    return res.json(row);
  } catch (error) {
    console.error('reject taxi-request error:', error);
    const message = error?.message || 'Failed to reject taxi request.';
    const status = message.includes('not available') ? 409 : 500;
    return res.status(status).json({ message });
  }
});

router.put('/taxi-request/driver-cancel', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const requestId = String(
      req.body?.requestId || req.body?.orderId || req.body?.id || ''
    ).trim();
    if (!requestId) {
      return res.status(400).json({ message: 'Request id is required.' });
    }
    const reason = String(req.body?.reason || '').trim();
    const row = await driverCancelTaxiRequest(phone, requestId, reason);
    return res.json(row);
  } catch (error) {
    console.error('driver-cancel taxi-request error:', error);
    const message = error?.message || 'Failed to cancel taxi request.';
    return res.status(500).json({ message });
  }
});

module.exports = router;
