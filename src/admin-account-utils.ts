import type { AdminAccountSummary } from './admin-types';

/** Driver-tab approval when the same phone may also be a merchant/customer. */
export function driverApprovalFor(account: AdminAccountSummary) {
  const useDriver = account.hasDriverCredential === true || account.kind === 'driver';
  return {
    isApproved: useDriver ? account.driverIsApproved === true : account.isApproved,
    approvalStatus: useDriver
      ? (account.driverApprovalStatus ?? account.approvalStatus)
      : account.approvalStatus,
  };
}
