import React, { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { loadProfessionals } from '../../../admin-api';
import { PROFESSIONAL_CATEGORIES } from '../../../admin-types';
import type { ProfessionalSummary } from '../../../admin-types';
import { useAdminToken } from '../../context/AuthContext';
import { MerchantQuickActions } from '../../components/MerchantQuickActions';
import { AdminAvatar, pickMerchantAvatarUrl } from '../../components/AdminAvatar';
import { isMerchantAccountPending } from '../../utils/moderation';

type Props = {
  title: string;
  pendingOnly?: boolean;
  emptyHint: string;
};

export function ProfessionalsListPage({ title, pendingOnly = false, emptyHint }: Props) {
  const token = useAdminToken();
  const [q, setQ] = useState('');
  const [category, setCategory] = useState('');
  const { data = [], isLoading } = useQuery({
    queryKey: ['professionals'],
    queryFn: () => loadProfessionals(token),
    refetchOnMount: 'always',
  });

  const filtered = useMemo(() => {
    let base = data;
    if (pendingOnly) {
      base = base.filter((p) => isMerchantAccountPending(p));
    }
    if (category) {
      base = base.filter((p) => p.professionalCategoryId === category);
    }
    const hay = q.trim().toLowerCase();
    if (!hay) return base;
    return base.filter((p) =>
      `${p.phone} ${p.storeName} ${p.fullName} ${p.professionalCategoryLabel}`
        .toLowerCase()
        .includes(hay),
    );
  }, [data, q, category, pendingOnly]);

  return (
    <div>
      <div className="adm-page-header">
        <h2 style={{ margin: 0 }}>{title}</h2>
        {!pendingOnly && (
          <Link to="/admin/professionals/new" className="adm-btn adm-btn-primary">
            + تسجيل مهني
          </Link>
        )}
      </div>

      <div className="adm-card adm-grid adm-grid-2" style={{ marginBottom: 16 }}>
        <input
          className="adm-input"
          placeholder="بحث بالاسم أو الهاتف أو المهنة..."
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
        <select className="adm-select" value={category} onChange={(e) => setCategory(e.target.value)}>
          <option value="">كل التخصصات</option>
          {PROFESSIONAL_CATEGORIES.map((cat) => (
            <option key={cat.id} value={cat.id}>
              {cat.label}
            </option>
          ))}
        </select>
      </div>

      {isLoading ? (
        <p style={{ color: 'var(--adm-muted)' }}>جاري التحميل...</p>
      ) : filtered.length === 0 ? (
        <div className="adm-card">
          <p style={{ margin: 0, color: 'var(--adm-muted)' }}>{emptyHint}</p>
        </div>
      ) : (
        <ProfessionalsTable rows={filtered} />
      )}
    </div>
  );
}

function ProfessionalsTable({ rows }: { rows: ProfessionalSummary[] }) {
  return (
    <div className="adm-table-wrap">
      <table className="adm-table">
        <thead>
          <tr>
            <th>الصورة</th>
            <th>الاسم</th>
            <th>التخصص</th>
            <th>الهاتف</th>
            <th>الموافقة</th>
            <th>الحالة</th>
            <th>الأعمال</th>
            <th>إجراءات</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {rows.map((p) => (
            <tr key={p.phone}>
              <td>
                <AdminAvatar src={pickMerchantAvatarUrl(p)} alt={p.storeName || p.fullName || ''} />
              </td>
              <td>{p.storeName || p.fullName || '—'}</td>
              <td>{p.professionalCategoryLabel || '—'}</td>
              <td dir="ltr">{p.phone}</td>
              <td>
                {p.isApproved ? (
                  <span className="adm-badge adm-badge-success">معتمد</span>
                ) : p.approvalStatus === 'rejected' ? (
                  <span className="adm-badge adm-badge-danger">مرفوض</span>
                ) : (
                  <span className="adm-badge adm-badge-warning">معلق</span>
                )}
              </td>
              <td>
                {p.isFrozen ? (
                  <span className="adm-badge adm-badge-danger">مجمّد</span>
                ) : (
                  <span className="adm-badge adm-badge-success">نشط</span>
                )}
              </td>
              <td>{p.workSampleCount ?? 0}</td>
              <td>
                <MerchantQuickActions
                  phone={p.phone}
                  label={p.storeName || p.fullName || p.phone}
                  isFrozen={p.isFrozen}
                  invalidateKeys={['professionals']}
                />
              </td>
              <td>
                <Link
                  to={`/admin/professionals/${encodeURIComponent(p.phone)}`}
                  className="adm-btn adm-btn-secondary"
                >
                  إدارة
                </Link>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
