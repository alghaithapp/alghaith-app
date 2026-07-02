export interface AdminSession {
  token: string;
  phoneNumber: string;
}

export interface AppUpdatePolicy {
  minBuildNumber: number;
  minVersionName: string;
  latestBuildNumber: number;
  latestVersionName: string;
  messageAr: string;
  androidStoreUrl: string;
  iosStoreUrl: string;
  updatedAt: string | null;
}

export interface MaintenancePolicy {
  enabled: boolean;
  messageAr: string;
  messageEn: string;
  allowAdminBypass: boolean;
  updatedAt: string | null;
}

export interface HomeCategoryPlatformOverride {
  default?: boolean;
  android?: boolean;
  ios?: boolean;
  web?: boolean;
}

export interface HomeCategoriesConfig {
  overrides: Record<string, HomeCategoryPlatformOverride>;
  updatedAt: string | null;
}

export const DEFAULT_HOME_CATEGORY_IDS = new Set(['restaurant', 'cars', 'product', 'gen_services', 'professionals', 'beauty', 'tourism', 'real_estate', 'offers', 'used', 'eden_printing', 'global_shopping']);

export const TOGGLEABLE_HOME_CATEGORIES = [
  { id: 'restaurant', titleAr: 'المطاعم' },
  { id: 'product', titleAr: 'التسوق' },
  { id: 'cars', titleAr: 'السيارات' },
  { id: 'gen_services', titleAr: 'خدمات عامة' },
  { id: 'global_shopping', titleAr: 'التسوق من الخارج' },
  { id: 'professionals', titleAr: 'المهنيين' },
  { id: 'beauty', titleAr: 'الصحة والجمال' },
  { id: 'tourism', titleAr: 'السياحة والسفر' },
  { id: 'real_estate', titleAr: 'العقارات' },
  { id: 'offers', titleAr: 'العروض والخصومات' },
  { id: 'used', titleAr: 'المنتجات المستعملة' },
  { id: 'eden_printing', titleAr: 'طباعة وإعلانات' },
] as const;

/** أقسام يمكن اختيارها عند تسجيل التاجر (باستثناء الأقسام المُدارة من المنصة). */
export const MERCHANT_SIGNUP_CATEGORIES = TOGGLEABLE_HOME_CATEGORIES.filter(
  (category) => category.id !== 'eden_printing',
);

export interface MerchantPreRegisterPayload {
  merchantPhone: string;
  fullName?: string;
  primaryServiceId: string;
  serviceIds: string[];
  note?: string;
  isBazaarMember?: boolean;
  serviceSubCategory?: string;
}

export interface MerchantCategoryUpdatePayload {
  merchantPhone: string;
  primaryServiceId: string;
  serviceIds?: string[];
  serviceSubCategory?: string;
  isBazaarMember?: boolean;
}

export interface MerchantCategoryUpdateResponse {
  success: boolean;
  phone: string;
  primaryServiceId: string;
  serviceIds: string[];
  serviceSubCategory: string | null;
  isBazaarMember: boolean;
  storeName: string;
}

/** فئات فرعية لقسم التسوق (product) */
export const SHOPPING_PRODUCT_SUBCATEGORIES = [
  { id: 'cosmetics', labelAr: 'مستحضرات تجميل' },
  { id: 'home_goods', labelAr: 'مواد منزلية' },
  { id: 'electrical_appliances', labelAr: 'أجهزة كهربائية' },
  { id: 'food_items', labelAr: 'مواد غذائية' },
  { id: 'construction', labelAr: 'مواد إنشائية' },
  { id: 'school', labelAr: 'لوازم مكتبية ومدرسية' },
  { id: 'bakery', labelAr: 'مخابز ومعجنات' },
  { id: 'meat', labelAr: 'لحوم' },
  { id: 'grocery', labelAr: 'بقالة' },
  { id: 'shoes_bags', labelAr: 'أحذية وحقائب' },
  { id: 'kids_clothing', labelAr: 'ملابس أطفال' },
  { id: 'women_clothing', labelAr: 'ملابس نسائية' },
  { id: 'men_clothing', labelAr: 'ملابس رجالية' },
  { id: 'gifts', labelAr: 'زهور وهدايا' },
] as const;

