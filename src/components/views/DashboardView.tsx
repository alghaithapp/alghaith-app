import React, { ReactNode } from 'react';
import {
  ShoppingBag, Store, Users, TrendingUp, BadgeCheck, Bike,
  Snowflake, Car, ArrowUpRight, Clock, CheckCircle2, AlertCircle
} from 'lucide-react';
import type { AdminReports, MerchantSummary, CourierSummary } from '../../admin-types';
import { Card } from '../ui/Card';
import { Button } from '../ui/Button';
import { Badge } from '../ui/Badge';
import { Table, Thead, Tbody, Tr, Th, Td } from '../ui/Table';

interface DashboardViewProps {
  reports: AdminReports | null;
  pendingMerchantQueue: MerchantSummary[];
  pendingCourierQueue: CourierSummary[];
  approvalQueue: MerchantSummary[];
  frozenMerchants: number;
  pendingDriverCount: number;
  totalCustomers: number;
  totalMerchants: number;
  totalCouriers: number;
  totalDrivers: number;
  onSwitchView: (view: any) => void;
  onSetMerchantFilter: (filter: string) => void;
  formatMoney: (value: number) => string;
  formatDate: (value: string | null | undefined) => string;
}

function MetricCard({ icon, title, value, hint, color }: { icon: ReactNode; title: string; value: string; hint: string; color: string }) {
  return (
    <Card padding="md" style={{ display: 'flex', flexDirection: 'row', gap: '16px', alignItems: 'center' }}>
      <div style={{
        width: 50, height: 50, borderRadius: 14, display: 'grid', placeItems: 'center',
        background: `rgba(var(--${color}-rgb, 14, 165, 233), 0.1)`,
        color: `var(--brand-primary)`,
      }}>
        {icon}
      </div>
      <div>
        <p style={{ margin: '0 0 4px', fontSize: '0.9rem', color: 'var(--text-secondary)' }}>{title}</p>
        <strong style={{ fontSize: '1.4rem', color: 'var(--text-primary)' }}>{value}</strong>
        <span style={{ display: 'block', fontSize: '0.75rem', color: 'var(--text-muted)' }}>{hint}</span>
      </div>
    </Card>
  );
}

function QuickActionCard({ icon, label, count, buttonLabel, onClick }: { icon: ReactNode; label: string; count: number; buttonLabel: string; onClick: () => void; }) {
  return (
    <Card padding="md" style={{ display: 'flex', flexDirection: 'column', gap: '12px', alignItems: 'center', textAlign: 'center', justifyContent: 'space-between' }}>
      <p style={{ margin: 0, color: 'var(--text-secondary)' }}>{label}</p>
      <strong style={{ fontSize: '1.8rem', color: count > 0 ? 'var(--warning)' : 'var(--text-primary)' }}>{count}</strong>
      <Button variant="secondary" onClick={onClick} icon={icon} style={{ width: '100%' }}>
        {buttonLabel}
      </Button>
    </Card>
  );
}

function statusColor(statusKey?: string | null) {
  if (!statusKey) return 'warning';
  if (statusKey.includes('complet') || statusKey === 'delivered') return 'success';
  if (statusKey.includes('cancel') || statusKey.includes('reject')) return 'error';
  if (statusKey.includes('deliver') || statusKey.includes('transit')) return 'info';
  return 'warning';
}

function statusLabel(statusKey?: string | null) {
  if (!statusKey) return 'غير معروف';
  const map: Record<string, string> = {
    pending: 'معلق', processing: 'قيد التجهيز', ready: 'جاهز',
    delivering: 'جاري التوصيل', delivered: 'تم التوصيل',
    cancelled: 'ملغي', rejected: 'مرفوض',
  };
  return map[statusKey] || statusKey;
}

