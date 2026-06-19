import React, { useState, useMemo } from 'react';
import {
  Users,
  BadgeCheck,
  LoaderCircle,
  UserX,
  Trash2,
  XCircle,
  RefreshCw,
  ArrowUpDown,
  ArrowUp,
  ArrowDown,
  Phone,
  Calendar,
  ShoppingBag,
  Store,
  Bike,
  Car,
  Shield,
  ChevronDown,
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
  onOpenReject: (target: { phone: string; displayName: string; kind: string }) => void;
}

type SortField = 'name' | 'createdAt' | 'updatedAt' | 'none';
type SortDir = 'asc' | 'desc';

function accountNeedsApproval(account: AdminAccountSummary) {
  return account.needsApproval === true;
}

function serviceLabel(serviceId: string) {
  switch (serviceId) {
    case 'restaurant': return 'مطعم';
    case 'product': return 'متجر';
    case 'real_estate': return 'عقار';
    case 'professionals': return 'مهني';
    default: return serviceId || 'غير محدد';
  }
}

function formatDate(value: string | null | undefined) {
  if (!value) return '—';
  try {
    return new Intl.DateTimeFormat('ar-IQ', { dateStyle: 'medium' }).format(new Date(value));
  } catch {
    return value;
  }
}

function formatDateTime(value: string | null | undefined) {
  if (!value) return '—';
  try {
    return new Intl.DateTimeFormat('ar-IQ', { dateStyle: 'short', timeStyle: 'short' }).format(new Date(value));
  } catch {
    return value;
  }
}

function SortIcon({ field, active, dir }: { field: string; active: boolean; dir: SortDir }) {
  if (!active) return <ArrowUpDown size={12} className="sort-icon" />;
  return dir === 'asc'
    ? <ArrowUp size={12} className="sort-icon active" />
    : <ArrowDown size={12} className="sort-icon active" />;
}

function useSorted<T extends Record<string, any>>(
  items: T[],
  field: SortField,
  dir: SortDir,
) {
  return useMemo(() => {
    if (field === 'none') return items;
    return [...items].sort((a, b) => {
      let va: any = a[field];
      let vb: any = b[field];
      if (field === 'createdAt' || field === 'updatedAt') {
        va = va ? new Date(va).getTime() : 0;
        vb = vb ? new Date(vb).getTime() : 0;
      } else {
        va = String(va || '').toLowerCase();
        vb = String(vb || '').toLowerCase();
      }
      if (va < vb) return dir === 'asc' ? -1 : 1;
      if (va > vb) return dir === 'asc' ? 1 : -1;
      return 0;
    });
  }, [items, field, dir]);
}

function useSort(initial: SortField = 'none') {
  const [field, setField] = useState<SortField>(initial);
  const [dir, setDir] = useState<SortDir>('desc');

  function toggle(f: SortField) {
    if (field === f) {
      setDir((d) => (d === 'asc' ? 'desc' : 'asc'));
    } else {
      setField(f);
      setDir('desc');
    }
  }

  return { field, dir, toggle };
}

function SortableTh({
  label,
  sortField,
  currentField,
  currentDir,
  onToggle,
}: {
  label: string;
  sortField: SortField;
  currentField: SortField;
  currentDir: SortDir;
  onToggle: (f: SortField) => void;
}) {
  const active = currentField === sortField;
  return (
    <th
      className={`sortable ${active ? 'sort-active' : ''}`}
      onClick={() => onToggle(sortField)}
      style={{ cursor: 'pointer' }}
    >
      {label}
      <SortIcon field={sortField} active={active} dir={currentDir} />
    </th>
  );
}

