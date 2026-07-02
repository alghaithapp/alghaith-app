const express = require('express');
const router = express.Router();
const {
  getAdminReports,
  getAllMerchants,
  getAllProfessionals,
  getAllCouriers,
  getAllDrivers,
  getAdminMerchantDetails,
  getAdminProfessionalDetails,
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
  getPendingProductsForAdmin,
  toggleProductApprovalStatus,
  mapAdminProductRow,
  getHomeCategoriesConfig,
  saveAdminHomeCategoriesConfig,
  getUserState,
  saveUserState,
  deleteUserState,
  ensurePlatformAdminAccess,
  preRegisterMerchantAccount,
  updateMerchantCategoryByAdmin,
  preRegisterCustomerAccount,
  preRegisterDriverAccount,
  preRegisterCourierAccount,
  preRegisterProfessionalAccount,
  preRegisterBeautyAccount,
  broadcastAdminUserMessage,
  getSupportThreadsForAdmin,
} = require('../supabase_repo');
const logger = require('../lib/logger');
const {
  requireAuthorizedPhone,
  requireOptionalAuthorizedPhone,
  parseQueryValue,
} = require('./_middleware');

const { assertAdminPermission } = require('../supabase_repo');
const { getAdminRole, hasMinRole } = require('../supabase_repo/admin_roles');

async function requireMinAdminRole(req, res, adminPhone, minRole) {
  const role = await getAdminRole(adminPhone);
  if (!role) {
    res.status(403).json({ message: 'Admin access required.' });
    return null;
  }
  if (!hasMinRole(role, minRole)) {
    res.status(403).json({ message: `Requires ${minRole} role or higher.` });
    return null;
  }
  return role;
}

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

