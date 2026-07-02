import React, { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { loadMerchants } from '../../../admin-api';
import type { MerchantSummary } from '../../../admin-types';
import { useAdminToken } from '../../context/AuthContext';
import {
  isMerchantAccountPending,
  merchantAccountApprovalRequired,
  merchantModerationListPath,
  merchantModerationReviewPath,
} from '../../utils/moderation';
import { AdminAvatar, pickMerchantAvatarUrl } from '../../components/AdminAvatar';
import { formatPrimaryServiceLabel } from '../../utils/serviceLabels';

function AccountStatusCell({ m }: { m: MerchantSummary }) {
  if (!merchantAccountApprovalRequired(m)) {
    return <span className="adm-badge adm-badge-success" title="لا يحتاج موافقة حساب">نشط</span>;
  }
  if (m.isApproved) {
    return <span className="adm-badge adm-badge-success">معتمد</span>;
  }
  if (m.approvalStatus === 'rejected') {
    return <span className="adm-badge adm-badge-danger">مرفوض</span>;
  }
  return (
    <Link
      to={merchantModerationReviewPath(m)}
      className="adm-badge adm-badge-warning"
      style={{ textDecoration: 'none' }}
      title={`مراجعة في ${merchantModerationListPath(m)}`}
    >
      معلق — مراجعة
    </Link>
  );
}

export function MerchantsPage() {
  const token = useAdminToken();
  const [q, setQ] = useState('');
  const { data = [], isLoading } = useQuery({
    queryKey: ['merchants'],
    queryFn: () => loadMerchants(token),
  });

  const filtered = useMemo(() => {
    const hay = q.trim().toLowerCase();
    if (!hay) return data;
    return data.filter((m) =>
      `${m.phone} ${m.storeName} ${m.primaryServiceId} ${formatPrimaryServiceLabel(m.primaryServiceId)}`
        .toLowerCase()
        .includes(hay),
    );
  }, [data, q]);

  const pendingAccountCount = useMemo(
    () => data.filter(isMerchantAccountPending).length,
    [data],
  );
  const pendingProductsCount = useMemo(
    () => data.reduce((sum, m) => sum + (m.pendingProducts ?? 0), 0),
    [data],
  );

  return (
    <div>
      <div className="adm-page-header">
        <h1>التجار</h1>
        <Link to="/admin/merchants/new" className="adm-btn adm-btn-primary">+ تاجر جديد</Link>
      </div>

      {(pendingAccountCount > 0 || pendingProductsCount > 0) && (
        <div className="adm-card" style={{ marginBottom: 16 }}>
          <p style={{ margin: 0, color: 'var(--adm-muted)', lineHeight: 1.7 }}>
            {pendingProductsCount > 0 && (
              <>
                <Link to="/admin/moderation/products">{pendingProductsCount} منتج/طعام معلق</Link>
                {' — يحتاج موافقة قبل الظهور للزبائن. '}
              </>
            )}
            {pendingAccountCount > 0 && (
              <>
                <Link to="/admin/moderation">{pendingAccountCount} حساب معلق</Link>
                {' — مهنيين أو صحة وجمال أو سياحة (راجع قسم الموافقات).'}
              </>
            )}
          </p>
        </div>
      )}

      <div className="adm-card" style={{ marginBottom: 16 }}>
        <input className="adm-input" placeholder="بحث بالاسم أو الهاتف..." value={q} onChange={(e) => setQ(e.target.value)} />
      </div>
      {isLoading ? (
        <p style={{ color: 'var(--adm-muted)' }}>جاري التحميل...</p>
      ) : (
        <div className="adm-table-wrap">
          <table className="adm-table">
            <thead>
              <tr>
                <th>الصورة</th>
                <th>المتجر</th>
                <th>الهاتف</th>
                <th>القسم</th>
                <th>الحساب</th>
                <th>منتجات معلقة</th>
                <th>الطلبات</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((m) => (
                <tr key={m.phone}>
                  <td>
                    <AdminAvatar src={pickMerchantAvatarUrl(m)} alt={m.storeName || ''} />
                  </td>
                  <td>{m.storeName || '—'}</td>
                  <td dir="ltr">{m.phone}</td>
                  <td>{formatPrimaryServiceLabel(m.primaryServiceId)}</td>
                  <td>
                    <AccountStatusCell m={m} />
                  </td>
                  <td>
                    {(m.pendingProducts ?? 0) > 0 ? (
                      <Link
                        to={`/admin/merchants/${encodeURIComponent(m.phone)}`}
                        className="adm-badge adm-badge-warning"
                        style={{ textDecoration: 'none' }}
                      >
                        {m.pendingProducts} معلق
                      </Link>
                    ) : (
                      <span style={{ color: 'var(--adm-muted)' }}>—</span>
                    )}
                  </td>
                  <td>{m.totalOrders ?? 0}</td>
                  <td>
                    <Link to={`/admin/merchants/${encodeURIComponent(m.phone)}`} className="adm-btn adm-btn-secondary">
                      إدارة
                    </Link>
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
