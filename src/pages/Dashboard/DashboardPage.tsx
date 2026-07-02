import React from 'react';
import { useReports, useAccounts } from '../../hooks/useAdminData';
import { LoaderCircle, ShoppingBag, TrendingUp, Users, Store, ArrowUpRight } from 'lucide-react';
import { Card } from '../../components/ui/Card';
import { Badge } from '../../components/ui/Badge';
import { Table, Thead, Tbody, Tr, Th, Td } from '../../components/ui/Table';

const METRIC_THEMES: Record<string, { bg: string; iconBg: string; text: string; glow: string }> = {
  info: {
    bg: 'linear-gradient(135deg, rgba(14, 165, 233, 0.15) 0%, rgba(14, 165, 233, 0.02) 100%)',
    iconBg: 'rgba(14, 165, 233, 0.2)',
    text: '#0ea5e9',
    glow: 'rgba(14, 165, 233, 0.15)',
  },
  warning: {
    bg: 'linear-gradient(135deg, rgba(245, 158, 11, 0.15) 0%, rgba(245, 158, 11, 0.02) 100%)',
    iconBg: 'rgba(245, 158, 11, 0.2)',
    text: '#f59e0b',
    glow: 'rgba(245, 158, 11, 0.12)',
  },
  'brand-primary': {
    bg: 'linear-gradient(135deg, rgba(99, 102, 241, 0.15) 0%, rgba(99, 102, 241, 0.02) 100%)',
    iconBg: 'rgba(99, 102, 241, 0.2)',
    text: '#6366f1',
    glow: 'rgba(99, 102, 241, 0.15)',
  },
  success: {
    bg: 'linear-gradient(135deg, rgba(16, 185, 129, 0.15) 0%, rgba(16, 185, 129, 0.02) 100%)',
    iconBg: 'rgba(16, 185, 129, 0.2)',
    text: '#10b981',
    glow: 'rgba(16, 185, 129, 0.15)',
  },
};

function MetricCard({ icon, title, value, hint, color }: any) {
  const theme = METRIC_THEMES[color] || METRIC_THEMES.info;
  return (
    <div style={{
      background: theme.bg,
      borderRadius: '20px',
      border: '1px solid rgba(255, 255, 255, 0.05)',
      padding: '24px',
      display: 'flex',
      flexDirection: 'row',
      gap: '20px',
      alignItems: 'center',
      boxShadow: `0 8px 30px ${theme.glow}`,
      transition: 'transform 0.2s ease, border-color 0.2s ease',
      cursor: 'pointer',
    }}
    onMouseEnter={(e) => {
      e.currentTarget.style.transform = 'translateY(-2px)';
      e.currentTarget.style.borderColor = theme.text;
    }}
    onMouseLeave={(e) => {
      e.currentTarget.style.transform = 'none';
      e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.05)';
    }}
    >
      <div style={{
        width: '56px',
        height: '56px',
        borderRadius: '16px',
        display: 'grid',
        placeItems: 'center',
        background: theme.iconBg,
        color: theme.text,
        boxShadow: `0 4px 12px ${theme.glow}`,
      }}>
        {icon}
      </div>
      <div style={{ flex: 1 }}>
        <p style={{ margin: '0 0 6px', fontSize: '0.9rem', color: 'var(--text-secondary)', fontWeight: 600 }}>{title}</p>
        <strong style={{ fontSize: '1.7rem', color: '#fff', display: 'block', letterSpacing: '-0.5px' }}>{value}</strong>
        <span style={{ display: 'block', fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '4px' }}>{hint}</span>
      </div>
    </div>
  );
}