/** فئات فرعية لقسم الصحة والجمال */
export const BEAUTY_SUBCATEGORIES = [
  { id: 'صالون رجالي', labelAr: 'صالون رجالي' },
  { id: 'صالون نسائي', labelAr: 'صالون نسائي' },
  { id: 'أطباء وعيادات', labelAr: 'أطباء وعيادات' },
  { id: 'صيدلية', labelAr: 'صيدلية' },
] as const;

/** تخصصات الأطباء الثابتة — للتسجيل والفلترة */
export const DOCTOR_SPECIALTIES = [
  { id: 'طب القلب', labelAr: 'طب القلب' },
  { id: 'طب الأطفال', labelAr: 'طب الأطفال' },
  { id: 'الطب الباطني', labelAr: 'الطب الباطني' },
  { id: 'الجراحة العامة', labelAr: 'الجراحة العامة' },
  { id: 'طب النساء والتوليد', labelAr: 'طب النساء والتوليد' },
  { id: 'طب العيون', labelAr: 'طب العيون' },
  { id: 'طب الأنف والأذن والحنجرة', labelAr: 'طب الأنف والأذن والحنجرة' },
  { id: 'طب الأسنان', labelAr: 'طب الأسنان' },
  { id: 'الأمراض الجلدية', labelAr: 'الأمراض الجلدية' },
  { id: 'جراحة العظام', labelAr: 'جراحة العظام' },
] as const;

export type DoctorSpecialtyId = (typeof DOCTOR_SPECIALTIES)[number]['id'];

export function isDoctorSpecialtyId(value: string): value is DoctorSpecialtyId {
  return DOCTOR_SPECIALTIES.some((item) => item.id === value);
}

export interface MerchantPreRegisterResponse {
  success: boolean;
  phone: string;
  fullName: string;
  primaryServiceId: string;
  serviceIds: string[];
  isApproved: boolean;
  approvalStatus: string;
  merchantProfileComplete: boolean;
  storeName: string;
}

export interface DriverPreRegisterPayload {
  driverPhone: string;
  fullName: string;
  note?: string;
}

export interface DriverPreRegisterResponse {
  success: boolean;
  phone: string;
  fullName: string;
  isApproved: boolean;
  approvalStatus: string;
  driverProfileComplete: boolean;
}

export interface CourierPreRegisterPayload {
  courierPhone: string;
  fullName: string;
  note?: string;
}

export interface CourierPreRegisterResponse {
  success: boolean;
  phone: string;
  fullName: string;
  isApproved: boolean;
  approvalStatus: string;
  courierProfileComplete: boolean;
}

export interface DoctorPharmacyPreRegisterPayload {
  subscriberPhone: string;
  fullName: string;
  subCategoryId?: 'أطباء وعيادات' | 'صيدلية';
  description?: string;
  address?: string;
  contactPhone?: string;
  whatsapp?: string;
  specialty?: DoctorSpecialtyId;
  doctorPhone?: string;
  clinicPhone?: string;
  openTime?: string;
  closeTime?: string;
  profileImageUrl?: string;
  clinicImageUrl?: string;
}

export interface CustomerPreRegisterPayload {
  phone: string;
  fullName?: string;
  address?: string;
}

export interface CustomerPreRegisterResponse {
  success: boolean;
  phone: string;
  fullName: string | null;
  role: string;
}

export interface DoctorPharmacyPreRegisterResponse {
  success: boolean;
  phone: string;
  fullName: string;
  subCategoryId: string;
  storeName: string;
  isApproved: boolean;
  approvalStatus: string;
  merchantProfileComplete: boolean;
}

