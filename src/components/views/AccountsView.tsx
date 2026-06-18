import React from 'react';
import {
  Users,
  BadgeCheck,
  LoaderCircle,
  UserX,
  Trash2,
  XCircle,
  RefreshCw,
} from 'lucide-react';
import type { AdminAccountSummary, AccountFilter } from '../../admin-types';

interface AccountsViewProps {
  accounts: AdminAccountSummary[];
  filteredAccounts: AdminAccountSummary[];
  search: string;
  accountFilter: AccountFilter;
  activeActionKey: string;
  accountKindLabel: (kind: string) => string;
  onSearchChange: (value: string) => void;
  onFilterChange: (filter: AccountFilter) => void;
  onOpenDelete: (account: AdminAccountSummary) => void;
  onSuspend: (account: AdminAccountSummary) => Promise<void>;
  onRoleChange: (account: AdminAccountSummary, newRole: string) => Promise<void>;
  onApproveAccount: (account: AdminAccountSummary) => Promise<void>;
  onOpenReject: (target: {
    phone: string;
    displayName: string;
    kind: string;
  }) => void;
}

function accountNeedsApproval(account: AdminAccountSummary) {
  return account.needsApproval === true;
}

function serviceLabel(serviceId: string) {
  switch (serviceId) {
    case 'restaurant':
      return 'مطعم';
    case 'product':
      return 'متجر';
    case 'real_estate':
      return 'عقار';
    case 'professionals':
      return 'مهني';
    default:
      return serviceId || 'غير محدد';
  }
}

function formatDate(value: string | null | undefined) {
  if (!value) return 'غير متوفر';
  try {
    return new Intl.DateTimeFormat('ar-IQ', {
      dateStyle: 'medium',
      timeStyle: 'short',
    }).format(new Date(value));
  } catch (_) {
    return value;
  }
}