export default function DashboardPage() {
  const token = sessionStorage.getItem('alghaith-admin-session-v1') || '';
  const { data: reports, isLoading: reportsLoading } = useReports(token);
  const { data: accounts, isLoading: accountsLoading } = useAccounts(token);

  if (reportsLoading || accountsLoading) {
    return (
      <div style={{ display: 'grid', placeItems: 'center', minHeight: '300px' }}>
        <LoaderCircle className="spin" size={40} color="var(--brand-primary)" />
      </div>
    );
  }

  const formatMoney = (val: number) => new Intl.NumberFormat('ar-IQ').format(val);

  const totalCustomers = accounts?.filter(a => a.kind === 'customer').length || 0;
  const totalMerchants = accounts?.filter(a => a.kind === 'merchant').length || 0;
  const totalCouriers = accounts?.filter(a => a.kind === 'courier').length || 0;
  const totalDrivers = accounts?.filter(a => a.kind === 'driver').length || 0;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '32px' }} className="fade-in">
      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: '24px' }}>
        <MetricCard icon={<ShoppingBag size={26} />} color="info" title="إجمالي طلبات المنصة" value={String(reports?.totalOrders || 0)} hint={`${reports?.completedOrders || 0} مكتملة · ${reports?.pendingOrders || 0} قيد التحضير`} />
        <MetricCard icon={<TrendingUp size={26} />} color="warning" title="إجمالي مبيعات التجار" value={`${formatMoney(reports?.totalSales || 0)} د.ع`} hint={`المبالغ المستلمة: ${formatMoney(reports?.codCollected || 0)} د.ع`} />
        <MetricCard icon={<Users size={26} />} color="brand-primary" title="المستخدمون المسجلون" value={String(reports?.totalUsers || 0)} hint={`${totalCustomers} زبون نشط · ${totalMerchants} متجر`} />
        <MetricCard icon={<Store size={26} />} color="success" title="المتاجر المتاحة حالياً" value={String(reports?.openMerchants || 0)} hint={`${reports?.totalMerchants || 0} إجمالي المحلات المعتمدة`} />
      </section>

      <div style={{
        background: 'rgba(255,255,255,0.01)',
        borderRadius: '20px',
        border: '1px solid var(--border-strong)',
        padding: '20px 24px',
        display: 'flex',
        alignItems: 'center',
        gap: '24px',
        flexWrap: 'wrap'
      }}>
        <span style={{ fontSize: '0.9rem', fontWeight: 700, color: 'var(--text-secondary)' }}>توزيع النشاط:</span>
        <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
          <Badge variant="info">زبون: {totalCustomers}</Badge>
          <Badge variant="warning">تاجر: {totalMerchants}</Badge>
          <Badge variant="success">مندوب: {totalCouriers}</Badge>
          <Badge variant="neutral">تكسي: {totalDrivers}</Badge>
        </div>
      </div>

      <div className="ui-card padding-none" style={{ background: 'rgba(17, 24, 39, 0.25)', backdropFilter: 'blur(20px)', border: '1px solid var(--border-strong)' }}>
        <div style={{ padding: '24px', borderBottom: '1px solid var(--border-strong)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <h3 style={{ margin: 0, fontSize: '1.2rem', fontWeight: 800 }}>أحدث العمليات على الطلبات</h3>
          <span style={{ fontSize: '0.85rem', color: 'var(--brand-primary)', fontWeight: 'bold', display: 'flex', alignItems: 'center', gap: '4px', cursor: 'pointer' }}>
            عرض الكل <ArrowUpRight size={16} />
          </span>
        </div>
        <div style={{ overflowX: 'auto' }}>
          <Table>
            <Thead>
              <Tr>
                <Th>رقم الطلب</Th>
                <Th>الزبون</Th>
                <Th>التاجر</Th>
                <Th>التاريخ</Th>
                <Th>المبلغ الكلي</Th>
                <Th>حالة الطلب</Th>
              </Tr>
            </Thead>
            <Tbody>
              {reports?.recentOrders?.length ? reports.recentOrders.map((o: any) => (
                <Tr key={o.id} style={{ transition: 'background 0.2s' }}>
                  <Td dir="ltr" style={{ textAlign: 'right', fontFamily: 'monospace', fontWeight: 'bold', color: 'var(--brand-primary-dim)' }}>
                    #{o.id.split('-')[0].toUpperCase()}
                  </Td>
                  <Td style={{ fontWeight: '500' }}>{o.customerName || o.customerPhone}</Td>
                  <Td>{o.merchantName || '—'}</Td>
                  <Td style={{ color: 'var(--text-secondary)' }}>{new Date(o.createdAt).toLocaleDateString('ar-IQ')}</Td>
                  <Td style={{ fontWeight: 'bold', color: '#fff' }}>{formatMoney(o.totalPrice)} د.ع</Td>
                  <Td>
                    <Badge variant={!o.status ? 'warning' : o.status.includes('complet') ? 'success' : o.status.includes('cancel') ? 'error' : 'info'}>
                      {o.status === 'completed' ? 'مكتمل' : o.status === 'cancelled' ? 'ملغي' : o.status === 'pending' ? 'قيد الانتظار' : o.status || 'معلق'}
                    </Badge>
                  </Td>
                </Tr>
              )) : (
                <Tr><Td colSpan={6} style={{ textAlign: 'center', padding: '32px', color: 'var(--text-muted)' }}>لا توجد طلبات حديثة في المنصة</Td></Tr>
              )}
            </Tbody>
          </Table>
        </div>
      </div>
    </div>
  );
}