export interface ProfessionalPreRegisterPayload {
  professionalPhone: string;
  fullName: string;
  professionId: string;
  description?: string;
  address?: string;
  contactPhone?: string;
  whatsapp?: string;
  openTime?: string;
  closeTime?: string;
  profileImageUrl?: string;
  workSampleUrls?: string[];
  showPhoneToCustomers?: boolean;
  showWhatsAppToCustomers?: boolean;
}

export interface ProfessionalPreRegisterResponse {
  success: boolean;
  phone: string;
  fullName: string;
  professionId: string;
  storeName: string;
  isApproved: boolean;
  approvalStatus: string;
  merchantProfileComplete: boolean;
}

export interface AdminPermissions {
  canRegister: boolean;
  canApprove: boolean;
  canDelete: boolean;
  canSuspend: boolean;
  canManageAdmins: boolean;
}

export const DEFAULT_ADMIN_PERMISSIONS: AdminPermissions = {
  canRegister: true,
  canApprove: true,
  canDelete: true,
  canSuspend: true,
  canManageAdmins: false,
};

export interface AdminSummary {
  phone: string;
  fullName: string;
  role: string;
  permissions: AdminPermissions;
  isProtected: boolean;
  updatedAt: string | null;
}

export type AdminView =
  | 'dashboard'
  | 'accounts'
  | 'merchants'
  | 'couriers'
  | 'drivers'
  | 'homeCategories'
  | 'appUpdate'
  | 'notifications'
  | 'maintenance'
  | 'admins'
  | 'appConfig';

export interface AdminTaxiTrip {
  id: string;
  requestNumber: string;
  statusKey: string;
  statusAr?: string;
  customerPhone?: string;
  driverPhone?: string;
  driverName?: string;
  pickupAddress: string;
  dropoffAddress: string;
  fare: number;
  taxiType: string;
  driverRating?: number;
  adminReviewRequired?: boolean;
  completedAt?: string | null;
  acceptedAt?: string | null;
  cancellationReason?: string | null;
  ratingComment?: string | null;
}

export interface AdminReports {
  totalOrders: number;
  completedOrders: number;
  pendingOrders: number;
  deliveringOrders: number;
  totalSales: number;
  codCollected: number;
  totalMerchants: number;
  openMerchants: number;
  totalProducts: number;
  totalUsers: number;
  recentOrders: AdminRecentOrder[];
}

export interface AdminRecentOrder {
  id: string;
  orderNumber: string;
  statusKey: string;
  statusAr: string;
  price: number;
  merchantStoreName: string;
  customerNameAr: string;
  deliveryStatusKey: string;
  updatedAt: string | null;
}

export interface BazaarProductSyncResult {
  synced: number;
  totalEligible: number;
}

export interface ToggleBazaarResponse {
  success: boolean;
  bazaarProductSync?: BazaarProductSyncResult;
}

export type MerchantRejectionReasonKey =
  | 'storeName'
  | 'phone'
  | 'address'
  | 'images'
  | 'description';

export interface MerchantSummary {
  phone: string;
  storeName: string;
  description: string;
  primaryServiceId: string;
  isProfessional?: boolean;
  isOpen: boolean;
  isFrozen: boolean;
  isApproved: boolean;
  approvalStatus: 'pending' | 'approved' | 'rejected';
  rejectionReasonKey: MerchantRejectionReasonKey | null;
  rejectionMessageAr: string | null;
  rating: number;
  isBazaarMember: boolean;
  createdAt: string | null;
  fullName: string;
  role: string;
  totalOrders: number;
  completedOrders: number;
  pendingOrders: number;
  deliveringOrders: number;
  totalRevenue: number;
  lastOrderAt: string | null;
  totalProducts: number;
  availableProducts: number;
  pendingProducts?: number;
  accountApprovalRequired?: boolean;
  visibleToCustomers: boolean;
  visibleProductCount: number;
  visibilityNotes: string[];
  serviceSubCategory?: string;
  specialty?: string;
  serviceIds?: string[];
  profileImageUrl?: string;
  logoImageUrl?: string;
  coverImageUrl?: string;
  clinicImageUrl?: string;
  avatarImageUrl?: string;
}