router.get('/admin/professionals', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const professionals = await getAllProfessionals(phone);
    return res.json(professionals);
  } catch (error) {
    console.error('admin professionals error:', error);
    const message = error?.message || 'Failed to load professionals.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

router.get('/admin/professional-details', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const professionalPhone = String(parseQueryValue(req.query.professionalPhone) || '').trim();
    if (!professionalPhone) {
      return res.status(400).json({ message: 'professionalPhone is required.' });
    }
    const details = await getAdminProfessionalDetails(phone, professionalPhone);
    return res.json(details);
  } catch (error) {
    console.error('admin professional-details error:', error);
    const message = error?.message || 'Failed to load professional details.';
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
    await assertAdminPermission(adminPhone, 'canDelete');
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
    await assertAdminPermission(phone, 'canApprove');
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
    await assertAdminPermission(phone, 'canApprove');
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
    const adminPhone = requireOptionalAuthorizedPhone(req, res);
    if (!adminPhone) return;
    const adminRole = await requireMinAdminRole(req, res, adminPhone, 'moderator');
    if (!adminRole) return;
    
    const merchantPhone = String(req.body?.merchantPhone ?? req.body?.phone ?? '').trim();
    if (!merchantPhone) {
      return res.status(400).json({ message: 'merchantPhone is required' });
    }
    
    await syncMerchantProductsForBazaar(merchantPhone);
    return res.json({ success: true });
  } catch (error) {
    console.error('sync bazaar products error:', error);
    const message = error?.message || 'Failed to sync bazaar products.';
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

const { getMerchantProducts, saveMerchantProduct, deleteMerchantProduct } = require('../supabase_repo/merchants');

router.get('/admin/pending-products', async (req, res) => {
  try {
    const adminPhone = requireOptionalAuthorizedPhone(req, res);
    if (!adminPhone) return;
    const adminRole = await requireMinAdminRole(req, res, adminPhone, 'moderator');
    if (!adminRole) return;
    const category = String(req.query?.category ?? '').trim();
    const rows = await getPendingProductsForAdmin(adminPhone, { category });
    return res.json(rows);
  } catch (error) {
    console.error('admin pending-products error:', error);
    const message = error?.message || 'Failed to load pending products.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

router.put('/admin/product-approval', async (req, res) => {
  try {
    const adminPhone = requireOptionalAuthorizedPhone(req, res);
    if (!adminPhone) return;
    const adminRole = await requireMinAdminRole(req, res, adminPhone, 'moderator');
    if (!adminRole) return;
    const merchantPhone = String(req.body?.merchantPhone ?? '').trim();
    const productId = String(req.body?.productId ?? req.body?.id ?? '').trim();
    const isApproved = Boolean(req.body?.isApproved ?? req.body?.is_approved);
    const rejectionMessageAr = String(
      req.body?.rejectionMessageAr ?? req.body?.rejection_message_ar ?? ''
    ).trim();
    if (!merchantPhone || !productId) {
      return res.status(400).json({ message: 'merchantPhone and productId are required.' });
    }
    const result = await toggleProductApprovalStatus(
      adminPhone,
      merchantPhone,
      productId,
      isApproved,
      rejectionMessageAr
    );
    return res.json(result);
  } catch (error) {
    console.error('admin product-approval error:', error);
    const message = error?.message || 'Failed to update product approval.';
    const status = message.includes('Admin access')
      ? 403
      : message.includes('not found')
        ? 404
        : 500;
    return res.status(status).json({ message });
  }
});

router.get('/admin/merchant-products', async (req, res) => {
  try {
    const adminPhone = requireOptionalAuthorizedPhone(req, res);
    if (!adminPhone) return;
    const adminRole = await requireMinAdminRole(req, res, adminPhone, 'moderator');
    if (!adminRole) return;
    
    const merchantPhone = String(req.query?.merchantPhone ?? '').trim();
    if (!merchantPhone) return res.status(400).json({ message: 'merchantPhone is required' });
    
    const rows = await getMerchantProducts(merchantPhone);
    return res.json(rows.map(mapAdminProductRow));
  } catch (error) {
    console.error('admin get merchant products error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to get products' });
  }
});

router.put('/admin/merchant-product', async (req, res) => {
  try {
    const adminPhone = requireOptionalAuthorizedPhone(req, res);
    if (!adminPhone) return;
    const adminRole = await requireMinAdminRole(req, res, adminPhone, 'moderator');
    if (!adminRole) return;
    
    const merchantPhone = String(req.body?.merchantPhone ?? '').trim();
    if (!merchantPhone) return res.status(400).json({ message: 'merchantPhone is required' });
    
    const row = await saveMerchantProduct(merchantPhone, req.body || {}, { adminSave: true });
    return res.json(row);
  } catch (error) {
    console.error('admin save merchant product error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to save product' });
  }
});

router.delete('/admin/merchant-product', async (req, res) => {
  try {
    const adminPhone = requireOptionalAuthorizedPhone(req, res);
    if (!adminPhone) return;
    const adminRole = await requireMinAdminRole(req, res, adminPhone, 'moderator');
    if (!adminRole) return;
    
    const merchantPhone = String(req.query?.merchantPhone ?? '').trim();
    const id = String(req.query?.id ?? '').trim();
    if (!merchantPhone || !id) return res.status(400).json({ message: 'merchantPhone and id are required' });
    
    await deleteMerchantProduct(id, merchantPhone);
    return res.json({ success: true });
  } catch (error) {
    console.error('admin delete merchant product error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to delete product' });
  }
});

router.post('/admin/customer-pre-register', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    await assertAdminPermission(phone, 'canRegister');
    const result = await preRegisterCustomerAccount(phone, req.body || {});
    return res.json(result);
  } catch (error) {
    console.error('customer pre-register error:', error);
    const message = error?.message || 'Failed to pre-register customer.';
    const status = message.includes('Admin access')
      ? 403
      : message.includes('بالفعل') || message.includes('لا يمكن') || message.includes('مطلوب')
        ? 400
        : 500;
    return res.status(status).json({ message });
  }
});

router.post('/admin/merchant-pre-register', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    await assertAdminPermission(phone, 'canRegister');
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

router.put('/admin/merchant-category', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    await assertAdminPermission(phone, 'canRegister');
    const result = await updateMerchantCategoryByAdmin(phone, req.body || {});
    return res.json(result);
  } catch (error) {
    console.error('merchant category update error:', error);
    const message = error?.message || 'Failed to update merchant category.';
    const status = message.includes('Admin access')
      ? 403
      : message.includes('غير موجود') ||
          message.includes('مطلوب') ||
          message.includes('غير صالح')
        ? 400
        : 500;
    return res.status(status).json({ message });
  }
});

