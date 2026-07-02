import React, { useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import {
  loadCouriers,
  loadDrivers,
  loadMerchants,
  loadPendingProducts,
  loadProfessionals,
} from '../../../admin-api';
import { useAdminToken } from '../../context/AuthContext';
import {
  countPendingMerchantAccounts,
  isMerchantAccountPending,
} from '../../utils/moderation';
import { isHealthBeautyMerchant } from '../health-beauty/constants';

function countPendingOperators<T extends { isApproved: boolean; approvalStatus: string }>(
  rows: T[],
) {
  return rows.filter(
    (r) => r.approvalStatus === 'pending' || (!r.isApproved && r.approvalStatus !== 'rejected'),
  ).length;
}

export function ModerationOverviewPage() {
  const token = useAdminToken();
  const { data: pendingProducts = [], isLoading: productsLoading } = useQuery({
    queryKey: ['pending-products'],
    queryFn: () => loadPendingProducts(token),
  });
  const { data: merchants = [], isLoading: merchantsLoading } = useQuery({
    queryKey: ['merchants'],
    queryFn: () => loadMerchants(token),
  });
  const { data: professionals = [], isLoading: prosLoading } = useQuery({
    queryKey: ['professionals'],
    queryFn: () => loadProfessionals(token),
  });
  const { data: drivers = [], isLoading: driversLoading } = useQuery({
    queryKey: ['drivers'],
    queryFn: () => loadDrivers(token),
  });
  const { data: couriers = [], isLoading: couriersLoading } = useQuery({
    queryKey: ['couriers'],
    queryFn: () => loadCouriers(token),
  });

  const stats = useMemo(() => {
    const pendingRealEstate = pendingProducts.filter((p) => p.category === 'real_estate').length;
    const pendingCars = pendingProducts.filter((p) => p.category === 'cars').length;
    const pendingUsed = pendingProducts.filter((p) => p.category === 'used').length;
    const pendingCatalog = pendingProducts.filter(
      (p) => !['real_estate', 'cars', 'used'].includes(p.category),
    ).length;

    const healthBeautyPending = merchants.filter(
      (m) => isHealthBeautyMerchant(m) && isMerchantAccountPending(m),
    ).length;

    return {
      accounts: countPendingMerchantAccounts(merchants, {
        excludeServices: ['professionals', 'tourism', 'beauty', 'pharmacy'],
      }),
      tourism: countPendingMerchantAccounts(merchants, { serviceId: 'tourism' }),
      healthBeauty: healthBeautyPending,
      professionals: countPendingOperators(professionals),
      products: pendingCatalog,
      realEstate: pendingRealEstate,
      cars: pendingCars,
      used: pendingUsed,
      drivers: countPendingOperators(drivers),
      couriers: countPendingOperators(couriers),
      total:
        stats.accounts +
        stats.tourism +
        stats.healthBeauty +
        stats.professionals +
        stats.products +
        stats.realEstate +
        stats.cars +
        stats.used +
        stats.drivers +
        stats.couriers,
    };
  }, [pendingProducts, merchants, professionals, drivers, couriers]);

  const loading =
    productsLoading || merchantsLoading || prosLoading || driversLoading || couriersLoading;

  const links = [
    { to: '/admin/moderation/products', label: 'منتجات وطعام', count: stats.products },
    { to: '/admin/moderation/real-estate', label: 'عقارات', count: stats.realEstate },
    { to: '/admin/moderation/cars', label: 'سيارات', count: stats.cars },
    { to: '/admin/moderation/used', label: 'مستعمل', count: stats.used },
    { to: '/admin/moderation/accounts', label: 'حسابات متاجر', count: stats.accounts },
    { to: '/admin/moderation/tourism', label: 'سياحة', count: stats.tourism },
    { to: '/admin/health-beauty', label: 'صحة وجمال', count: stats.healthBeauty },
    { to: '/admin/moderation/professionals', label: 'مهنيين', count: stats.professionals },
    { to: '/admin/moderation/drivers', label: 'سائقين', count: stats.drivers },
    { to: '/admin/moderation/couriers', label: 'مندوبين', count: stats.couriers },
  ];

  return (
    <div>
      <div className="adm-grid adm-grid-3" style={{ marginBottom: 24 }}>
        <div className="adm-stat-card">
          <div className="adm-stat-value">{loading ? '…' : stats.total}</div>
          <div className="adm-stat-label">إجمالي العناصر المعلقة</div>
        </div>
        <div className="adm-stat-card">
          <div className="adm-stat-value">
            {loading ? '…' : stats.products + stats.realEstate + stats.cars + stats.used}
          </div>
          <div className="adm-stat-label">منتجات وإعلانات</div>
        </div>
        <div className="adm-stat-card">
          <div className="adm-stat-value">
            {loading
              ? '…'
              : stats.accounts +
                stats.professionals +
                stats.tourism +
                stats.healthBeauty +
                stats.drivers +
                stats.couriers}
          </div>
          <div className="adm-stat-label">حسابات وبروفايلات</div>
        </div>
      </div>

      <div className="adm-card">
        <h3 style={{ marginTop: 0 }}>مراجعة سريعة</h3>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {links.map(({ to, label, count }) => (
            <Link key={to} to={to} className="adm-btn adm-btn-secondary">
              {label} ({loading ? '…' : count})
            </Link>
          ))}
        </div>
      </div>

      {!loading && stats.total === 0 && (
        <div className="adm-card" style={{ marginTop: 16 }}>
          <p style={{ margin: 0, color: 'var(--adm-muted)', lineHeight: 1.7 }}>
            لا توجد عناصر معلقة حالياً. عندما ينشر تاجر منتجاً جديداً سيظهر في{' '}
            <Link to="/admin/moderation/products">منتجات وطعام</Link>. حسابات المهنيين
            والصحة والجمال تظهر في أقسامها المخصصة أعلاه.
          </p>
        </div>
      )}

      <div className="adm-card" style={{ marginTop: 16 }}>
        <h3 style={{ marginTop: 0 }}>كيف تعمل الموافقات؟</h3>
        <ul style={{ margin: 0, paddingInlineStart: 20, color: 'var(--adm-muted)', lineHeight: 1.8 }}>
          <li>
            <strong>متاجر ومطاعم:</strong> الحساب يُفعَّل مباشرة — راجع المنتجات والأطعمة المنشورة فقط.
          </li>
          <li>
            <strong>مهنيين / سياحة / صحة وجمال:</strong> يحتاجون موافقة على الحساب قبل الظهور.
          </li>
          <li>عند الموافقة أو الرفض يُرسل إشعار للمستخدم على هاتفه.</li>
        </ul>
      </div>
    </div>
  );
}