export interface ProfessionalSummary extends MerchantSummary {
  professionalCategoryId: string;
  professionalCategoryLabel: string;
  profileImageUrl: string;
  workSampleCount: number;
}

export interface ProfessionalDetails extends MerchantDetails {
  professional: {
    categoryId: string;
    categoryLabel: string;
    profileImageUrl: string;
    workSampleUrls: string[];
    description: string;
    contactPhone: string;
    whatsapp: string;
    openTime: string;
    closeTime: string;
    showPhoneToCustomers: boolean;
    showWhatsAppToCustomers: boolean;
    rejectionMessageAr: string;
    professionalInfo: Record<string, unknown>;
  };
}

export interface MerchantDetails {
  merchant: {
    phone: string;
    storeName: string;
    description: string;
    primaryServiceId: string;
    serviceIds: string[];
    isOpen: boolean;
    isFrozen: boolean;
    isApproved?: boolean;
    approvalStatus?: string;
    isBazaarMember: boolean;
    rating: number;
    address: string;
    deliveryFee: number;
    createdAt: string | null;
    updatedAt: string | null;
    fullName: string;
    role: string;
    profileImageUrl?: string;
    logoImageUrl?: string;
    coverImageUrl?: string;
    clinicImageUrl?: string;
    avatarImageUrl?: string;
    workSampleUrls?: string[];
  };
  stats: {
    totalOrders: number;
    completedOrders: number;
    pendingOrders: number;
    deliveringOrders: number;
    cancelledOrders: number;
    totalRevenue: number;
    codCollected: number;
    averageOrderValue: number;
    totalProducts: number;
  };
  recentOrders: MerchantOrder[];
  products: MerchantProduct[];
}

export interface MerchantOrder {
  id: string;
  orderNumber: string;
  statusKey: string;
  statusAr: string;
  statusEn: string;
  deliveryStatusKey: string;
  deliveryStatusAr: string;
  deliveryStatusEn: string;
  price: number;
  customerName: string;
  customerPhone: string;
  itemCount: number;
  updatedAt: string | null;
  createdAt: string | null;
}

export interface MerchantProduct {
  id: string;
  name: string;
  category: string;
  subCategory: string;
  price: number;
  isAvailable: boolean;
  createdAt: string | null;
}

export type CourierRejectionReasonKey = 'name' | 'phone' | 'address' | 'vehicleImage';

export type AdminAccountKind =
  | 'customer'
  | 'merchant'
  | 'courier'
  | 'driver'
  | 'admin';

export interface AdminAccountSummary {
  phone: string;
  displayName: string;
  fullName: string;
  role: string;
  accountType: string;
  kind: AdminAccountKind;
  isSuspended: boolean;
  needsApproval: boolean;
  approvalStatus: 'pending' | 'approved' | 'rejected' | null;
  isApproved: boolean;
  rejectionMessageAr: string | null;
  merchantStoreName: string;
  primaryServiceId: string;
  courierApproved: boolean;
  updatedAt: string | null;
  createdAt: string | null;
  hasMerchantProfile: boolean;
  hasCourierProfile: boolean;
  hasDriverProfile: boolean;
  hasDriverCredential?: boolean;
  driverProfileComplete?: boolean;
  driverIsApproved?: boolean;
  driverApprovalStatus?: string | null;
  documents?: {
    profileImage?: string;
    vehicleImage?: string;
    idFrontImage?: string;
    idBackImage?: string;
    residenceCardImage?: string;
    vehicleRegFrontImage?: string;
    vehicleRegBackImage?: string;
  };
}

export interface CourierSummary {
  phone: string;
  name: string;
  contactPhone: string;
  homeAddress: string;
  vehicleImage: string;
  available: boolean;
  isSuspended: boolean;
  isApproved: boolean;
  approvalStatus: 'pending' | 'approved' | 'rejected';
  rejectionReasonKey: CourierRejectionReasonKey | null;
  rejectionMessageAr: string | null;
  role: string;
  accountType: string;
  updatedAt: string | null;
  mukhtarName?: string;
  documents?: OperatorDocuments;
}

