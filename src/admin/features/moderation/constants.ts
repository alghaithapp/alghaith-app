export const MODERATION_NAV = [
  { id: 'overview', to: '/admin/moderation', end: true, label: 'نظرة عامة' },
  { id: 'accounts', to: '/admin/moderation/accounts', label: 'حسابات تجار' },
  { id: 'products', to: '/admin/moderation/products', label: 'منتجات' },
  { id: 'real-estate', to: '/admin/moderation/real-estate', label: 'عقارات' },
  { id: 'cars', to: '/admin/moderation/cars', label: 'سيارات' },
  { id: 'used', to: '/admin/moderation/used', label: 'مستعمل' },
  { id: 'tourism', to: '/admin/moderation/tourism', label: 'سياحة' },
  { id: 'health-beauty', to: '/admin/health-beauty', label: 'صحة وجمال' },
  { id: 'professionals', to: '/admin/moderation/professionals', label: 'مهنيين' },
  { id: 'drivers', to: '/admin/moderation/drivers', label: 'سائقين' },
  { id: 'couriers', to: '/admin/moderation/couriers', label: 'مندوبين' },
] as const;

export const PRODUCT_CATEGORY_LABELS: Record<string, string> = {
  product: 'تسوق',
  restaurant: 'مطاعم',
  used: 'مستعمل',
  offers: 'عروض',
  cars: 'سيارات',
  real_estate: 'عقارات',
  beauty: 'صحة وجمال',
  tourism: 'سياحة',
  professionals: 'مهنيين',
  bazar_ghaith: 'بازار',
};