router.post('/admin/driver-pre-register', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    await assertAdminPermission(phone, 'canRegister');
    const result = await preRegisterDriverAccount(phone, req.body || {});
    return res.json(result);
  } catch (error) {
    console.error('driver pre-register error:', error);
    const message = error?.message || 'Failed to pre-register driver.';
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

router.post('/admin/professional-pre-register', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    await assertAdminPermission(phone, 'canRegister');
    const result = await preRegisterProfessionalAccount(phone, req.body || {});
    return res.json(result);
  } catch (error) {
    console.error('professional pre-register error:', error);
    const message = error?.message || 'Failed to pre-register professional.';
    const status = message.includes('Admin access')
      ? 403
      : message.includes('بالفعل') ||
          message.includes('لا يمكن') ||
          message.includes('مطلوب') ||
          message.includes('غير صالح') ||
          message.includes('تخصص')
        ? 400
        : 500;
    return res.status(status).json({ message });
  }
});

router.post('/admin/beauty-pre-register', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    await assertAdminPermission(phone, 'canRegister');
    const result = await preRegisterBeautyAccount(phone, req.body || {});
    return res.json(result);
  } catch (error) {
    console.error('beauty pre-register error:', error);
    const message = error?.message || 'Failed to pre-register.';
    const status = message.includes('Admin access')
      ? 403
      : message.includes('بالفعل') || message.includes('لا يمكن') || message.includes('مطلوب') || message.includes('تصنيف')
        ? 400
        : 500;
    return res.status(status).json({ message });
  }
});

router.post('/admin/doctor-pre-register', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    await assertAdminPermission(phone, 'canRegister');
    const body = {
      ...(req.body || {}),
      subCategoryId: 'أطباء وعيادات',
      subscriberPhone: req.body?.subscriberPhone ?? req.body?.phone,
    };
    const result = await preRegisterBeautyAccount(phone, body);
    return res.json(result);
  } catch (error) {
    console.error('doctor pre-register error:', error);
    const message = error?.message || 'Failed to pre-register doctor.';
    const status = message.includes('Admin access') ? 403 : 400;
    return res.status(status).json({ message });
  }
});

router.post('/admin/pharmacy-pre-register', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    await assertAdminPermission(phone, 'canRegister');
    const body = {
      ...(req.body || {}),
      subCategoryId: 'صيدلية',
      subscriberPhone: req.body?.subscriberPhone ?? req.body?.phone,
    };
    const result = await preRegisterBeautyAccount(phone, body);
    return res.json(result);
  } catch (error) {
    console.error('pharmacy pre-register error:', error);
    const message = error?.message || 'Failed to pre-register pharmacy.';
    const status = message.includes('Admin access') ? 403 : 400;
    return res.status(status).json({ message });
  }
});

