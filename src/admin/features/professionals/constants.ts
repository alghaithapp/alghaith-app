export const PROFESSIONALS_NAV = [
  { id: 'overview', to: '/admin/professionals', end: true, label: 'نظرة عامة' },
  { id: 'list', to: '/admin/professionals/list', label: 'كل المهنيين' },
  { id: 'pending', to: '/admin/professionals/pending', label: 'طلبات الموافقة' },
  { id: 'new', to: '/admin/professionals/new', label: 'تسجيل مهني' },
] as const;
