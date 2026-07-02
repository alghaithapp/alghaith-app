import type { MerchantSummary } from '../admin-types';

const ACCOUNT_APPROVAL_SERVICES = new Set([
  'professionals',
  'tourism',
  'beauty',
  'pharmacy',
]);

/** هل يحتاج حساب هذا التاجر موافقة إدارية (وليس المنتجات فقط)؟ */
export function merchantAccountApprovalRequired(m: MerchantSummary): boolean {
  if (m.accountApprovalRequired === false) return false;
  if (m.accountApprovalRequired === true) return true;
  const primary = (m.primaryServiceId || '').trim();
  if (ACCOUNT_APPROVAL_SERVICES.has(primary)) return true;
  const ids = m.serviceIds || [];
  return ids.some((id) => ACCOUNT_APPROVAL_SERVICES.has(String(id).trim()));
}

/** حساب التاجر معلّق (يحتاج موافقة على الحساب وليس مرفوضاً). */
export function isMerchantAccountPending(m: MerchantSummary): boolean {
  if (!merchantAccountApprovalRequired(m)) return false;
  return (
    m.approvalStatus === 'pending' ||
    (!m.isApproved && m.approvalStatus !== 'rejected')
  );
}

export function merchantModerationReviewPath(m: MerchantSummary): string {
  const service = (m.primaryServiceId || '').trim();
  if (service === 'professionals' || m.isProfessional) {
    return `/admin/professionals/${encodeURIComponent(m.phone)}`;
  }
  if (service === 'tourism') {
    return `/admin/moderation/tourism`;
  }
  if (service === 'beauty' || service === 'pharmacy') {
    if (m.serviceSubCategory === 'صيدلية' || service === 'pharmacy') {
      return `/admin/health-beauty/pharmacies`;
    }
    return `/admin/health-beauty/doctors`;
  }
  return `/admin/merchants/${encodeURIComponent(m.phone)}`;
}

export function merchantModerationListPath(m: MerchantSummary): string {
  const service = (m.primaryServiceId || '').trim();
  if (service === 'professionals' || m.isProfessional) {
    return '/admin/moderation/professionals';
  }
  if (service === 'tourism') return '/admin/moderation/tourism';
  if (service === 'beauty' || service === 'pharmacy') {
    return '/admin/health-beauty';
  }
  return '/admin/moderation/products';
}

export function countPendingMerchantAccounts(
  merchants: MerchantSummary[],
  options?: { serviceId?: string; excludeServices?: string[] },
): number {
  let base = merchants.filter(isMerchantAccountPending);
  if (options?.serviceId) {
    base = base.filter((m) => m.primaryServiceId === options.serviceId);
  } else if (options?.excludeServices?.length) {
    base = base.filter(
      (m) => !options.excludeServices!.includes(m.primaryServiceId || ''),
    );
  }
  return base.length;
}

export function countMerchantsWithPendingProducts(merchants: MerchantSummary[]): number {
  return merchants.filter((m) => (m.pendingProducts ?? 0) > 0).length;
}