export interface DriverSummary {
  phone: string;
  name: string;
  contactPhone: string;
  vehicle: string;
  plate: string;
  area: string;
  available: boolean;
  isSuspended: boolean;
  isApproved: boolean;
  approvalStatus: 'pending' | 'approved' | 'rejected';
  rejectionReasonKey: string | null;
  rejectionMessageAr: string | null;
  role: string;
  accountType: string;
  updatedAt: string | null;
  mukhtarName?: string;
  taxiType?: string;
  carImage?: string;
  documents?: OperatorDocuments;
}

export interface OperatorDocuments {
  profileImage?: string;
  vehicleImage?: string;
  carImage?: string;
  idFrontImage?: string;
  idBackImage?: string;
  residenceCardImage?: string;
  vehicleRegFrontImage?: string;
  vehicleRegBackImage?: string;
}

export interface PendingProductSummary {
  id: string;
  phone?: string;
  merchantPhone: string;
  merchantStoreName: string;
  merchantCategory: string;
  name_ar?: string;
  nameAr?: string;
  description_ar?: string;
  descriptionAr?: string;
  price: number;
  category: string;
  sub_category?: string;
  subCategory?: string;
  image?: string;
  image_url?: string;
  isApproved: boolean;
  approvalStatus: 'pending' | 'approved' | 'rejected';
  rejectionMessageAr?: string;
  listing_mode?: string;
  listingMode?: string;
  neighborhood?: string;
  created_at?: string;
  updated_at?: string;
}

export const MERCHANT_REJECTION_REASONS: Array<{
  key: MerchantRejectionReasonKey;
  label: string;
}> = [
  { key: 'storeName', label: 'اسم المتجر غير واضح أو غير مطابق' },
  { key: 'phone', label: 'رقم الهاتف أو واتساب غير صحيح' },
  { key: 'address', label: 'العنوان أو الموقع على الخريطة غير واضح' },
  { key: 'images', label: 'صور المتجر (الشعار/الغلاف) غير مناسبة' },
  { key: 'description', label: 'وصف المتجر ناقص أو غير مناسب' },
];

export const COURIER_REJECTION_REASONS: Array<{
  key: CourierRejectionReasonKey;
  label: string;
}> = [
  { key: 'name', label: 'الاسم غير صحيح — يرجى كتابة الاسم الثلاثي بشكل صحيح' },
  { key: 'phone', label: 'رقم الهاتف غير صحيح — يرجى إدخال رقم مفعّل على واتساب' },
  { key: 'address', label: 'عنوان السكن غير صحيح أو غير واضح' },
  { key: 'vehicleImage', label: 'صورة الدراجة غير واضحة أو غير مقبولة' },
];

export const PROFESSIONAL_CATEGORIES: Array<{ id: string; label: string }> = [
  { id: 'plumber', label: 'سباك' },
  { id: 'electrician', label: 'كهربائي' },
  { id: 'ac_tech', label: 'فني تكييف' },
  { id: 'carpenter', label: 'نجار' },
  { id: 'cleaner', label: 'تنظيف منازل' },
  { id: 'blacksmith', label: 'حداد' },
  { id: 'painter', label: 'صباغ' },
  { id: 'builder', label: 'بناء' },
  { id: 'cctv_tech', label: 'فني كاميرات مراقبة' },
  { id: 'network_tech', label: 'فني إنترنت وشبكات' },
  { id: 'loading_worker', label: 'عامل تحميل وتنزيل' },
  { id: 'gardener', label: 'عامل حدائق' },
  { id: 'aluminum_glass', label: 'فني ألمنيوم وزجاج' },
  { id: 'photography', label: 'استوديوهات تصوير' },
  { id: 'wedding', label: 'تجهيز الأعراس والمناسبات' },
];
