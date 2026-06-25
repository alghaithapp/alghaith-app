const express = require('express');
const router = express.Router();
const {
  getAppUser,
  saveAppUser,
  deleteAppUser,
  getCustomerProfile,
  saveCustomerProfile,
  deleteCustomerProfile,
  getCustomerAddresses,
  saveCustomerAddress,
  deleteCustomerAddress,
  getCustomerFavorites,
  saveCustomerFavorite,
  getCustomerOrders,
  mapOrderRow,
  saveCustomerOrder,
  saveDeviceToken,
  deleteDeviceToken,
  markPushInboxOpened,
} = require('../supabase_repo');
const {
  requireAuthorizedPhone,
  parseQueryValue,
} = require('./_middleware');
const { getUserState, saveUserState } = require('../supabase_repo');
const {
  serializeUserStateForClient,
  serializeCustomerProfileForClient,
} = require('../services/image_refs');

// ── App User ────────────────────────────────────────────────────────────

router.get('/app-user', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await getAppUser(phone);
    return res.json(row);
  } catch (error) {
    console.error('get app-user error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load app user.' });
  }
});

router.put('/app-user', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await saveAppUser(phone, req.body || {});
    return res.json(row);
  } catch (error) {
    console.error('save app-user error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to save app user.' });
  }
});

router.delete('/app-user', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    await deleteAppUser(phone);
    return res.json({ success: true });
  } catch (error) {
    console.error('delete app-user error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to delete app user.' });
  }
});

// ── Device Token ────────────────────────────────────────────────────────

router.put('/device-token', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await saveDeviceToken(phone, req.body || {});
    return res.json(row);
  } catch (error) {
    console.error('save device-token error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to save device token.' });
  }
});

router.delete('/device-token', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const token = String(req.body?.token || req.query?.token || '').trim();
    if (!token) {
      return res.status(400).json({ message: 'Device token is required.' });
    }
    await deleteDeviceToken(phone, token);
    return res.json({ success: true });
  } catch (error) {
    console.error('delete device-token error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to delete device token.' });
  }
});

router.put('/push-inbox/opened', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const result = await markPushInboxOpened(phone);
    return res.json(result);
  } catch (error) {
    console.error('mark push-inbox opened error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to mark inbox opened.' });
  }
});

// ── Customer Profile ────────────────────────────────────────────────────

router.get('/customer-profile', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await getCustomerProfile(phone);
    return res.json(serializeCustomerProfileForClient(row));
  } catch (error) {
    console.error('get customer-profile error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load customer profile.' });
  }
});

router.put('/customer-profile', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await saveCustomerProfile(phone, req.body || {});
    return res.json(serializeCustomerProfileForClient(row));
  } catch (error) {
    console.error('save customer-profile error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to save customer profile.' });
  }
});

router.delete('/customer-profile', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    await deleteCustomerProfile(phone);
    return res.json({ success: true });
  } catch (error) {
    console.error('delete customer-profile error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to delete customer profile.' });
  }
});

// ── Customer Addresses ──────────────────────────────────────────────────

router.get('/customer-addresses', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const rows = await getCustomerAddresses(phone);
    return res.json(rows);
  } catch (error) {
    console.error('get customer-addresses error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load customer addresses.' });
  }
});

router.put('/customer-address', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await saveCustomerAddress(phone, req.body || {});
    return res.json(row);
  } catch (error) {
    console.error('save customer-address error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to save customer address.' });
  }
});

router.delete('/customer-address', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    const address = String(parseQueryValue(req.query.address) || '').trim();
    if (!phone) return;
    if (!address) {
      return res.status(400).json({ message: 'Address is required.' });
    }
    await deleteCustomerAddress(phone, address);
    return res.json({ success: true });
  } catch (error) {
    console.error('delete customer-address error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to delete customer address.' });
  }
});

// ── Customer Favorites ──────────────────────────────────────────────────

router.get('/customer-favorites', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const rows = await getCustomerFavorites(phone);
    return res.json(rows);
  } catch (error) {
    console.error('get customer-favorites error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load customer favorites.' });
  }
});

router.put('/customer-favorite', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await saveCustomerFavorite(phone, req.body || {});
    return res.json(row);
  } catch (error) {
    console.error('save customer-favorite error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to save customer favorite.' });
  }
});

// ── Customer Orders ─────────────────────────────────────────────────────

router.get('/customer-orders', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const rows = await getCustomerOrders(phone);
    // تحويل كل صف من تنسيق قاعدة البيانات (snake_case + order_payload)
    // إلى تنسيق camelCase مسطّح ليتوافق مع نموذج ActiveOrder في Flutter
    const mapped = rows.map(mapOrderRow);
    return res.json(mapped);
  } catch (error) {
    console.error('get customer-orders error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load customer orders.' });
  }
});

router.put('/customer-order', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await saveCustomerOrder(phone, req.body || {});
    return res.json(row);
  } catch (error) {
    console.error('save customer-order error:', error);
    const message = error?.message || 'Failed to save customer order.';
    const status = message === 'MERCHANT_FROZEN' ? 409 : 500;
    return res.status(status).json({ message });
  }
});

// ── User State (للمستخدم العادي، بدون صلاحية أدمن) ─────────────────

router.get('/user-state', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const state = serializeUserStateForClient((await getUserState(phone)) || {});
    return res.json(state);
  } catch (error) {
    console.error('get user-state error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load user state.' });
  }
});

router.put('/user-state', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await saveUserState(phone, req.body?.state || {});
    const state = row?.state ?? (await getUserState(phone)) ?? {};
    return res.json(serializeUserStateForClient(state));
  } catch (error) {
    console.error('save user-state error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to save user state.' });
  }
});

module.exports = router;
