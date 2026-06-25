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
  getHomeCategoriesConfig,
  saveAdminHomeCategoriesConfig,
  getUserState,
  saveUserState,
  deleteUserState,
  ensurePlatformAdminAccess,
  preRegisterMerchantAccount,
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
    const reports = await getAdminReports(phone);
    return res.json(reports);
  } catch (error) {
    console.error('admin reports error:', error);
    const message = error?.message || 'Failed to load admin reports.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

// ── Merchants ───────────────────────────────────────────────────────────

router.get('/admin/merchants', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const merchants = await getAllMerchants(phone);
    return res.json(merchants);
  } catch (error) {
    console.error('admin merchants error:', error);
    const message = error?.message || 'Failed to load merchants.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

router.get('/admin/couriers', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const couriers = await getAllCouriers(phone);
    return res.json(couriers);
  } catch (error) {
    console.error('admin couriers error:', error);
    const message = error?.message || 'Failed to load couriers.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

router.get('/admin/drivers', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const drivers = await getAllDrivers(phone);
    return res.json(drivers);
  } catch (error) {
    console.error('admin drivers error:', error);
    const message = error?.message || 'Failed to load drivers.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

router.get('/admin/taxi/trips', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const taxiRepo = require('../supabase_repo/taxi');
    const trips = await taxiRepo.getAdminTaxiTrips(phone, {
      status: parseQueryValue(req.query.status),
      limit: Number(req.query.limit ?? 100),
    });
    return res.json(trips);
  } catch (error) {
    console.error('admin taxi trips error:', error);
    const message = error?.message || 'Failed to load taxi trips.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

router.get('/admin/taxi/complaints', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const taxiRepo = require('../supabase_repo/taxi');
    const complaints = await taxiRepo.getAdminTaxiComplaints(phone, {
      limit: Number(req.query.limit ?? 100),
    });
    return res.json(complaints);
  } catch (error) {
    console.error('admin taxi complaints error:', error);
    const message = error?.message || 'Failed to load taxi complaints.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

router.delete('/admin/driver', async (req, res) => {
  try {
    const adminPhone = requireOptionalAuthorizedPhone(req, res);
    if (!adminPhone) return;
    const driverPhone = String(parseQueryValue(req.query.driverPhone) || '').trim();
    if (!driverPhone) {
      return res.status(400).json({ message: 'Driver phone is required.' });
    }
    const { deleteDriverAccount } = require('../supabase_repo');
    const result = await deleteDriverAccount(adminPhone, driverPhone);
    return res.json(result);
  } catch (error) {
    console.error('admin delete-driver error:', error);
    const message = error?.message || 'Failed to delete driver account.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

router.get('/admin/merchant-details', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const merchantPhone = String(parseQueryValue(req.query.merchantPhone) || '').trim();
    if (!merchantPhone) {
      return res.status(400).json({ message: 'merchantPhone is required.' });
    }
    const details = await getAdminMerchantDetails(phone, merchantPhone);
    return res.json(details);
  } catch (error) {
    console.error('admin merchant-details error:', error);
    const message = error?.message || 'Failed to load merchant details.';
    const status = message.includes('Admin access')
      ? 403
      : message.includes('required')
        ? 400
        : message.includes('not found')
          ? 404
          : 500;
    return res.status(status).json({ message });
  }
});

router.put('/admin/merchant-approval', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const merchantPhone = String(req.body?.merchantPhone || '').trim();
    const isApproved = req.body?.isApproved === true;
    if (!merchantPhone) {
      return res.status(400).json({ message: 'merchantPhone is required.' });
    }
    const result = await toggleMerchantApprovalStatus(phone, merchantPhone, isApproved);
    return res.json(result);
  } catch (error) {
    console.error('toggle merchant approval error:', error);
    const message = error?.message || 'Failed to toggle merchant approval.';
    const status = message.includes('Admin access')
      ? 403
      : message.includes('not found')
        ? 404
        : 500;
    return res.status(status).json({ message });
  }
});

router.put('/admin/merchant-rejection', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const merchantPhone = String(req.body?.merchantPhone || '').trim();
    const reasonKey = String(req.body?.reasonKey || '').trim();
    const rejectionMessageAr = String(
      req.body?.rejectionMessageAr || req.body?.message || ''
    ).trim();
    if (!merchantPhone) {
      return res.status(400).json({ message: 'merchantPhone is required.' });
    }
    if (!reasonKey && !rejectionMessageAr) {
      return res.status(400).json({ message: 'Rejection reason is required.' });
    }
    const result = await rejectMerchantApplication(
      phone,
      merchantPhone,
      reasonKey,
      rejectionMessageAr
    );
    return res.json(result);
  } catch (error) {
    console.error('reject merchant error:', error);
    const message = error?.message || 'Failed to reject merchant application.';
    const status = message.includes('Admin access')
      ? 403
      : message.includes('not found') || message.includes('Invalid')
        ? 400
        : 500;
    return res.status(status).json({ message });
  }
});

router.put('/admin/merchant-bazaar', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const merchantPhone = String(req.body?.merchantPhone || '').trim();
    const isBazaarMember = req.body?.isBazaarMember === true;
    if (!merchantPhone) {
      return res.status(400).json({ message: 'merchantPhone is required.' });
    }
    const result = await toggleBazaarMemberStatus(phone, merchantPhone, isBazaarMember);
    return res.json(result);
  } catch (error) {
    console.error('toggle bazaar error:', error);
    const message = error?.message || 'Failed to toggle bazaar status.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

router.post('/admin/merchant-bazaar-sync', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const merchantPhone = String(req.body?.merchantPhone || '').trim();
    if (!merchantPhone) {
      return res.status(400).json({ message: 'merchantPhone is required.' });
    }
    const result = await syncMerchantProductsForBazaar(merchantPhone);
    return res.json({ success: true, ...result });
  } catch (error) {
    console.error('sync bazaar products error:', error);
    const message = error?.message || 'Failed to sync bazaar products.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

router.put('/admin/merchant-freeze', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const merchantPhone = String(req.body?.merchantPhone || '').trim();
    const isFrozen = req.body?.isFrozen === true;
    if (!merchantPhone) {
      return res.status(400).json({ message: 'merchantPhone is required.' });
    }
    const result = await toggleMerchantFreezeStatus(phone, merchantPhone, isFrozen);
    return res.json(result);
  } catch (error) {
    console.error('toggle freeze error:', error);
    const message = error?.message || 'Failed to toggle freeze status.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

router.post('/admin/merchant-pre-register', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const result = await preRegisterMerchantAccount(phone, req.body || {});
    return res.json(result);
  } catch (error) {
    console.error('merchant pre-register error:', error);
    const message = error?.message || 'Failed to pre-register merchant.';
    const status = message.includes('Admin access')
      ? 403
      : message.includes('بالفعل') ||
          message.includes('لا يمكن') ||
          message.includes('مطلوب') ||
          message.includes('غير صالح')
        ? 400
        : 500;
    return res.status(status).json({ message });
  }
});

// ── Couriers/Drivers Approvals ──────────────────────────────────────────

router.put('/admin/courier-approval', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const courierPhone = String(req.body?.courierPhone || '').trim();
    const isApproved = req.body?.isApproved === true;
    if (!courierPhone) {
      return res.status(400).json({ message: 'courierPhone is required.' });
    }
    const result = await toggleCourierApprovalStatus(phone, courierPhone, isApproved);
    return res.json(result);
  } catch (error) {
    console.error('toggle courier approval error:', error);
    const message = error?.message || 'Failed to toggle courier approval.';
    const status = message.includes('Admin access')
      ? 403
      : message.includes('not found')
        ? 404
        : 500;
    return res.status(status).json({ message });
  }
});

router.put('/admin/courier-rejection', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const courierPhone = String(req.body?.courierPhone || '').trim();
    const reasonKey = String(req.body?.reasonKey || '').trim();
    const rejectionMessageAr = String(
      req.body?.rejectionMessageAr || req.body?.message || ''
    ).trim();
    if (!courierPhone) {
      return res.status(400).json({ message: 'courierPhone is required.' });
    }
    if (!reasonKey && !rejectionMessageAr) {
      return res.status(400).json({ message: 'Rejection reason is required.' });
    }
    const result = await rejectCourierApplication(
      phone,
      courierPhone,
      reasonKey,
      rejectionMessageAr
    );
    return res.json(result);
  } catch (error) {
    console.error('reject courier error:', error);
    const message = error?.message || 'Failed to reject courier application.';
    const status = message.includes('Admin access')
      ? 403
      : message.includes('not found') || message.includes('Invalid')
        ? 400
        : 500;
    return res.status(status).json({ message });
  }
});

