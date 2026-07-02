import { TOGGLEABLE_HOME_CATEGORIES } from '../../admin-types';
import { PRODUCT_CATEGORY_LABELS } from '../features/moderation/constants';

const PRIMARY_SERVICE_LABELS: Record<string, string> = {
  ...Object.fromEntries(TOGGLEABLE_HOME_CATEGORIES.map((item) => [item.id, item.titleAr])),
  ...PRODUCT_CATEGORY_LABELS,
  pharmacy: 'صيدلية',
};

export function formatPrimaryServiceLabel(serviceId?: string | null): string {
  const key = String(serviceId || '').trim();
  if (!key) return '—';
  return PRIMARY_SERVICE_LABELS[key] || key;
}
