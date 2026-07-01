const express = require('express');
const router = express.Router();

const { getAllConfigs, updateConfig, getTaxiPricing, getTaxiConfig, getMapDefaults, getHomeCategories, getSubCategories, getNeighborhoods, getNotificationTexts, getAppTheme, getCartConfig, getCategoryConfig, getDeliveryConfig, getErrorMessages } = require('../services/app_config_service');

// ── Public: قراءة إعدادات محددة ────────────────────────────────────

router.get('/taxi-pricing', async (_req, res) => {
  try {
    const data = await getTaxiPricing();
    return res.json(data);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

router.get('/taxi-config', async (_req, res) => {
  try {
    const data = await getTaxiConfig();
    return res.json(data);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

router.get('/map-defaults', async (_req, res) => {
  try {
    const data = await getMapDefaults();
    return res.json(data);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

router.get('/home-categories', async (_req, res) => {
  try {
    const data = await getHomeCategories();
    return res.json(data);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

router.get('/sub-categories', async (_req, res) => {
  try {
    const data = await getSubCategories();
    return res.json(data);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

router.get('/neighborhoods', async (_req, res) => {
  try {
    const data = await getNeighborhoods();
    return res.json(data);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

router.get('/notification-texts', async (_req, res) => {
  try {
    const data = await getNotificationTexts();
    return res.json(data);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

router.get('/app-theme', async (_req, res) => {
  try {
    const data = await getAppTheme();
    return res.json(data);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

router.get('/cart-config', async (_req, res) => {
  try { const data = await getCartConfig(); return res.json(data); }
  catch (error) { return res.status(500).json({ message: error.message }); }
});

router.get('/category-config', async (_req, res) => {
  try { const data = await getCategoryConfig(); return res.json(data); }
  catch (error) { return res.status(500).json({ message: error.message }); }
});

router.get('/delivery-config', async (_req, res) => {
  try { const data = await getDeliveryConfig(); return res.json(data); }
  catch (error) { return res.status(500).json({ message: error.message }); }
});

router.get('/error-messages', async (_req, res) => {
  try { const data = await getErrorMessages(); return res.json(data); }
  catch (error) { return res.status(500).json({ message: error.message }); }
});

// ── Admin: قراءة/تعديل كل الإعدادات ──────────────────────────────────

router.get('/admin/configs', async (req, res) => {
  try {
    const { requireOptionalAuthorizedPhone, assertAdminPermission } = require('./_middleware');
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    await assertAdminPermission(phone, 'canRegister');
    const data = await getAllConfigs();
    return res.json(data);
  } catch (error) {
    return res.status(403).json({ message: error.message });
  }
});

router.put('/admin/configs', async (req, res) => {
  try {
    const { requireOptionalAuthorizedPhone, assertAdminPermission } = require('./_middleware');
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    await assertAdminPermission(phone, 'canRegister');
    const { key, value } = req.body || {};
    if (!key) return res.status(400).json({ message: 'Config key is required.' });
    const result = await updateConfig(key, value);
    return res.json(result);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

module.exports = router;
