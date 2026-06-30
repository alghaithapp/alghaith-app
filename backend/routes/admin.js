const express = require('express');
const router = express.Router();
const {
  getAdminReports,
  getAllMerchants,
  getAllCouriers,
  getAllDrivers,
  getAdminMerchantDetails,
  toggleMerchantApprovalStatus,
  rejectMerchantApplication,
  toggleBazaarMemberStatus,
  syncMerchantProductsForBazaar,
  toggleMerchantFreezeStatus,
  toggleCourierApprovalStatus,
  rejectCourierApplication,
  toggleDriverApprovalStatus,
  rejectDriverApplication,
  getAllAdminAccounts,
  adminDeleteAccount,
  adminSuspendAccount,
  updateAccountRole,
  getAppUpdatePolicy,
  saveAdminAppUpdatePolicy,
  getMaintenancePolicy,
  saveAdminMaintenancePolicy,
  getHomeCategoriesConfig,
  saveAdminHomeCategoriesConfig,
  getUserState,
  saveUserState,
  deleteUserState,
  ensurePlatformAdminAccess,
  preRegisterMerchantAccount,
  preRegisterDriverAccount,
} = require('../supabase_repo');
const logger = require('../lib/logger');
const {
  requireAuthorizedPhone,
  requireOptionalAuthorizedPhone,
  parseQueryValue,
} = require('./_middleware');

// ── Reports ─────────────────────────────────────────────────────────────

router.get('/admin/reports', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;

    const { title, body, audience, storeUpdate } = req.body;
    if (!title?.trim() || !body?.trim()) {
      return res.status(400).json({ message: 'العنوان والنص مطلوبان.' });
    }

    const { assertSupabaseAdmin } = require('../supabase_repo/common');
    const supabase = assertSupabaseAdmin();
    let query = supabase.from('device_tokens').select('token, platform');

    switch (audience) {
      case 'drivers':
        const driverPhones = (await supabase.from('driver_profiles').select('phone'))
          .data?.map(r => r.phone) || [];
        if (driverPhones.length > 0) query = query.in('phone', driverPhones);
        else return res.json({ message: 'لا يوجد سائقون.', sent: 0 });
        break;
      case 'merchants':
        const merchantPhones = (await supabase.from ('merchant_profiles').select('phone'))
          .data?.map(r => r.phone) || [];
        if (merchantPhones.length > 0) query = query.in('phone', merchantPhones);
        else return res.json({ message: 'لا يوجد تجار.', sent: 0 });
        break;
      case 'customers':
        const customerPhones = (await supabase.from('customer_profiles').select('phone'))
          .data?.map(r => r.phone) || [];
        if (customerPhones.length > 0) query = query.in('phone', customerPhones);
        else return res.json({ message: 'لا يوجد زبائن.', sent: 0 });
        break;
      case 'all':
      default:
        break;
    }

    const { data: tokens } = await query;
    if (!tokens?.length) {
      return res.json({ message: 'لا توجد أجهزة مسجلة لهذا الجمهور.', sent: 0 });
    }

    const uniqueTokens = [...new Set(tokens.map(t => t.token).filter(Boolean))];
    const platforms = [...new Set(tokens.map(t => t.platform).filter(Boolean))];

    const { sendPushToTokensDirect } = require('../services/notification_delivery');
    const result = await sendPushToTokensDirect(uniqueTokens, {
      title: title.trim(),
      body: body.trim(),
      data: {
        category: 'admin',
        audience: audience || 'all',
        eventKey: 'admin:manual_push',
        storeUpdate: storeUpdate === true ? 'true' : 'false',
      },
      showSystemBanner: true,
    });

    return res.json({
      sent: result.sent || 0,
      failed: result.failed || 0,
      invalidTokens: result.invalidTokens?.length || 0,
      tokenCount: uniqueTokens.length,
      platforms,
      message: `تم الإرسال إلى ${result.sent} جهاز${result.failed > 0 ? `، فشل: ${result.failed}` : ''}.`,
    });
  } catch (error) {
    console.error('admin push send error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to send push notification.' });
  }
});

/// إشعارات لوحة الأدمن
router.get('/admin/notifications', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;

    const { assertSupabaseAdmin } = require('../supabase_repo/common');
    const supabase = assertSupabaseAdmin();
    const limit = Math.min(Number(req.query.limit) || 50, 200);
    const unreadOnly = req.query.unreadOnly === 'true';

    let query = supabase
      .from('admin_notifications')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(limit);

    if (unreadOnly) query = query.eq('is_read', false);

    const { data, error } = await query;
    if (error) throw new Error(error.message);

    return res.json(data || []);
  } catch (error) {
    console.error('admin notifications fetch error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to fetch notifications.' });
  }
});

router.put('/admin/notifications/read', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;

    const { assertSupabaseAdmin } = require('../supabase_repo/common');
    const supabase = assertSupabaseAdmin();
    const { ids } = req.body;

    if (Array.isArray(ids) && ids.length > 0) {
      await supabase.from('admin_notifications').update({ is_read: true }).in('id', ids);
    } else {
      await supabase.from('admin_notifications').update({ is_read: true }).eq('is_read', false);
    }

    return res.json({ success: true });
  } catch (error) {
    console.error('admin notifications mark read error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to mark notifications as read.' });
  }
});

/// إضافة إشعار للأدمن
async function insertAdminNotification(type, title, body, data = {}) {
  try {
    const { assertSupabaseAdmin } = require('../supabase_repo/common');
    const supabase = assertSupabaseAdmin();
    await supabase.from('admin_notifications').insert({
      type,
      title,
      body,
      data: { ...data, timestamp: new Date().toISOString() },
    });
  } catch (e) {
    console.error('insertAdminNotification error:', e?.message || e);
  }
}

module.exports = router;
