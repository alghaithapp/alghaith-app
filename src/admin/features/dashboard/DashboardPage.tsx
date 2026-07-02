import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { loadAdminReports } from '../../../admin-api';
import { useAdminToken } from '../../context/AuthContext';

export function DashboardPage() {
  const token = useAdminToken();
  const { data, isLoading, error } = useQuery({
    queryKey: ['admin-reports'],
    queryFn: () => loadAdminReports(token),
  });

  if (isLoading) return <p style={{ color: 'var(--adm-muted)' }}>جاري التحميل...</p>;
  if (error) return <p className="adm-error">{error instanceof Error ? error.message : 'خطأ'}</p>;

  const stats = [
    { label: 'المستخدمون', value: data?.totalUsers ?? 0 },
    { label: 'التجار', value: data?.totalMerchants ?? 0 },
    { label: 'المنتجات', value: data?.totalProducts ?? 0 },
    { label: 'الطلبات', value: data?.totalOrders ?? 0 },
    { label: 'السائقون', value: data?.totalDrivers ?? 0 },
    { label: 'المندوبون', value: data?.totalCouriers ?? 0 },
  ];

  return (
    <div>
      <div className="adm-page-header">
        <h1>الإحصائيات</h1>
      </div>
      <div className="adm-grid adm-grid-3">
        {stats.map((s) => (
          <div key={s.label} className="adm-card">
            <div className="adm-stat-value">{s.value}</div>
            <div className="adm-stat-label">{s.label}</div>
          </div>
        ))}
      </div>
      {data?.recentOrders && data.recentOrders.length > 0 && (
        <div className="adm-card" style={{ marginTop: 24 }}>
          <h3 style={{ marginTop: 0 }}>أحدث الطلبات</h3>
          <div className="adm-table-wrap">
            <table className="adm-table">
              <thead>
                <tr>
                  <th>العميل</th>
                  <th>التاجر</th>
                  <th>الحالة</th>
                  <th>المبلغ</th>
                </tr>
              </thead>
              <tbody>
                {data.recentOrders.slice(0, 8).map((o) => (
                  <tr key={o.id || o.orderNumber}>
                    <td>{o.customerNameAr || '—'}</td>
                    <td>{o.merchantStoreName || '—'}</td>
                    <td>{o.statusAr || o.statusKey}</td>
                    <td>{o.price?.toLocaleString('ar-IQ')} د.ع</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
