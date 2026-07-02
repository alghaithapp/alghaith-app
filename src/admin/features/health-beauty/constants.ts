export type HealthBeautySubCategoryId =
  | 'صيدلية'
  | 'أطباء وعيادات'
  | 'صالون رجالي'
  | 'صالون نسائي';

export const HEALTH_BEAUTY_SERVICE_ID = 'beauty';

export const HEALTH_BEAUTY_NAV = [
  { id: 'overview', to: '/admin/health-beauty', end: true, label: 'نظرة عامة' },
  { id: 'pharmacies', to: '/admin/health-beauty/pharmacies', end: true, label: 'الصيدليات' },
  { id: 'doctors', to: '/admin/health-beauty/doctors', end: true, label: 'الأطباء' },
  { id: 'doctor-register', to: '/admin/health-beauty/doctors/new', label: 'الدكتور' },
] as const;

export const HEALTH_BEAUTY_CATEGORIES: {
  id: HealthBeautySubCategoryId;
  label: string;
  registerPath: string;
  registerLabel: string;
}[] = [
  {
    id: 'صيدلية',
    label: 'الصيدليات',
    registerPath: '/admin/health-beauty/pharmacies/new',
    registerLabel: 'تسجيل صيدلية',
  },
  {
    id: 'أطباء وعيادات',
    label: 'الأطباء',
    registerPath: '/admin/health-beauty/doctors/new',
    registerLabel: 'تسجيل دكتور',
  },
];

export function isPharmacyMerchant(
  merchant: { primaryServiceId?: string; serviceSubCategory?: string },
): boolean {
  const sub = String(merchant.serviceSubCategory ?? '').trim();
  if (sub !== 'صيدلية') return false;
  const primary = String(merchant.primaryServiceId ?? '').trim();
  return primary === 'beauty' || primary === 'pharmacy';
}

export function isHealthBeautyMerchant(
  merchant: { primaryServiceId?: string; serviceSubCategory?: string },
): boolean {
  if (merchant.primaryServiceId === HEALTH_BEAUTY_SERVICE_ID) return true;
  const sub = String(merchant.serviceSubCategory ?? '').trim();
  return ['صيدلية', 'أطباء وعيادات', 'صالون رجالي', 'صالون نسائي'].includes(sub);
}

export function matchesHealthBeautySubCategory(
  merchant: { serviceSubCategory?: string },
  subCategoryId: HealthBeautySubCategoryId | HealthBeautySubCategoryId[],
): boolean {
  const sub = String(merchant.serviceSubCategory ?? '').trim();
  const ids = Array.isArray(subCategoryId) ? subCategoryId : [subCategoryId];
  return ids.includes(sub as HealthBeautySubCategoryId);
}