router.post('/admin/courier-pre-register', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    await assertAdminPermission(phone, 'canRegister');
    const result = await preRegisterCourierAccount(phone, req.body || {});
    return res.json(result);
  } catch (error) {
    console.error('courier pre-register error:', error);
    const message = error?.message || 'Failed to pre-register courier.';
    const status = message.includes('Admin access')
      ? 403
      : message.includes('بالفعل') ||
          message.includes('لا يمكن') ||
          message.includes('مطلوب')
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
    await assertAdminPermission(phone, 'canApprove');
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
    await assertAdminPermission(phone, 'canApprove');
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
    await assertAdminPermission(phone, 'canApprove');
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
    await assertAdminPermission(phone, 'canApprove');
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
    await assertAdminPermission(phone, 'canDelete');
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
    await assertAdminPermission(phone, 'canSuspend');
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

// ── Maintenance mode (admin) ────────────────────────────────────────────

router.get('/admin/maintenance', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const policy = await getMaintenancePolicy();
    return res.json(policy);
  } catch (error) {
    console.error('admin maintenance read error:', error);
    const message = error?.message || 'Failed to load maintenance policy.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

router.put('/admin/maintenance', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const policy = await saveAdminMaintenancePolicy(phone, {
      enabled: req.body?.enabled,
      messageAr: req.body?.messageAr ?? req.body?.message_ar,
      messageEn: req.body?.messageEn ?? req.body?.message_en,
      allowAdminBypass:
        req.body?.allowAdminBypass ?? req.body?.allow_admin_bypass,
    });
    return res.json({ success: true, policy });
  } catch (error) {
    console.error('admin maintenance save error:', error);
    const message = error?.message || 'Failed to save maintenance policy.';
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
    const { getAdminRoleWithPermissions, listAdminAccounts } = require('../supabase_repo');
    const [roleData, accounts] = await Promise.all([
      getAdminRoleWithPermissions(phone),
      listAdminAccounts(phone),
    ]);
    return res.json({ role: roleData.role, permissions: roleData.permissions, accounts });
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

// ── Admin Permissions ────────────────────────────────────────────────────

router.get('/admin/admins', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const { listAllAdmins, getAdminPermissions } = require('../supabase_repo');
    const [admins, myPermissions] = await Promise.all([
      listAllAdmins(phone),
      getAdminPermissions(phone),
    ]);
    return res.json({ admins, myPermissions });
  } catch (error) {
    logger.error('admin list admins error', { error: error.message });
    const status = error.message.includes('Super admin') ? 403 : 500;
    return res.status(status).json({ message: error.message });
  }
});

router.post('/admin/admin-invite', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const targetPhone = String(req.body?.targetPhone || '').trim();
    const permissions = req.body?.permissions || {};
    if (!targetPhone) {
      return res.status(400).json({ message: 'رقم الهاتف مطلوب.' });
    }
    const { setAdminPermissions } = require('../supabase_repo');
    const result = await setAdminPermissions(phone, targetPhone, permissions);
    return res.json(result);
  } catch (error) {
    logger.error('admin invite error', { error: error.message });
    const status = error.message.includes('Super admin') ? 403 : 500;
    return res.status(status).json({ message: error.message });
  }
});

router.put('/admin/admin-permissions', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const targetPhone = String(req.body?.targetPhone || '').trim();
    const permissions = req.body?.permissions || {};
    if (!targetPhone) {
      return res.status(400).json({ message: 'رقم الهاتف مطلوب.' });
    }
    const { setAdminPermissions } = require('../supabase_repo');
    const result = await setAdminPermissions(phone, targetPhone, permissions);
    return res.json(result);
  } catch (error) {
    logger.error('admin permissions update error', { error: error.message });
    const status = error.message.includes('Super admin') ? 403 : 500;
    return res.status(status).json({ message: error.message });
  }
});

router.delete('/admin/admin-remove', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const targetPhone = String(req.body?.targetPhone || req.query?.targetPhone || '').trim();
    if (!targetPhone) {
      return res.status(400).json({ message: 'رقم الهاتف مطلوب.' });
    }
    const { removeAdmin } = require('../supabase_repo');
    const result = await removeAdmin(phone, targetPhone);
    return res.json(result);
  } catch (error) {
    logger.error('admin remove error', { error: error.message });
    const status = error.message.includes('Super admin') || error.message.includes('protected')
      ? 403
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

/// إرسال رسالة للمستخدمين (إشعار داخلي + push خارجي)
async function handleAdminBroadcast(req, res) {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;

    const { title, body, audience, platform, storeUpdate } = req.body || {};
    const result = await broadcastAdminUserMessage(phone, {
      title,
      body,
      audience,
      platform,
      storeUpdate,
    });
    return res.json(result);
  } catch (error) {
    console.error('admin broadcast error:', error);
    const message = error?.message || 'Failed to broadcast message.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
}

router.post('/admin/messages/broadcast', handleAdminBroadcast);

router.get('/admin/support-threads', async (req, res) => {
  try {
    const phone = requireOptionalAuthorizedPhone(req, res);
    if (!phone) return;
    const threads = await getSupportThreadsForAdmin(phone);
    return res.json(threads);
  } catch (error) {
    console.error('admin support threads error:', error);
    const message = error?.message || 'Failed to load support threads.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

/// إرسال إشعار يدوي من لوحة الأدمن (يتضمن حفظ داخل التطبيق + push)
router.post('/admin/push/send', handleAdminBroadcast);

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