router.put('/admin/driver-approval', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const driverPhone = String(req.body?.driverPhone || '').trim();
    const isApproved = req.body?.isApproved === true;
    if (!driverPhone) {
      return res.status(400).json({ message: 'driverPhone is required.' });
    }
    const result = await toggleDriverApprovalStatus(phone, driverPhone, isApproved);
    return res.json(result);
  } catch (error) {
    console.error('toggle driver approval error:', error);
    const message = error?.message || 'Failed to toggle driver approval.';
    const status = message.includes('Admin access')
      ? 403
      : message.includes('not found')
        ? 404
        : 500;
    return res.status(status).json({ message });
  }
});

router.put('/admin/driver-rejection', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const driverPhone = String(req.body?.driverPhone || '').trim();
    const reasonKey = String(req.body?.reasonKey || '').trim();
    const rejectionMessageAr = String(
      req.body?.rejectionMessageAr || req.body?.message || ''
    ).trim();
    if (!driverPhone) {
      return res.status(400).json({ message: 'driverPhone is required.' });
    }
    if (!reasonKey && !rejectionMessageAr) {
      return res.status(400).json({ message: 'Rejection reason is required.' });
    }
    const result = await rejectDriverApplication(
      phone,
      driverPhone,
      reasonKey,
      rejectionMessageAr
    );
    return res.json(result);
  } catch (error) {
    console.error('reject driver error:', error);
    const message = error?.message || 'Failed to reject driver application.';
    const status = message.includes('Admin access')
      ? 403
      : message.includes('not found') || message.includes('required')
        ? 400
        : 500;
    return res.status(status).json({ message });
  }
});