export default function AccountsView({
  accounts,
  filteredAccounts,
  search,
  accountFilter,
  activeActionKey,
  accountKindLabel,
  onSearchChange,
  onFilterChange,
  onOpenDelete,
  onSuspend,
  onRoleChange,
  onApproveAccount,
  onOpenReject,
}: AccountsViewProps) {
  return (
    <>
      <div className="account-filter-row">
        {(
          [
            ['all', 'الكل'],
            ['customer', 'زبائن'],
            ['merchant', 'تجار'],
            ['courier', 'مندوبين'],
            ['driver', 'تكسي'],
          ] as Array<[AccountFilter, string]>
        ).map(([filter, label]) => (
          <button
            key={filter}
            type="button"
            className={
              accountFilter === filter
                ? 'account-filter-chip active'
                : 'account-filter-chip'
            }
            onClick={() => onFilterChange(filter)}
          >
            {label}
          </button>
        ))}
      </div>
      <div className="merchant-list">
        {(() => {
          const toRender = accountFilter === 'all'
            ? (() => {
                const byKind = {
                  admin: filteredAccounts.filter(a => a.kind === 'admin'),
                  merchant: filteredAccounts.filter(a => a.kind === 'merchant'),
                  courier: filteredAccounts.filter(a => a.kind === 'courier'),
                  driver: filteredAccounts.filter(a => a.kind === 'driver'),
                  customer: filteredAccounts.filter(a => a.kind === 'customer'),
                };
                return [
                  ...byKind.admin.map(a => ({ account: a, section: '👑 المشرفون' })),
                  ...byKind.merchant.map(a => ({ account: a, section: '🏪 التجار' })),
                  ...byKind.courier.map(a => ({ account: a, section: '🛵 المندوبون' })),
                  ...byKind.driver.map(a => ({ account: a, section: '🚕 سائقو التكسي' })),
                  ...byKind.customer.map(a => ({ account: a, section: '👤 الزبائن' })),
                ];
              })()
            : filteredAccounts.map(a => ({ account: a, section: '' }));
          let lastSection = '';
          return toRender.map(({ account, section }) => {
            const showSection = section && section !== lastSection;
            lastSection = section || lastSection;
            const suspendLoading = activeActionKey === `suspend-account:${account.phone}`;
            const deleteLoading = activeActionKey === `delete-account:${account.phone}`;
            const approvalLoading = activeActionKey === `approve-account:${account.phone}`;
            const rejectLoading = activeActionKey === `reject-account:${account.phone}`;
            const isAdmin = account.kind === 'admin';
            const needsApproval = accountNeedsApproval(account);
            const isRejected = account.approvalStatus === 'rejected';
            const isPending = needsApproval && !account.isApproved && !isRejected;
            return (
              <React.Fragment key={account.phone}>
                {showSection ? <div className="section-divider"><span>{section}</span></div> : null}
                <article className="merchant-card account-card">
                  <div className="merchant-main">
                    <div>
                      <div className="merchant-title-row">
                        <h4>{account.displayName || 'حساب بدون اسم'}</h4>
                        <span className="status-badge muted">{accountKindLabel(account.kind)}</span>
                        {needsApproval ? (
                          account.isApproved ? (
                            <span className="status-badge success">مفعّل</span>
                          ) : isRejected ? (
                            <span className="status-badge danger">مرفوض</span>
                          ) : (
                            <span className="status-badge warning">بانتظار الموافقة</span>
                          )
                        ) : null}
                        {account.isSuspended ? (
                          <span className="status-badge danger">معلّق</span>
                        ) : (
                          <span className="status-badge success">نشط</span>
                        )}
                      </div>
                      <p className="merchant-meta">
                        {account.fullName || 'بدون اسم مسجّل'} ·{' '}
                        <span dir="ltr">{account.phone}</span>
                      </p>
                      {account.kind === 'merchant' && account.merchantStoreName ? (
                        <p className="merchant-description">
                          {serviceLabel(account.primaryServiceId)} · {account.merchantStoreName}
                        </p>
                      ) : (
                        <p className="merchant-description">
                          آخر تحديث: {formatDate(account.updatedAt)}
                        </p>
                      )}
                      {isRejected && account.rejectionMessageAr ? (
                        <p className="courier-rejection-note">سبب الرفض الحالي: {account.rejectionMessageAr}</p>
                      ) : null}
                    </div>
                  </div>
                  <div className="merchant-actions">
                    {needsApproval && isPending ? (
                      <button
                        className="soft-button success"
                        disabled={approvalLoading || rejectLoading || suspendLoading}
                        onClick={() => { onApproveAccount(account).catch(() => undefined); }}
                      >
                        {approvalLoading ? <LoaderCircle className="spin" size={16} /> : <BadgeCheck size={16} />}
                        <span>موافقة وتفعيل</span>
                      </button>
                    ) : null}
                    {needsApproval && (isPending || isRejected) ? (
                      <button
                        className="soft-button danger"
                        disabled={approvalLoading || rejectLoading || suspendLoading}
                        onClick={() => {
                          onOpenReject({
                            phone: account.phone,
                            displayName: account.displayName || account.phone,
                            kind: account.kind,
                          });
                        }}
                      >
                        {rejectLoading ? <LoaderCircle className="spin" size={16} /> : <XCircle size={16} />}
                        <span>رفض مع سبب</span>
                      </button>
                    ) : null}
                    {isAdmin ? null : (
                      <button
                        className={account.isSuspended ? 'soft-button success' : 'soft-button danger'}
                        disabled={suspendLoading || deleteLoading || approvalLoading || rejectLoading}
                        onClick={() => { onSuspend(account).catch(() => undefined); }}
                      >
                        {suspendLoading ? <LoaderCircle className="spin" size={16} /> : <UserX size={16} />}
                        <span>{account.isSuspended ? 'فك التعليق' : 'تعليق الحساب'}</span>
                      </button>
                    )}
                    {isAdmin ? null : (
                      <button
                        className="soft-button danger"
                        disabled={suspendLoading || deleteLoading || approvalLoading || rejectLoading}
                        onClick={() => { onOpenDelete(account); }}
                      >
                        <Trash2 size={16} />
                        <span>حذف الحساب</span>
                      </button>
                    )}
                    {!isAdmin ? (
                      <div className="role-change-wrapper">
                        <select
                          className="role-select"
                          value={account.role || 'customer'}
                          disabled={activeActionKey === `role:${account.phone}` || suspendLoading || deleteLoading}
                          onChange={(event) => { onRoleChange(account, event.target.value).catch(() => undefined); }}
                        >
                          <option value="customer">زبون</option>
                          <option value="merchant">تاجر</option>
                          <option value="delivery">مندوب</option>
                          <option value="driver">سائق</option>
                          <option value="admin">مشرف</option>
                        </select>
                        {activeActionKey === `role:${account.phone}` ? <LoaderCircle className="spin" size={14} /> : <RefreshCw size={14} />}
                      </div>
                    ) : null}
                  </div>
                </article>
              </React.Fragment>
            );
          });
        })()}
        {filteredAccounts.length === 0 ? (
          <div className="empty-state">
            <Users size={22} />
            <p>لا توجد حسابات مطابقة للبحث الحالي.</p>
          </div>
        ) : null}
      </div>
    </>
  );
}
