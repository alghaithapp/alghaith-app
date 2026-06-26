const express = require('express');
const router = express.Router();
const {
  decodeBase64Image,
  uploadMediaWithVariants,
  getOwnerMediaGrouped,
} = require('../services/media_service');
const { pickVariantUrl } = require('../supabase_repo/media_assets');
const { requireAuthorizedPhone } = require('./_middleware');

router.post('/media/upload', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;

    const base64 = req.body?.imageBase64 ?? req.body?.image_base64 ?? req.body?.data;
    const buffer = decodeBase64Image(base64);
    if (!buffer || buffer.length === 0) {
      return res.status(400).json({ message: 'Valid image base64 is required.' });
    }

    const result = await uploadMediaWithVariants({
      phone,
      buffer,
      ownerType: String(req.body?.ownerType ?? req.body?.owner_type ?? 'user').trim(),
      ownerId: String(req.body?.ownerId ?? req.body?.owner_id ?? phone).trim(),
      role: String(req.body?.role ?? 'gallery').trim(),
    });
    return res.json({ success: true, ...result });
  } catch (error) {
    console.error('media upload error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to upload media.' });
  }
});

router.get('/media/assets', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const ownerType = String(req.query?.ownerType ?? req.query?.owner_type ?? 'user').trim();
    const ownerId = String(req.query?.ownerId ?? req.query?.owner_id ?? phone).trim();
    const role = String(req.query?.role ?? '').trim();
    const grouped = await getOwnerMediaGrouped(ownerType, ownerId, role || null);
    const preferred = String(req.query?.variant ?? '256').trim();
    return res.json({
      assets: grouped,
      url: role ? pickVariantUrl(grouped[role], preferred) : grouped,
    });
  } catch (error) {
    console.error('media assets error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load media assets.' });
  }
});

module.exports = router;