// ── Accounts ────────────────────────────────────────────────────────────

router.get('/admin/accounts', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const accounts = await getAllAdminAccounts(phone);
    return res.json(accounts);
  } catch (error) {
    console.error('admin accounts error:', error);
    const message = error?.message || 'Failed to load accounts.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

router.delete('/admin/account', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const accountPhone = String(
      req.body?.accountPhone || req.query?.accountPhone || ''
    ).trim();
    if (!accountPhone) {
      return res.status(400).json({ message: 'accountPhone is required.' });
    }
    const result = await adminDeleteAccount(phone, accountPhone);
    return res.json(result);
  } catch (error) {
    console.error('admin account delete error:', error);
    const message = error?.message || 'Failed to delete account.';
    const status = message.includes('Admin access')
      ? 403
      : message.includes('not found') || message.includes('Cannot')
        ? 400
        : 500;
    return res.status(status).json({ message });
  }
});

router.put('/admin/account-suspend', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const accountPhone = String(req.body?.accountPhone || '').trim();
    const isSuspended = req.body?.isSuspended === true;
    if (!accountPhone) {
      return res.status(400).json({ message: 'accountPhone is required.' });
    }
    const result = await adminSuspendAccount(phone, accountPhone, isSuspended);
    return res.json(result);
  } catch (error) {
    console.error('admin account suspend error:', error);
    const message = error?.message || 'Failed to update account suspension.';
    const status = message.includes('Admin access')
      ? 403
      : message.includes('not found') || message.includes('Cannot')
        ? 400
        : 500;
    return res.status(status).json({ message });
  }
});