export default function DashboardView({
  reports, pendingMerchantQueue, pendingCourierQueue, approvalQueue, frozenMerchants,
  pendingDriverCount, totalCustomers, totalMerchants, totalCouriers, totalDrivers,
  onSwitchView, onSetMerchantFilter, formatMoney, formatDate,
}: DashboardViewProps) {
  const totalPendingApprovals = pendingMerchantQueue.length + pendingCourierQueue.length + pendingDriverCount;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '32px' }}>
      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: '20px' }}>
        <MetricCard icon={<ShoppingBag size={24} />} color="info" title="إجمالي الطلبات" value={String(reports?.totalOrders || 0)} hint={`${reports?.completedOrders || 0} مكتمل · ${reports?.pendingOrders || 0} معلق`} />
        <MetricCard icon={<TrendingUp size={24} />} color="warning" title="إجمالي المبيعات" value={`${formatMoney(reports?.totalSales || 0)} د.ع`} hint={`COD: ${formatMoney(reports?.codCollected || 0)} د.ع`} />
        <MetricCard icon={<Users size={24} />} color="brand-primary" title="إجمالي المستخدمين" value={String(reports?.totalUsers || 0)} hint={`${totalCustomers} زبون · ${totalMerchants} تاجر`} />
        <MetricCard icon={<Store size={24} />} color="success" title="التجار النشطون" value={String(reports?.openMerchants || 0)} hint={`${reports?.totalMerchants || 0} إجمالي التجار`} />
      </section>

      <Card padding="md" style={{ display: 'flex', alignItems: 'center', gap: '20px', flexWrap: 'wrap' }}>
        <span style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-muted)' }}>توزيع المستخدمين:</span>
        <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap', flex: 1 }}>
          <Badge variant="info">زبون: {totalCustomers}</Badge>
          <Badge variant="warning">تاجر: {totalMerchants}</Badge>
          <Badge variant="success">مندوب: {totalCouriers}</Badge>
          <Badge variant="neutral">تكسي: {totalDrivers}</Badge>
        </div>
        {totalPendingApprovals > 0 ? (
          <Badge variant="warning" icon={<AlertCircle size={14} />}>{totalPendingApprovals} طلب معلق</Badge>
        ) : (
          <Badge variant="success" icon={<CheckCircle2 size={14} />}>لا توجد طلبات معلقة</Badge>
        )}
      </Card>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '20px' }}>
        <QuickActionCard icon={<Store size={16} />} label="طلبات التجار" count={pendingMerchantQueue.length} buttonLabel="مراجعة التجار" onClick={() => onSwitchView('merchants')} />
        <QuickActionCard icon={<BadgeCheck size={16} />} label="موافقات بازار" count={approvalQueue.length} buttonLabel="مراجعة البازار" onClick={() => { onSetMerchantFilter('bazaar'); onSwitchView('merchants'); }} />
        <QuickActionCard icon={<Bike size={16} />} label="طلبات المندوبين" count={pendingCourierQueue.length} buttonLabel="مراجعة المندوبين" onClick={() => onSwitchView('couriers')} />
        <QuickActionCard icon={<Car size={16} />} label="طلبات التكسي" count={pendingDriverCount} buttonLabel="مراجعة سائقي التكسي" onClick={() => onSwitchView('drivers')} />
        <QuickActionCard icon={<Snowflake size={16} />} label="حسابات مجمدة" count={frozenMerchants} buttonLabel="عرض المجمدين" onClick={() => { onSetMerchantFilter('rejected'); onSwitchView('merchants'); }} />
      </section>

      <Card padding="none">
        <div style={{ padding: '24px', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <h3 style={{ margin: 0 }}>أحدث الطلبات النشطة</h3>
            <p style={{ margin: '4px 0 0', color: 'var(--text-secondary)', fontSize: '0.85rem' }}>آخر 15 طلب لم يتم توصيله أو إلغاؤه.</p>
          </div>
        </div>
        <Table>
          <Thead>
            <Tr>
              <Th>الطلب</Th>
              <Th>التاجر</Th>
              <Th>الزبون</Th>
              <Th>المندوب</Th>
              <Th>الوقت</Th>
              <Th>السعر (د.ع)</Th>
              <Th>الحالة</Th>
            </Tr>
          </Thead>
          <Tbody>
            {reports?.recentOrders?.length ? (
              reports.recentOrders.map((o) => (
                <Tr key={o.id}>
                  <Td>
                    <span style={{ fontSize: '0.75rem', fontFamily: 'monospace', color: 'var(--text-muted)' }}>{o.id.split('-')[0]}</span>
                  </Td>
                  <Td><strong>{o.storeName || 'متجر'}</strong><br /><span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }} dir="ltr">{o.merchantPhone}</span></Td>
                  <Td><span dir="ltr">{o.customerPhone}</span></Td>
                  <Td>{o.courierPhone ? <span dir="ltr">{o.courierPhone}</span> : <span style={{ color: 'var(--text-muted)' }}>--</span>}</Td>
                  <Td><span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>{formatDate(o.createdAt)}</span></Td>
                  <Td><strong>{formatMoney(o.totalPrice)}</strong></Td>
                  <Td><Badge variant={statusColor(o.status)}>{statusLabel(o.status)}</Badge></Td>
                </Tr>
              ))
            ) : (
              <Tr><Td colSpan={7} style={{ textAlign: 'center', padding: '40px', color: 'var(--text-muted)' }}>لا توجد طلبات نشطة في الوقت الحالي.</Td></Tr>
            )}
          </Tbody>
        </Table>
      </Card>
    </div>
  );
}
