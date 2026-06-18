const express = require('express');
const router = express.Router();
const {
  getMerchantProfile,
  saveMerchantProfile,
  deleteMerchantProfile,
  getMerchantProducts,
  saveMerchantProduct,
  deleteMerchantProduct,
  listProfessionalProfiles,
  saveMerchantReview,
  getMerchantIncomingOrders,
  updateIncomingOrderStatus,
} = require('../supabase_repo');
const {
  requireAuthorizedPhone,
  requireOptionalAuthorizedPhone,
  parseQueryValue,
} = require('./_middleware');

// ── Merchant Profile ────────────────────────────────────────────────────

router.get('/merchant-profile', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await getMerchantProfile(phone);
    return res.json(row);
  } catch (error) {
    console.error('get merchant-profile error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load merchant profile.' });
  }
});

router.put('/merchant-profile', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await saveMerchantProfile(phone, req.body || {});
    return res.json(row);
  } catch (error) {
    console.error('save merchant-profile error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to save merchant profile.' });
  }
});

router.delete('/merchant-profile', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    await deleteMerchantProfile(phone);
    return res.json({ success: true });
  } catch (error) {
    console.error('delete merchant-profile error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to delete merchant profile.' });
  }
});

// ── Merchant Products ───────────────────────────────────────────────────

router.get('/merchant-products', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const rows = await getMerchantProducts(phone);
    return res.json(rows);
  } catch (error) {
    console.error('get merchant-products error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load merchant products.' });
  }
});

router.put('/merchant-product', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await saveMerchantProduct(phone, req.body || {});
    return res.json(row);
  } catch (error) {
    console.error('save merchant-product error:', error);
    const message = error?.message || 'Failed to save merchant product.';
    const status = message === 'BAZAAR_APPROVAL_REQUIRED' ? 409 : 500;
    return res.status(status).json({ message });
  }
});

router.delete('/merchant-product', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    const id = String(parseQueryValue(req.query.id) || '').trim();
    if (!phone) return;
    if (!id) {
      return res.status(400).json({ message: 'Product id is required.' });
    }
    await deleteMerchantProduct(id, phone);
    return res.json({ success: true });
  } catch (error) {
    console.error('delete merchant-product error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to delete merchant product.' });
  }
});

// ── Professionals (public) ──────────────────────────────────────────────

router.get('/professionals', async (req, res) => {
  try {
    const professionId = String(parseQueryValue(req.query.professionId) || '').trim();
    const rows = await listProfessionalProfiles(professionId);
    return res.json(rows);
  } catch (error) {
    console.error('list professionals error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load professionals.' });
  }
});

// ── Merchant Review ─────────────────────────────────────────────────────

router.post('/merchant-review', async (req, res) => {
  try {
    const { merchantPhone, customerPhone, customerName, orderId, stars, comment } = req.body;
    if (!merchantPhone || !customerPhone || !orderId || !stars) {
      return res.status(400).json({ message: 'Missing required review fields.' });
    }
    const result = await saveMerchantReview({
      merchantPhone,
      customerPhone,
      customerName,
      orderId,
      stars,
      comment
    });
    return res.json(result);
  } catch (error) {
    console.error('merchant-review error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to save review.' });
  }
});

// ── Merchant Incoming Orders ────────────────────────────────────────────

router.get('/merchant-incoming-orders', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const rows = await getMerchantIncomingOrders(phone);
    return res.json(rows);
  } catch (error) {
    console.error('get merchant-incoming-orders error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load merchant orders.' });
  }
});

router.put('/incoming-order-status', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const orderId = String(req.body?.orderId || req.body?.id || '').trim();
    if (!orderId) {
      return res.status(400).json({ message: 'Order id is required.' });
    }
    const row = await updateIncomingOrderStatus(phone, orderId, {
      statusKey: req.body?.statusKey,
      statusAr: req.body?.statusAr,
      statusEn: req.body?.statusEn,
      noteAr: req.body?.noteAr,
      noteEn: req.body?.noteEn,
      deliveryStatusKey: req.body?.deliveryStatusKey,
      deliveryStatusAr: req.body?.deliveryStatusAr,
      deliveryStatusEn: req.body?.deliveryStatusEn,
      lineItems: req.body?.lineItems,
      price: req.body?.price,
      itemsCount: req.body?.itemsCount,
      itemsNameAr: req.body?.itemsNameAr,
      itemsNameEn: req.body?.itemsNameEn,
      originalPrice: req.body?.originalPrice,
      itemsSubtotalIqd: req.body?.itemsSubtotalIqd,
      deliveryFeeIqd: req.body?.deliveryFeeIqd,
      promoDiscountIqd: req.body?.promoDiscountIqd,
      merchantDecisionAt: req.body?.merchantDecisionAt,
      isPriceLocked: req.body?.isPriceLocked,
    });
    return res.json(row);
  } catch (error) {
    console.error('update incoming-order-status error:', error);
    const status = String(error?.message || '').includes('not allowed') ? 403 : 500;
    return res.status(status).json({ message: error?.message || 'Failed to update order status.' });
  }
});

module.exports = router;