/* ═══════════════════════════════════════════
   CUSTOMER TABLE
═══════════════════════════════════════════ */
function CustomerTable({
  accounts,
  activeActionKey,
  onOpenDelete,
  onSuspend,
}: {
  accounts: AdminAccountSummary[];
  activeActionKey: string;
  onOpenDelete: (a: AdminAccountSummary) => void;
  onSuspend: (a: AdminAccountSummary) => Promise<void>;
}) {
  const { field, dir, toggle } = useSort('createdAt');
  const sorted = useSorted(accounts, field, dir);

  if (accounts.length === 0) {
    return (
      <div className="empty-state">
        <Users size={28} />
        <p>لا يوجد زبائن مطابقون</p>
      </div>
    );
  }

  return (
    <div className="accounts-table-wrap">
      <table className="accounts-table">
        <thead>
          <tr>
            <SortableTh label="الاسم" sortField="name" currentField={field} currentDir={dir} onToggle={toggle} />
            <th>رقم الهاتف</th>
            <SortableTh label="تاريخ التسجيل" sortField="createdAt" currentField={field} currentDir={dir} onToggle={toggle} />
            <SortableTh label="آخر نشاط" sortField="updatedAt" currentField={field} currentDir={dir} onToggle={toggle} />
            <th>الحالة</th>
            <th>الإجراءات</th>
          </tr>
        </thead>
        <tbody>
          {sorted.map((a) => {
            const suspendLoading = activeActionKey === `suspend-account:${a.phone}`;
            const deleteLoading = activeActionKey === `delete-account:${a.phone}`;
            return (
              <tr key={a.phone}>
                <td className="td-name">{a.displayName || a.fullName || 'بدون اسم'}</td>
                <td className="td-phone">{a.phone}</td>
                <td>{formatDate(a.createdAt)}</td>
                <td>{formatDateTime(a.updatedAt)}</td>
                <td>
                  {a.isSuspended ? (
                    <span className="status-badge danger">معلّق</span>
                  ) : (
                    <span className="status-badge success">نشط</span>
                  )}
                </td>
                <td>
                  <div className="table-actions">
                    <button
                      className={a.isSuspended ? 'soft-button success' : 'soft-button danger'}
                      disabled={suspendLoading || deleteLoading}
                      onClick={() => onSuspend(a).catch(() => undefined)}
                      title={a.isSuspended ? 'فك التعليق' : 'تعليق الحساب'}
                    >
                      {suspendLoading ? <LoaderCircle className="spin" size={14} /> : <UserX size={14} />}
                      <span>{a.isSuspended ? 'فك التعليق' : 'تعليق'}</span>
                    </button>
                    <button
                      className="soft-button danger"
                      disabled={suspendLoading || deleteLoading}
                      onClick={() => onOpenDelete(a)}
                      title="حذف الحساب"
                    >
                      {deleteLoading ? <LoaderCircle className="spin" size={14} /> : <Trash2 size={14} />}
                    </button>
                  </div>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

/* ═══════════════════════════════════════════
   MERCHANT TABLE (in accounts view)
═══════════════════════════════════════════ */
function MerchantTable({
  accounts,
  activeActionKey,
  onOpenDelete,
  onSuspend,
  onApproveAccount,
  onOpenReject,
  onRoleChange,
}: {
  accounts: AdminAccountSummary[];
  activeActionKey: string;
  onOpenDelete: (a: AdminAccountSummary) => void;
  onSuspend: (a: AdminAccountSummary) => Promise<void>;
  onApproveAccount: (a: AdminAccountSummary) => Promise<void>;
  onOpenReject: (t: { phone: string; displayName: string; kind: string }) => void;
  onRoleChange: (a: AdminAccountSummary, role: string) => Promise<void>;
}) {
  const { field, dir, toggle } = useSort('createdAt');
  const sorted = useSorted(accounts, field, dir);

  if (accounts.length === 0) {
    return (
      <div className="empty-state">
        <Store size={28} />
        <p>لا يوجد تجار مطابقون</p>
      </div>
    );
  }

  return (
    <div className="accounts-table-wrap">
      <table className="accounts-table">
        <thead>
          <tr>
            <SortableTh label="صاحب الحساب" sortField="name" currentField={field} currentDir={dir} onToggle={toggle} />
            <th>المتجر / الخدمة</th>
            <th>الهاتف</th>
            <SortableTh label="تاريخ التسجيل" sortField="createdAt" currentField={field} currentDir={dir} onToggle={toggle} />
            <th>حالة الموافقة</th>
            <th>الحساب</th>
            <th>الإجراءات</th>
          </tr>
        </thead>
        <tbody>
          {sorted.map((a) => {
            const suspendLoading = activeActionKey === `suspend-account:${a.phone}`;
            const deleteLoading = activeActionKey === `delete-account:${a.phone}`;
            const approvalLoading = activeActionKey === `approve-account:${a.phone}`;
            const rejectLoading = activeActionKey === `reject-account:${a.phone}`;
            const needsApproval = accountNeedsApproval(a);
            const isRejected = a.approvalStatus === 'rejected';
            const isPending = needsApproval && !a.isApproved && !isRejected;

            return (
              <tr key={a.phone}>
                <td className="td-name">{a.fullName || a.displayName || 'بدون اسم'}</td>
                <td>
                  {a.merchantStoreName ? (
                    <span>
                      <span className="status-badge muted" style={{ fontSize: '0.72rem', marginInlineEnd: 6 }}>
                        {serviceLabel(a.primaryServiceId)}
                      </span>
                      {a.merchantStoreName}
                    </span>
                  ) : <span style={{ color: 'var(--text-muted)' }}>—</span>}
                </td>
                <td className="td-phone">{a.phone}</td>
                <td>{formatDate(a.createdAt)}</td>
                <td>
                  {needsApproval ? (
                    a.isApproved ? (
                      <span className="status-badge success">مفعّل</span>
                    ) : isRejected ? (
                      <span className="status-badge danger">مرفوض</span>
                    ) : (
                      <span className="status-badge warning">بانتظار</span>
                    )
                  ) : (
                    <span className="status-badge success">مفعّل</span>
                  )}
                </td>
                <td>
                  {a.isSuspended ? (
                    <span className="status-badge danger">معلّق</span>
                  ) : (
                    <span className="status-badge success">نشط</span>
                  )}
                </td>
                <td>
                  <div className="table-actions">
                    {needsApproval && isPending ? (
                      <button
                        className="soft-button success"
                        disabled={approvalLoading || rejectLoading}
                        onClick={() => onApproveAccount(a).catch(() => undefined)}
                      >
                        {approvalLoading ? <LoaderCircle className="spin" size={13} /> : <BadgeCheck size={13} />}
                        <span>موافقة</span>
                      </button>
                    ) : null}
                    {needsApproval && (isPending || isRejected) ? (
                      <button
                        className="soft-button danger"
                        disabled={approvalLoading || rejectLoading}
                        onClick={() => onOpenReject({ phone: a.phone, displayName: a.displayName || a.phone, kind: a.kind })}
                      >
                        {rejectLoading ? <LoaderCircle className="spin" size={13} /> : <XCircle size={13} />}
                        <span>رفض</span>
                      </button>
                    ) : null}
                    <button
                      className={a.isSuspended ? 'soft-button success' : 'soft-button danger'}
                      disabled={suspendLoading || deleteLoading}
                      onClick={() => onSuspend(a).catch(() => undefined)}
                    >
                      {suspendLoading ? <LoaderCircle className="spin" size={13} /> : <UserX size={13} />}
                    </button>
                    <button
                      className="soft-button danger"
                      disabled={suspendLoading || deleteLoading}
                      onClick={() => onOpenDelete(a)}
                    >
                      {deleteLoading ? <LoaderCircle className="spin" size={13} /> : <Trash2 size={13} />}
                    </button>
                  </div>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

/* ═══════════════════════════════════════════
   COURIER TABLE
═══════════════════════════════════════════ */
function CourierTable({
  accounts,
  activeActionKey,
  onOpenDelete,
  onSuspend,
  onApproveAccount,
  onOpenReject,
}: {
  accounts: AdminAccountSummary[];
  activeActionKey: string;
  onOpenDelete: (a: AdminAccountSummary) => void;
  onSuspend: (a: AdminAccountSummary) => Promise<void>;
  onApproveAccount: (a: AdminAccountSummary) => Promise<void>;
  onOpenReject: (t: { phone: string; displayName: string; kind: string }) => void;
}) {
  const { field, dir, toggle } = useSort('createdAt');
  const sorted = useSorted(accounts, field, dir);

  if (accounts.length === 0) {
    return (
      <div className="empty-state">
        <Bike size={28} />
        <p>لا يوجد مندوبون مطابقون</p>
      </div>
    );
  }

  return (
    <div className="accounts-table-wrap">
      <table className="accounts-table">
        <thead>
          <tr>
            <SortableTh label="الاسم" sortField="name" currentField={field} currentDir={dir} onToggle={toggle} />
            <th>الهاتف</th>
            <SortableTh label="تاريخ التسجيل" sortField="createdAt" currentField={field} currentDir={dir} onToggle={toggle} />
            <th>حالة الموافقة</th>
            <th>الحساب</th>
            <th>الإجراءات</th>
          </tr>
        </thead>
        <tbody>
          {sorted.map((a) => {
            const suspendLoading = activeActionKey === `suspend-account:${a.phone}`;
            const deleteLoading = activeActionKey === `delete-account:${a.phone}`;
            const approvalLoading = activeActionKey === `approve-account:${a.phone}`;
            const rejectLoading = activeActionKey === `reject-account:${a.phone}`;
            const needsApproval = accountNeedsApproval(a);
            const isRejected = a.approvalStatus === 'rejected';
            const isPending = needsApproval && !a.isApproved && !isRejected;

            return (
              <tr key={a.phone}>
                <td className="td-name">{a.displayName || a.fullName || 'بدون اسم'}</td>
                <td className="td-phone">{a.phone}</td>
                <td>{formatDate(a.createdAt)}</td>
                <td>
                  {needsApproval ? (
                    a.isApproved ? (
                      <span className="status-badge success">مفعّل</span>
                    ) : isRejected ? (
                      <span className="status-badge danger">مرفوض</span>
                    ) : (
                      <span className="status-badge warning">بانتظار</span>
                    )
                  ) : (
                    <span className="status-badge success">مفعّل</span>
                  )}
                </td>
                <td>
                  {a.isSuspended
                    ? <span className="status-badge danger">معلّق</span>
                    : <span className="status-badge success">نشط</span>}
                </td>
                <td>
                  <div className="table-actions">
                    {needsApproval && isPending ? (
                      <button
                        className="soft-button success"
                        disabled={approvalLoading || rejectLoading}
                        onClick={() => onApproveAccount(a).catch(() => undefined)}
                      >
                        {approvalLoading ? <LoaderCircle className="spin" size={13} /> : <BadgeCheck size={13} />}
                        <span>تفعيل</span>
                      </button>
                    ) : null}
                    {needsApproval && (isPending || isRejected) ? (
                      <button
                        className="soft-button danger"
                        disabled={approvalLoading || rejectLoading}
                        onClick={() => onOpenReject({ phone: a.phone, displayName: a.displayName || a.phone, kind: a.kind })}
                      >
                        {rejectLoading ? <LoaderCircle className="spin" size={13} /> : <XCircle size={13} />}
                        <span>رفض</span>
                      </button>
                    ) : null}
                    <button
                      className={a.isSuspended ? 'soft-button success' : 'soft-button danger'}
                      disabled={suspendLoading || deleteLoading}
                      onClick={() => onSuspend(a).catch(() => undefined)}
                    >
                      {suspendLoading ? <LoaderCircle className="spin" size={13} /> : <UserX size={13} />}
                    </button>
                    <button
                      className="soft-button danger"
                      disabled={suspendLoading || deleteLoading}
                      onClick={() => onOpenDelete(a)}
                    >
                      {deleteLoading ? <LoaderCircle className="spin" size={13} /> : <Trash2 size={13} />}
                    </button>
                  </div>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

/* ═══════════════════════════════════════════
   DRIVER TABLE
═══════════════════════════════════════════ */
function DriverTable({
  accounts,
  activeActionKey,
  onOpenDelete,
  onSuspend,
  onApproveAccount,
  onOpenReject,
}: {
  accounts: AdminAccountSummary[];
  activeActionKey: string;
  onOpenDelete: (a: AdminAccountSummary) => void;
  onSuspend: (a: AdminAccountSummary) => Promise<void>;
  onApproveAccount: (a: AdminAccountSummary) => Promise<void>;
  onOpenReject: (t: { phone: string; displayName: string; kind: string }) => void;
}) {
  const { field, dir, toggle } = useSort('createdAt');
  const sorted = useSorted(accounts, field, dir);

  if (accounts.length === 0) {
    return (
      <div className="empty-state">
        <Car size={28} />
        <p>لا يوجد سائقو تكسي مطابقون</p>
      </div>
    );
  }

  return (
    <div className="accounts-table-wrap">
      <table className="accounts-table">
        <thead>
          <tr>
            <SortableTh label="الاسم" sortField="name" currentField={field} currentDir={dir} onToggle={toggle} />
            <th>الهاتف</th>
            <SortableTh label="تاريخ التسجيل" sortField="createdAt" currentField={field} currentDir={dir} onToggle={toggle} />
            <th>حالة الموافقة</th>
            <th>الحساب</th>
            <th>الإجراءات</th>
          </tr>
        </thead>
        <tbody>
          {sorted.map((a) => {
            const suspendLoading = activeActionKey === `suspend-account:${a.phone}`;
            const deleteLoading = activeActionKey === `delete-account:${a.phone}`;
            const approvalLoading = activeActionKey === `approve-account:${a.phone}`;
            const rejectLoading = activeActionKey === `reject-account:${a.phone}`;
            const needsApproval = accountNeedsApproval(a);
            const isRejected = a.approvalStatus === 'rejected';
            const isPending = needsApproval && !a.isApproved && !isRejected;

            return (
              <tr key={a.phone}>
                <td className="td-name">{a.displayName || a.fullName || 'بدون اسم'}</td>
                <td className="td-phone">{a.phone}</td>
                <td>{formatDate(a.createdAt)}</td>
                <td>
                  {needsApproval ? (
                    a.isApproved ? (
                      <span className="status-badge success">مفعّل</span>
                    ) : isRejected ? (
                      <span className="status-badge danger">مرفوض</span>
                    ) : (
                      <span className="status-badge warning">بانتظار</span>
                    )
                  ) : (
                    <span className="status-badge success">مفعّل</span>
                  )}
                </td>
                <td>
                  {a.isSuspended
                    ? <span className="status-badge danger">معلّق</span>
                    : <span className="status-badge success">نشط</span>}
                </td>
                <td>
                  <div className="table-actions">
                    {needsApproval && isPending ? (
                      <button
                        className="soft-button success"
                        disabled={approvalLoading || rejectLoading}
                        onClick={() => onApproveAccount(a).catch(() => undefined)}
                      >
                        {approvalLoading ? <LoaderCircle className="spin" size={13} /> : <BadgeCheck size={13} />}
                        <span>تفعيل</span>
                      </button>
                    ) : null}
                    {needsApproval && (isPending || isRejected) ? (
                      <button
                        className="soft-button danger"
                        disabled={approvalLoading || rejectLoading}
                        onClick={() => onOpenReject({ phone: a.phone, displayName: a.displayName || a.phone, kind: a.kind })}
                      >
                        {rejectLoading ? <LoaderCircle className="spin" size={13} /> : <XCircle size={13} />}
                        <span>رفض</span>
                      </button>
                    ) : null}
                    <button
                      className={a.isSuspended ? 'soft-button success' : 'soft-button danger'}
                      disabled={suspendLoading || deleteLoading}
                      onClick={() => onSuspend(a).catch(() => undefined)}
                    >
                      {suspendLoading ? <LoaderCircle className="spin" size={13} /> : <UserX size={13} />}
                    </button>
                    <button
                      className="soft-button danger"
                      disabled={suspendLoading || deleteLoading}
                      onClick={() => onOpenDelete(a)}
                    >
                      {deleteLoading ? <LoaderCircle className="spin" size={13} /> : <Trash2 size={13} />}
                    </button>
                  </div>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

/* ═══════════════════════════════════════════
   ADMIN TABLE
═══════════════════════════════════════════ */
function AdminTable({ accounts }: { accounts: AdminAccountSummary[] }) {
  const { field, dir, toggle } = useSort('name');
  const sorted = useSorted(accounts, field, dir);

  if (accounts.length === 0) {
    return (
      <div className="empty-state">
        <Shield size={28} />
        <p>لا يوجد مشرفون</p>
      </div>
    );
  }

  return (
    <div className="accounts-table-wrap">
      <table className="accounts-table">
        <thead>
          <tr>
            <SortableTh label="الاسم" sortField="name" currentField={field} currentDir={dir} onToggle={toggle} />
            <th>الهاتف</th>
            <SortableTh label="آخر تحديث" sortField="updatedAt" currentField={field} currentDir={dir} onToggle={toggle} />
            <th>الحالة</th>
          </tr>
        </thead>
        <tbody>
          {sorted.map((a) => (
            <tr key={a.phone}>
              <td className="td-name">{a.displayName || a.fullName || 'مشرف'}</td>
              <td className="td-phone">{a.phone}</td>
              <td>{formatDateTime(a.updatedAt)}</td>
              <td><span className="status-badge info">مشرف محمي</span></td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/* ═══════════════════════════════════════════
   MAIN COMPONENT
═══════════════════════════════════════════ */

const TABS: Array<{ filter: AccountFilter; label: string; icon: React.ReactNode; colorClass: string }> = [
  { filter: 'all',      label: 'الكل',              icon: <Users size={14} />,   colorClass: 'active-all' },
  { filter: 'customer', label: 'الزبائن',           icon: <Users size={14} />,   colorClass: 'active-customer' },
  { filter: 'merchant', label: 'التجار والمهنيون',  icon: <Store size={14} />,   colorClass: 'active-merchant' },
  { filter: 'courier',  label: 'مندوبو التوصيل',   icon: <Bike size={14} />,    colorClass: 'active-courier' },
  { filter: 'driver',   label: 'سائقو التكسي',     icon: <Car size={14} />,     colorClass: 'active-driver' },
  { filter: 'admin',    label: 'المشرفون',          icon: <Shield size={14} />,  colorClass: 'active-admin' },
];

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

  const byKind = useMemo(() => ({
    customer: filteredAccounts.filter((a) => a.kind === 'customer'),
    merchant: filteredAccounts.filter((a) => a.kind === 'merchant'),
    courier:  filteredAccounts.filter((a) => a.kind === 'courier'),
    driver:   filteredAccounts.filter((a) => a.kind === 'driver'),
    admin:    filteredAccounts.filter((a) => a.kind === 'admin'),
  }), [filteredAccounts]);

  const countFor = (f: AccountFilter) => {
    if (f === 'all') return filteredAccounts.length;
    if (f === 'customer') return byKind.customer.length;
    if (f === 'merchant') return byKind.merchant.length;
    if (f === 'courier')  return byKind.courier.length;
    if (f === 'driver')   return byKind.driver.length;
    if (f === 'admin')    return byKind.admin.length;
    return 0;
  };

  const renderTable = () => {
    const props = { activeActionKey, onOpenDelete, onSuspend, onApproveAccount, onOpenReject, onRoleChange };

    if (accountFilter === 'customer') return <CustomerTable accounts={byKind.customer} {...props} />;
    if (accountFilter === 'merchant') return <MerchantTable accounts={byKind.merchant} {...props} />;
    if (accountFilter === 'courier')  return <CourierTable  accounts={byKind.courier}  {...props} />;
    if (accountFilter === 'driver')   return <DriverTable   accounts={byKind.driver}   {...props} />;
    if (accountFilter === 'admin')    return <AdminTable accounts={byKind.admin} />;

    // ALL — show each section
    return (
      <>
        {byKind.customer.length > 0 ? (
          <>
            <div className="section-divider"><span>👤 الزبائن ({byKind.customer.length})</span></div>
            <CustomerTable accounts={byKind.customer} {...props} />
          </>
        ) : null}
        {byKind.merchant.length > 0 ? (
          <>
            <div className="section-divider"><span>🏪 التجار والمهنيون ({byKind.merchant.length})</span></div>
            <MerchantTable accounts={byKind.merchant} {...props} />
          </>
        ) : null}
        {byKind.courier.length > 0 ? (
          <>
            <div className="section-divider"><span>🛵 مندوبو التوصيل ({byKind.courier.length})</span></div>
            <CourierTable accounts={byKind.courier} {...props} />
          </>
        ) : null}
        {byKind.driver.length > 0 ? (
          <>
            <div className="section-divider"><span>🚕 سائقو التكسي ({byKind.driver.length})</span></div>
            <DriverTable accounts={byKind.driver} {...props} />
          </>
        ) : null}
        {byKind.admin.length > 0 ? (
          <>
            <div className="section-divider"><span>👑 المشرفون ({byKind.admin.length})</span></div>
            <AdminTable accounts={byKind.admin} />
          </>
        ) : null}
        {filteredAccounts.length === 0 ? (
          <div className="empty-state">
            <Users size={28} />
            <p>لا توجد حسابات مطابقة للبحث الحالي.</p>
          </div>
        ) : null}
      </>
    );
  };

  return (
    <>
      {/* Tab bar */}
      <div className="account-filter-row">
        {TABS.map(({ filter, label, icon, colorClass }) => (
          <button
            key={filter}
            type="button"
            className={`account-filter-chip ${accountFilter === filter ? colorClass : ''}`}
            onClick={() => onFilterChange(filter)}
          >
            {icon}
            {label}
            <span style={{
              background: 'rgba(255,255,255,0.1)',
              borderRadius: '999px',
              padding: '1px 7px',
              fontSize: '0.7rem',
              fontWeight: 900,
            }}>
              {countFor(filter)}
            </span>
          </button>
        ))}
      </div>

      {renderTable()}
    </>
  );
}
