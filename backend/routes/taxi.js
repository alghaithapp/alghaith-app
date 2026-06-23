const express = require('express');
const router = express.Router();
const { normalizeTaxiType } = require('../services/taxi_pricing_service');
const repo = require('../supabase_repo/taxi');
const { getUserState } = require('../supabase_repo/users');
const { requireOptionalAuthorizedPhone } = require('./_middleware');

function formatRequestRow(row) {
  return repo.formatTaxiRequestForClient(row);
}

async function formatRequestRowEnriched(row) {
  return repo.enrichTaxiRequestForClient(row);
}

// POST /db/taxi/create - إنشاء طلب جديد (يحسب السعر تلقائياً)
router.post('/create', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const result = await repo.createTaxiRequest(phone, req.body || {});
    return res.json(result);
  } catch (error) {
    console.error('taxi create error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to create taxi request.' });
  }
});

// POST /db/taxi/accept - قبول السائق
router.post('/accept', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const { requestId, driverName, vehicleModel, plateNumber } = req.body || {};
    const result = await repo.acceptTaxiRequest(phone, requestId, { driverName, vehicleModel, plateNumber });
    return res.json(result);
  } catch (error) {
    console.error('taxi accept error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to accept taxi request.' });
  }
});

// POST /db/taxi/reject - رفض السائق
router.post('/reject', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const { requestId } = req.body || {};
    const result = await repo.rejectTaxiRequest(phone, requestId);
    return res.json(result);
  } catch (error) {
    console.error('taxi reject error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to reject taxi request.' });
  }
});

// POST /db/taxi/cancel - إلغاء من الزبون
router.post('/cancel', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const { requestId, reason } = req.body || {};
    const result = await repo.cancelTaxiRequest(phone, requestId, reason);
    return res.json(result);
  } catch (error) {
    console.error('taxi cancel error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to cancel taxi request.' });
  }
});

// POST /db/taxi/status - تحديث حالة الرحلة
router.post('/status', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const { requestId, statusKey } = req.body || {};
    const result = await repo.updateTaxiRequestStatus(phone, requestId, statusKey);
    return res.json(result);
  } catch (error) {
    console.error('taxi status error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to update taxi request status.' });
  }
});

// GET /db/taxi/active - الطلب النشط للزبون
router.get('/active', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const request = await repo.getCustomerActiveRequest(phone);
    if (!request) return res.json(null);
    return res.json(await formatRequestRowEnriched(request));
  } catch (error) {
    console.error('taxi active error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to get active request.' });
  }
});

// GET /db/taxi/driver-active - الطلب النشط للسائق
router.get('/driver-active', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const request = await repo.getDriverActiveRequest(phone);
    if (!request) return res.json(null);
    return res.json(await formatRequestRowEnriched(request));
  } catch (error) {
    console.error('taxi driver-active error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to get driver active request.' });
  }
});

// GET /db/taxi/history - تاريخ رحلات الزبون
router.get('/history', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const requests = await repo.getCustomerHistory(phone);
    return res.json((requests || []).map(formatRequestRow));
  } catch (error) {
    console.error('taxi history error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to get history.' });
  }
});

// GET /db/taxi/driver-history - تاريخ رحلات السائق
router.get('/driver-history', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const requests = await repo.getDriverHistory(phone);
    return res.json((requests || []).map(formatRequestRow));
  } catch (error) {
    console.error('taxi driver-history error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to get driver history.' });
  }
});

// POST /db/taxi/driver-status - تحديث حالة اتصال السائق (متصل/غير متصل)
router.post('/driver-status', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const isOnline = req.body?.isOnline === true;
    const result = await repo.setDriverOnlineStatus(phone, isOnline);
    return res.json(result);
  } catch (error) {
    console.error('taxi driver-status error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to update driver status.' });
  }
});

// GET /db/taxi/nearby-drivers - البحث عن سائقين قريبين
router.get('/nearby-drivers', async (req, res) => {
  try {
    const { lat, lng, taxiType } = req.query;
    const pickupLat = Number(req.query.pickupLat ?? lat ?? 0);
    const pickupLng = Number(req.query.pickupLng ?? lng ?? 0);
    const drivers = await repo.getNearbyDrivers(
      pickupLat,
      pickupLng,
      String(taxiType || 'economic').trim(),
      [],
      10
    );
    return res.json(drivers);
  } catch (error) {
    console.error('taxi nearby-drivers error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to get nearby drivers.' });
  }
});

// GET /db/taxi/incoming-requests - الطلبات الواردة للسائق
// يقبل lat/lng من query params (موقع حالي) أو من ملف السائق المحفوظ
router.get('/incoming-requests', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;

    // محاولة استخدام الموقع المرسل من التطبيق أولاً
    let lat = Number(req.query.lat ?? 0);
    let lng = Number(req.query.lng ?? 0);

    // إذا لم يُرسَل الموقع، نجلبه من ملف السائق المحفوظ
    if (!lat || !lng) {
      const state = await getUserState(phone);
      const profile = state?.driverProfile;
      if (profile) {
        lat = Number(profile.latitude ?? profile.lat ?? 0);
        lng = Number(profile.longitude ?? profile.lng ?? 0);
      }
    }

    // إذا لا يزال الموقع مجهولاً، نرجع كل الطلبات المعلقة بدون فلتر مسافة
    const taxiType = normalizeTaxiType(
      req.query.taxiType ||
      (await getUserState(phone))?.driverProfile?.taxiType ||
      'economic'
    );

    const requests = await repo.getDriverIncomingRequests(
      phone,
      lat || null,
      lng || null,
      taxiType,
    );
    return res.json(requests);
  } catch (error) {
    console.error('taxi incoming-requests error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to get incoming requests.' });
  }
});

module.exports = router;
