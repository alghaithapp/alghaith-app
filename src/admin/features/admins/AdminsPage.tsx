import React, { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import type { AdminPermissions } from '../../../admin-types';
import {
  inviteAdmin,
  loadAllAdmins,
  removeAdmin,
  updateAdminPermissions,
} from '../../../admin-api';
import { useAdminToken, useAuth } from '../../context/AuthContext';

const PERM_LABELS: Record<keyof AdminPermissions, string> = {
  canRegister: 'تسجيل حسابات',
  canApprove: 'موافقة / رفض',
  canDelete: 'حذف',
  canSuspend: 'تعليق',
  canManageAdmins: 'إدارة المشرفين',
};

export function AdminsPage() {
  const token = useAdminToken();
  const { role } = useAuth();
  const qc = useQueryClient();
  const [targetPhone, setTargetPhone] = useState('');
  const [adminRole, setAdminRole] = useState<'admin' | 'moderator'>('moderator');
  const [perms, setPerms] = useState<AdminPermissions>({
    canRegister: true,
    canApprove: true,
    canDelete: false,
    canSuspend: true,
    canManageAdmins: false,
  });
  const [error, setError] = useState('');

  const { data, isLoading } = useQuery({
    queryKey: ['all-admins'],
    queryFn: () => loadAllAdmins(token),
    enabled: role === 'super_admin' || role === 'admin',
  });

  const inviteMut = useMutation({
    mutationFn: () => inviteAdmin(token, targetPhone.trim(), perms),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['all-admins'] });
      setTargetPhone('');
      setError('');
    },
    onError: (e: Error) => setError(e.message),
  });

  const removeMut = useMutation({
    mutationFn: (phone: string) => removeAdmin(token, phone),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['all-admins'] }),
  });

  const updatePermMut = useMutation({
    mutationFn: ({ phone, permissions }: { phone: string; permissions: AdminPermissions }) =>
      updateAdminPermissions(token, phone, permissions),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['all-admins'] }),
  });

  if (role !== 'super_admin' && role !== 'admin') {
    return <p className="adm-error">صلاحية super_admin أو admin مطلوبة</p>;
  }

  return (
    <div>
      <div className="adm-page-header">
        <h1>إدارة المشرفين</h1>
      </div>

      <div className="adm-card" style={{ marginBottom: 24, maxWidth: 640 }}>
        <h3 style={{ marginTop: 0 }}>دعوة مشرف جديد</h3>
        <div className="adm-grid adm-grid-2">
          <div className="adm-field">
            <label className="adm-label">رقم الهاتف</label>
            <input className="adm-input" dir="ltr" value={targetPhone} onChange={(e) => setTargetPhone(e.target.value)} />
          </div>
          <div className="adm-field">
            <label className="adm-label">الدور</label>
            <select className="adm-select" value={adminRole} onChange={(e) => setAdminRole(e.target.value as 'admin' | 'moderator')}>
              <option value="moderator">مشرف (moderator)</option>
              <option value="admin">مدير (admin)</option>
            </select>
          </div>
        </div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12, marginBottom: 16 }}>
          {(Object.keys(PERM_LABELS) as Array<keyof AdminPermissions>).map((key) => (
            <label key={key} style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '0.88rem' }}>
              <input
                type="checkbox"
                checked={Boolean(perms[key])}
                onChange={(e) => setPerms((p) => ({ ...p, [key]: e.target.checked }))}
              />
              {PERM_LABELS[key]}
            </label>
          ))}
        </div>
        {error && <p className="adm-error">{error}</p>}
        <button
          type="button"
          className="adm-btn adm-btn-primary"
          disabled={!targetPhone.trim() || inviteMut.isPending}
          onClick={() => inviteMut.mutate()}
        >
          إرسال الدعوة
        </button>
      </div>

      {isLoading ? (
        <p style={{ color: 'var(--adm-muted)' }}>جاري التحميل...</p>
      ) : (
        <div className="adm-table-wrap">
          <table className="adm-table">
            <thead>
              <tr>
                <th>الاسم</th>
                <th>الهاتف</th>
                <th>الدور</th>
                <th>الصلاحيات</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {(data?.admins || []).map((a) => (
                <tr key={a.phone}>
                  <td>{a.fullName || '—'}</td>
                  <td dir="ltr">{a.phone}</td>
                  <td><span className="adm-badge adm-badge-muted">{a.role}</span></td>
                  <td style={{ fontSize: '0.8rem', color: 'var(--adm-muted)' }}>
                    {a.permissions
                      ? Object.entries(a.permissions)
                          .filter(([, v]) => v)
                          .map(([k]) => PERM_LABELS[k as keyof AdminPermissions] || k)
                          .join('، ') || '—'
                      : '—'}
                  </td>
                  <td style={{ display: 'flex', gap: 6 }}>
                    {role === 'super_admin' && a.role !== 'super_admin' && (
                      <>
                        <button
                          type="button"
                          className="adm-btn adm-btn-secondary"
                          onClick={() => {
                            const next = { ...a.permissions, canApprove: true, canRegister: true } as AdminPermissions;
                            updatePermMut.mutate({ phone: a.phone, permissions: next });
                          }}
                        >
                          صلاحيات كاملة
                        </button>
                        <button
                          type="button"
                          className="adm-btn adm-btn-danger"
                          onClick={() => {
                            if (confirm('إزالة هذا المشرف؟')) removeMut.mutate(a.phone);
                          }}
                        >
                          إزالة
                        </button>
                      </>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
