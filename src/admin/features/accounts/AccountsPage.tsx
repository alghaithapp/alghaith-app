import React, { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import {
  deleteAdminAccount,
  loadAdminAccounts,
  suspendAdminAccount,
} from '../../../admin-api';
import { useAdminToken, useAuth } from '../../context/AuthContext';

export function AccountsPage() {
  const token = useAdminToken();
  const { hasPermission } = useAuth();
  const qc = useQueryClient();
  const [q, setQ] = useState('');
  const [kind, setKind] = useState('all');

  const { data = [], isLoading } = useQuery({
    queryKey: ['admin-accounts'],
    queryFn: () => loadAdminAccounts(token),
  });

  const suspendMut = useMutation({
    mutationFn: ({ phone, suspended }: { phone: string; suspended: boolean }) =>
      suspendAdminAccount(token, phone, suspended),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-accounts'] }),
  });

  const deleteMut = useMutation({
    mutationFn: (phone: string) => deleteAdminAccount(token, phone),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-accounts'] }),
  });

  const filtered = useMemo(() => {
    return data.filter((a) => {
      if (kind !== 'all' && a.kind !== kind) return false;
      const hay = `${a.phone} ${a.fullName} ${a.displayName}`.toLowerCase();
      return !q.trim() || hay.includes(q.trim().toLowerCase());
    });
  }, [data, kind, q]);

  return (
    <div>
      <div className="adm-page-header">
        <h1>الحسابات</h1>
        <Link to="/admin/customers/new" className="adm-btn adm-btn-primary">+ زبون جديد</Link>
      </div>

      <div className="adm-card" style={{ marginBottom: 16, display: 'flex', gap: 12, flexWrap: 'wrap' }}>
        <input className="adm-input" style={{ maxWidth: 280 }} placeholder="بحث..." value={q} onChange={(e) => setQ(e.target.value)} />
        <select className="adm-select" style={{ maxWidth: 180 }} value={kind} onChange={(e) => setKind(e.target.value)}>
          <option value="all">الكل</option>
          <option value="customer">زبائن</option>
          <option value="merchant">تجار</option>
          <option value="driver">سائقون</option>
          <option value="courier">مندوبون</option>
          <option value="admin">مشرفون</option>
        </select>
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
                <th>النوع</th>
                <th>الحالة</th>
                <th>إجراءات</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((a) => (
                <tr key={a.phone}>
                  <td>{a.fullName || a.displayName || '—'}</td>
                  <td dir="ltr">{a.phone}</td>
                  <td><span className="adm-badge adm-badge-muted">{a.kind}</span></td>
                  <td>
                    {a.isSuspended ? (
                      <span className="adm-badge adm-badge-danger">موقوف</span>
                    ) : (
                      <span className="adm-badge adm-badge-success">نشط</span>
                    )}
                  </td>
                  <td style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                    {a.kind === 'merchant' && (
                      <Link to={`/admin/merchants/${encodeURIComponent(a.phone)}`} className="adm-btn adm-btn-secondary">
                        التفاصيل
                      </Link>
                    )}
                    {hasPermission('canSuspend') && (
                      <button
                        type="button"
                        className="adm-btn adm-btn-secondary"
                        onClick={() => suspendMut.mutate({ phone: a.phone, suspended: !a.isSuspended })}
                      >
                        {a.isSuspended ? 'إلغاء التعليق' : 'تعليق'}
                      </button>
                    )}
                    {hasPermission('canDelete') && a.kind !== 'admin' && (
                      <button
                        type="button"
                        className="adm-btn adm-btn-danger"
                        onClick={() => {
                          if (confirm('حذف الحساب نهائياً؟')) deleteMut.mutate(a.phone);
                        }}
                      >
                        حذف
                      </button>
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
