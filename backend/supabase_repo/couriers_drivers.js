function readCourierProfileFromState(state) {
  if (!state || typeof state !== 'object') return null;
  const profile = state.courierProfile;
  if (!profile || typeof profile !== 'object') return null;
  return profile;
}

function isCourierProfileComplete(profile) {
  if (!profile || typeof profile !== 'object') return false;
  const name = String(profile.name ?? '').trim();
  const contactPhone = String(profile.phone ?? '').trim();
  const homeAddress = String(
    profile.homeAddress ?? profile.address ?? profile.area ?? ''
  ).trim();
  const vehicleImage = String(
    profile.vehicleImage ?? profile.bikeImage ?? ''
  ).trim();
  return Boolean(name && contactPhone && homeAddress && vehicleImage);
}

function isCourierApproved(profile) {
  return profile?.isApproved === true;
}

const COURIER_REJECTION_REASONS = {
  name: 'الاسم غير صحيح. يرجى إدخال الاسم الثلاثي (الاسم الأول + الأب + العائلة) بشكل واضح.',
  phone: 'رقم الهاتف غير صحيح. يرجى إدخال رقم مفعّل على واتساب.',
  address: 'عنوان السكن غير واضح أو غير مكتمل. يرجى تعديل العنوان.',
  vehicleImage: 'صورة الدراجة غير واضحة أو غير مقبولة. يرجى رفع صورة أوضح للدراجة.',
};

function courierApprovalStatus(profile) {
  if (!profile || typeof profile !== 'object') return 'pending';
  if (profile.isApproved === true || profile.approvalStatus === 'approved') {
    return 'approved';
  }
  const status = String(profile.approvalStatus ?? '').trim();
  if (status === 'rejected') return 'rejected';
  return 'pending';
}

function courierRejectionMessage(profile) {
  const explicit = String(profile?.rejectionMessageAr ?? '').trim();
  if (explicit) return explicit;
  const key = String(profile?.rejectionReasonKey ?? '').trim();
  return COURIER_REJECTION_REASONS[key] || '';
}

function mapCourierForAdmin(phone, user, profile) {
  const name = String(profile.name ?? '').trim();
  const contactPhone = String(profile.phone ?? phone ?? '').trim();
  const homeAddress = String(
    profile.homeAddress ?? profile.address ?? profile.area ?? ''
  ).trim();
  const vehicleImage = String(
    profile.vehicleImage ?? profile.bikeImage ?? ''
  ).trim();

  return {
    phone: String(phone || '').trim(),
    name,
    contactPhone,
    homeAddress,
    vehicleImage,
    available: profile.available !== false && profile.isSuspended !== true,
    isSuspended: profile.isSuspended === true,
    isApproved: isCourierApproved(profile),
    approvalStatus: courierApprovalStatus(profile),
    rejectionReasonKey: String(profile.rejectionReasonKey ?? '').trim() || null,
    rejectionMessageAr: courierRejectionMessage(profile) || null,
    role: String(user?.role ?? '').trim(),
    accountType: String(user?.account_type ?? '').trim(),
    updatedAt: user?.updated_at ?? null,
  };
}

function readDriverProfileFromState(state) {
  if (!state || typeof state !== 'object') return null;
  const profile = state.driverProfile;
  if (!profile || typeof profile !== 'object') return null;
  return profile;
}

function isDriverProfileComplete(profile) {
  if (!profile || typeof profile !== 'object') return false;
  const name = String(profile.name ?? '').trim();
  const phone = String(profile.phone ?? '').trim();
  const vehicle = String(profile.vehicle ?? profile.carImage ?? '').trim();
  const plate = String(profile.plate ?? '').trim();
  const area = String(profile.area ?? profile.homeAddress ?? '').trim();
  return Boolean(name && phone && vehicle && plate && area);
}

function isDriverApproved(profile) {
  return profile?.isApproved === true;
}

function driverApprovalStatus(profile) {
  if (!profile || typeof profile !== 'object') return 'pending';
  if (isDriverApproved(profile)) return 'approved';
  if (String(profile.approvalStatus ?? '').trim() === 'rejected') return 'rejected';
  return 'pending';
}

function driverRejectionMessage(profile) {
  return String(profile?.rejectionMessageAr ?? '').trim();
}

function mapDriverForAdmin(phone, user, profile) {
  const name = String(profile.name ?? '').trim();
  const contactPhone = String(profile.phone ?? phone ?? '').trim();
  const vehicle = String(profile.vehicle ?? profile.carImage ?? '').trim();
  const plate = String(profile.plate ?? '').trim();
  const area = String(profile.area ?? profile.homeAddress ?? '').trim();

  return {
    phone: String(phone || '').trim(),
    name,
    contactPhone,
    vehicle,
    plate,
    area,
    available: profile.available !== false && profile.isSuspended !== true,
    isSuspended: profile.isSuspended === true,
    isApproved: isDriverApproved(profile),
    approvalStatus: driverApprovalStatus(profile),
    rejectionReasonKey: String(profile.rejectionReasonKey ?? '').trim() || null,
    rejectionMessageAr: profile.rejectionMessageAr || null,
    role: String(user?.role ?? '').trim(),
    accountType: String(user?.account_type ?? '').trim(),
    updatedAt: user?.updated_at ?? null,
  };
}

module.exports = {
  readCourierProfileFromState,
  isCourierProfileComplete,
  isCourierApproved,
  COURIER_REJECTION_REASONS,
  courierApprovalStatus,
  courierRejectionMessage,
  mapCourierForAdmin,
  readDriverProfileFromState,
  isDriverProfileComplete,
  isDriverApproved,
  driverApprovalStatus,
  driverRejectionMessage,
  mapDriverForAdmin,
};