router.put('/admin/account-role', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const accountPhone = String(req.body?.accountPhone || '').trim();
    const newRole = String(req.body?.role || '').trim();
    if (!accountPhone) {
      return res.status(400).json({ message: 'accountPhone is required.' });
    }
    if (!newRole) {
      return res.status(400).json({ message: 'role is required.' });
    }
    const result = await updateAccountRole(phone, accountPhone, newRole);
    return res.json(result);
  } catch (error) {
    console.error('admin account-role error:', error);
    const message = error?.message || 'Failed to update account role.';
    const status = message.includes('Admin access')
      ? 403
      : message.includes('not found') || message.includes('required')
        ? 400
        : 500;
    return res.status(status).json({ message });
  }
});

// ── App Update Policy (admin) ───────────────────────────────────────────

router.get('/admin/app-update-policy', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const policy = await getAppUpdatePolicy();
    return res.json(policy);
  } catch (error) {
    console.error('admin app update policy read error:', error);
    const message = error?.message || 'Failed to load app update policy.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

router.put('/admin/app-update-policy', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const policy = await saveAdminAppUpdatePolicy(phone, {
      minBuildNumber: req.body?.minBuildNumber ?? req.body?.min_build_number,
      minVersionName: req.body?.minVersionName ?? req.body?.min_version_name,
      messageAr: req.body?.messageAr ?? req.body?.message_ar,
      androidStoreUrl: req.body?.androidStoreUrl ?? req.body?.android_store_url,
      iosStoreUrl: req.body?.iosStoreUrl ?? req.body?.ios_store_url,
    });
    return res.json({ success: true, policy });
  } catch (error) {
    console.error('admin app update policy save error:', error);
    const message = error?.message || 'Failed to save app update policy.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

// ── Home Categories (admin) ─────────────────────────────────────────────

router.get('/admin/home-categories', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const config = await getHomeCategoriesConfig();
    return res.json(config);
  } catch (error) {
    console.error('admin home categories read error:', error);
    const message = error?.message || 'Failed to load home categories.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

router.put('/admin/home-categories', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const overrides = req.body?.overrides;
    if (!overrides || typeof overrides !== 'object') {
      return res.status(400).json({ message: 'overrides object is required.' });
    }
    const result = await saveAdminHomeCategoriesConfig(phone, overrides);
    return res.json(result);
  } catch (error) {
    console.error('save home categories error:', error);
    const message = error?.message || 'Failed to save home categories.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

// ── Admin Roles ─────────────────────────────────────────────────────────

router.get('/admin/roles', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const { getAdminRole, listAdminAccounts } = require('../supabase_repo');
    const [role, accounts] = await Promise.all([
      getAdminRole(phone),
      listAdminAccounts(phone),
    ]);
    return res.json({ role, accounts });
  } catch (error) {
    logger.error('admin roles list error', { error: error.message });
    const status = error.message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message: error.message });
  }
});

router.put('/admin/roles', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const targetPhone = String(req.body?.targetPhone || '').trim();
    const newRole = String(req.body?.role || '').trim();
    if (!targetPhone) {
      return res.status(400).json({ message: 'targetPhone is required.' });
    }
    const { setAdminRole } = require('../supabase_repo');
    const result = await setAdminRole(phone, targetPhone, newRole || null);
    return res.json(result);
  } catch (error) {
    logger.error('admin roles set error', { error: error.message });
    const status = error.message.includes('Admin access') || error.message.includes('Only super admins')
      ? 403
      : error.message.includes('Invalid role')
        ? 400
        : 500;
    return res.status(status).json({ message: error.message });
  }
});

// ── User State ──────────────────────────────────────────────────────────

router.get('/user-state', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    await ensurePlatformAdminAccess(phone);
    const state = (await getUserState(phone)) || {};
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
    return res.json(row);
  } catch (error) {
    console.error('save user-state error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to save user state.' });
  }
});

router.delete('/user-state', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    await deleteUserState(phone);
    return res.json({ success: true });
  } catch (error) {
    console.error('delete user-state error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to delete user state.' });
  }
});

module.exports = router;
