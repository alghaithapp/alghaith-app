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

export const DEFAULT_HOME_CATEGORY_IDS = new Set(['restaurant', 'product', 'cars', 'eden_printing', 'global_shopping']);

export const TOGGLEABLE_HOME_CATEGORIES = [
  { id: 'restaurant', titleAr: 'المطاعم' },
  { id: 'product', titleAr: 'التسوق' },
  { id: 'cars', titleAr: 'السيارات' },
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

export type AdminView =
  | 'dashboard'
  | 'accounts'
  | 'merchants'
  | 'couriers'
  | 'drivers'
  | 'taxi'
  | 'homeCategories'
  | 'appUpdate'
  | 'maintenance';

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
  visibleToCustomers: boolean;
  visibleProductCount: number;
  visibilityNotes: string[];
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
    isBazaarMember: boolean;
    rating: number;
    address: string;
    deliveryFee: number;
    createdAt: string | null;
    updatedAt: string | null;
    fullName: string;
    role: string;
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
  documents?: {
    profileImage?: string;
    vehicleImage?: string;
    idFrontImage?: string;
    idBackImage?: string;
    residenceCardImage?: string;
  };
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
