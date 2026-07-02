import React, { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { loadMerchants } from '../../../admin-api';
import { useAdminToken } from '../../context/AuthContext';
import {
  isMerchantAccountPending,
  merchantModerationReviewPath,
} from '../../utils/moderation';
import { AdminAvatar, pickMerchantAvatarUrl } from '../../components/AdminAvatar';
import { formatPrimaryServiceLabel } from '../../utils/serviceLabels';

type Props = {
  title?: string;
  serviceFilter?: string;
  emptyHint?: string;
};

export function PendingAccountsPage({
  title = 'حسابات بانتظار الموافقة',
  serviceFilter,
  emptyHint = 'لا توجد حسابات معلقة حالياً.',
}: Props) {
  const token = useAdminToken();
  const [q, setQ] = useState('');
  const { data = [], isLoading } = useQuery({
    queryKey: ['merchants'],
    queryFn: () => loadMerchants(token),
    refetchOnMount: 'always',
  });

  const pending = useMemo(() => {
    let base = data.filter(isMerchantAccountPending);
    if (serviceFilter) {
      base = base.filter((m) => m.primaryServiceId === serviceFilter);
    } else {
      base = base.filter((m) =>
        ['product', 'restaurant', 'real_estate', 'cars', 'used', 'offers', 'bazar_ghaith'].includes(
          m.primaryServiceId || '',
        ),
      );
    }
    const hay = q.trim().toLowerCase();
    if (!hay) return base;
    return base.filter((m) =>
      `${m.phone} ${m.storeName} ${m.fullName}`.toLowerCase().includes(hay),
    );
  }, [data, q, serviceFilter]);

  return (
    <div>
      <div className="adm-page-header">
        <h2 style={{ margin: 0 }}>{title}</h2>
        <span className="adm-badge adm-badge-warning">{pending.length}</span>
      </div>

      <div className="adm-card" style={{ marginBottom: 16 }}>
        <input
          className="adm-input"
          placeholder="بحث بالاسم أو الهاتف..."
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
      </div>

      {isLoading ? (
        <p style={{ color: 'var(--adm-muted)' }}>جاري التحميل...</p>
      ) : pending.length === 0 ? (
        <div className="adm-card">
          <p style={{ margin: 0, color: 'var(--adm-muted)' }}>{emptyHint}</p>
        </div>
      ) : (
        <div className="adm-table-wrap">
          <table className="adm-table">
            <thead>
              <tr>
                <th>الصورة</th>
                <th>الحساب</th>
                <th>الهاتف</th>
                <th>القسم</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {pending.map((m) => (
                <tr key={m.phone}>
                  <td>
                    <AdminAvatar src={pickMerchantAvatarUrl(m)} alt={m.storeName || m.fullName || ''} />
                  </td>
                  <td>{m.storeName || m.fullName || '—'}</td>
                  <td dir="ltr">{m.phone}</td>
                  <td>
                    {formatPrimaryServiceLabel(m.primaryServiceId)}
                  </td>
                  <td>
                    <Link
                      to={merchantModerationReviewPath(m)}
                      className="adm-btn adm-btn-secondary"
                    >
                      مراجعة
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {!serviceFilter && (
        <div className="adm-card" style={{ marginTop: 16 }}>
          <p style={{ margin: 0, color: 'var(--adm-muted)', fontSize: '0.9rem', lineHeight: 1.7 }}>
            متاجر التسوق والمطاعم لا تحتاج موافقة على الحساب — راجع{' '}
            <Link to="/admin/moderation/products">المنتجات المعلقة</Link> بدلاً من ذلك.
            المهنيين والسياحة والصحة والجمال لها أقسام منفصلة في الموافقات.
          </p>
        </div>
      )}
    </div>
  );
}
