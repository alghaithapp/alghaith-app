import React, { ReactNode } from 'react';
import {
  ShoppingBag,
  Store,
  Users,
  TrendingUp,
  BadgeCheck,
  Bike,
  Snowflake,
  Car,
  ArrowUpRight,
  Clock,
  CheckCircle2,
  AlertCircle,
} from 'lucide-react';
import type { AdminReports, MerchantSummary, CourierSummary } from '../../admin-types';

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
  onSwitchView: (view: string) => void;
  onSetMerchantFilter: (filter: string) => void;
  formatMoney: (value: number) => string;
  formatDate: (value: string | null | undefined) => string;
}

function MetricCard({
  icon,
  iconClass,
  title,
  value,
  hint,
}: {
  icon: ReactNode;
  iconClass: string;
  title: string;
  value: string;
  hint: string;
}) {
  return (
    <article className="metric-card">
      <div className={`metric-icon ${iconClass}`}>{icon}</div>
      <div>
        <p>{title}</p>
        <strong>{value}</strong>
        <span>{hint}</span>
      </div>
    </article>
  );
}

function QuickActionCard({
  icon,
  iconColor,
  label,
  count,
  buttonLabel,
  buttonClass,
  onClick,
}: {
  icon: ReactNode;
  iconColor: string;
  label: string;
  count: number;
  buttonLabel: string;
  buttonClass?: string;
  onClick: () => void;
}) {
  return (
    <article className="quick-action-card">
      <p>{label}</p>
      <strong style={{ color: count > 0 ? 'var(--warning)' : 'var(--text-primary)' }}>
        {count}
      </strong>
      <button
        className={`soft-button ${buttonClass || ''}`}
        type="button"
        onClick={onClick}
        style={{ gap: '6px' }}
      >
        <span style={{ color: iconColor }}>{icon}</span>
        <span>{buttonLabel}</span>
      </button>
    </article>
  );
}

function statusColor(statusKey: string) {
  if (statusKey.includes('complet') || statusKey === 'delivered') return 'var(--success)';
  if (statusKey.includes('cancel') || statusKey.includes('reject')) return 'var(--error)';
  if (statusKey.includes('deliver') || statusKey.includes('transit')) return 'var(--color-courier)';
  return 'var(--warning)';
}

export default function DashboardView({
  reports,
  pendingMerchantQueue,
  pendingCourierQueue,
  approvalQueue,
  frozenMerchants,
  pendingDriverCount,
  totalCustomers,
  totalMerchants,
  totalCouriers,
  totalDrivers,
  onSwitchView,
  onSetMerchantFilter,
  formatMoney,
  formatDate,
}: DashboardViewProps) {
  const totalPendingApprovals =
    pendingMerchantQueue.length + pendingCourierQueue.length + pendingDriverCount;

  return (
    <>
      {/* ── KPI Metrics ── */}
      <section className="metrics-grid">
        <MetricCard
          icon={<ShoppingBag size={20} />}
          iconClass="teal"
          title="إجمالي الطلبات"
          value={String(reports?.totalOrders || 0)}
          hint={`${reports?.completedOrders || 0} مكتمل · ${reports?.pendingOrders || 0} معلق`}
        />
        <MetricCard
          icon={<TrendingUp size={20} />}
          iconClass="amber"
          title="إجمالي المبيعات"
          value={`${formatMoney(reports?.totalSales || 0)} د.ع`}
          hint={`COD: ${formatMoney(reports?.codCollected || 0)} د.ع`}
        />
        <MetricCard
          icon={<Users size={20} />}
          iconClass="blue"
          title="إجمالي المستخدمين"
          value={String(reports?.totalUsers || 0)}
          hint={`${totalCustomers} زبون · ${totalMerchants} تاجر`}
        />
        <MetricCard
          icon={<Store size={20} />}
          iconClass="green"
          title="التجار النشطون"
          value={String(reports?.openMerchants || 0)}
          hint={`${reports?.totalMerchants || 0} إجمالي التجار`}
        />
      </section>

      {/* ── User Distribution ── */}
      <div className="user-distribution-bar">
        <span style={{ fontSize: '0.8rem', fontWeight: 700, color: 'var(--text-muted)', marginInlineEnd: 4 }}>
          توزيع المستخدمين:
        </span>
        <div className="dist-item">
          <span className="dist-dot customer" />
          <span className="dist-count">{totalCustomers}</span>
          <span className="dist-label">زبون</span>
        </div>
        <div className="dist-item">
          <span className="dist-dot merchant" />
          <span className="dist-count">{totalMerchants}</span>
          <span className="dist-label">تاجر / مهني</span>
        </div>
        <div className="dist-item">
          <span className="dist-dot courier" />
          <span className="dist-count">{totalCouriers}</span>
          <span className="dist-label">مندوب</span>
        </div>
        <div className="dist-item">
          <span className="dist-dot driver" />
          <span className="dist-count">{totalDrivers}</span>
          <span className="dist-label">سائق تكسي</span>
        </div>
        {totalPendingApprovals > 0 ? (
          <span
            className="status-badge warning"
            style={{ marginInlineStart: 'auto' }}
          >
            <AlertCircle size={13} />
            {totalPendingApprovals} طلب معلق
          </span>
        ) : (
          <span
            className="status-badge success"
            style={{ marginInlineStart: 'auto' }}
          >
            <CheckCircle2 size={13} />
            لا توجد طلبات معلقة
          </span>
        )}
      </div>

      {/* ── Quick Actions ── */}
      <section className="quick-actions-grid">
        <QuickActionCard
          icon={<BadgeCheck size={15} />}
          iconColor="var(--color-merchant)"
          label="تجار بانتظار الموافقة"
          count={pendingMerchantQueue.length}
          buttonLabel="مراجعة التجار"
          buttonClass={pendingMerchantQueue.length > 0 ? 'warning' : ''}
          onClick={() => {
            onSetMerchantFilter('pending');
            onSwitchView('merchants');
          }}
        />
        <QuickActionCard
          icon={<BadgeCheck size={15} />}
          iconColor="var(--color-merchant)"
          label="طلبات موافقة البازار"
          count={approvalQueue.length}
          buttonLabel="مراجعة البازار"
          buttonClass={approvalQueue.length > 0 ? 'warning' : ''}
          onClick={() => onSwitchView('approvals')}
        />
        <QuickActionCard
          icon={<Bike size={15} />}
          iconColor="var(--color-courier)"
          label="مندوبون بانتظار التفعيل"
          count={pendingCourierQueue.length}
          buttonLabel="مراجعة المندوبين"
          buttonClass={pendingCourierQueue.length > 0 ? 'warning' : ''}
          onClick={() => onSwitchView('couriers')}
        />
        <QuickActionCard
          icon={<Car size={15} />}
          iconColor="var(--color-driver)"
          label="سائقو تكسي بانتظار التفعيل"
          count={pendingDriverCount}
          buttonLabel="مراجعة السائقين"
          buttonClass={pendingDriverCount > 0 ? 'warning' : ''}
          onClick={() => onSwitchView('drivers')}
        />
        <QuickActionCard
          icon={<Snowflake size={15} />}
          iconColor="var(--info)"
          label="تجار مجمّدون"
          count={frozenMerchants}
          buttonLabel="إدارة التجار"
          buttonClass={frozenMerchants > 0 ? 'info' : ''}
          onClick={() => onSwitchView('merchants')}
        />
      </section>

      {/* ── Recent Orders ── */}
      <section className="panel recent-orders-panel">
        <div className="panel-header">
          <div>
            <h3>آخر طلبات المنصة</h3>
            <p>لمتابعة حركة الطلبات العامة داخل التطبيق.</p>
          </div>
          <span className="panel-chip">
            <Clock size={13} />
            {reports?.recentOrders?.length || 0} طلب
          </span>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>رقم الطلب</th>
                <th>المتجر</th>
                <th>الزبون</th>
                <th>حالة الطلب</th>
                <th>التوصيل</th>
                <th>القيمة</th>
                <th>آخر تحديث</th>
              </tr>
            </thead>
            <tbody>
              {(reports?.recentOrders || []).length === 0 ? (
                <tr>
                  <td colSpan={7} style={{ textAlign: 'center', color: 'var(--text-muted)', padding: '32px' }}>
                    لا توجد طلبات حديثة
                  </td>
                </tr>
              ) : (
                (reports?.recentOrders || []).map((order) => (
                  <tr key={order.id}>
                    <td style={{ fontFamily: 'monospace', fontSize: '0.82rem', color: 'var(--brand-primary)' }}>
                      #{order.orderNumber || order.id.slice(0, 8)}
                    </td>
                    <td style={{ fontWeight: 700, color: 'var(--text-primary)' }}>
                      {order.merchantStoreName || 'غير معروف'}
                    </td>
                    <td>{order.customerNameAr || 'غير معروف'}</td>
                    <td>
                      <span
                        className="status-badge"
                        style={{
                          background: `${statusColor(order.statusKey)}22`,
                          color: statusColor(order.statusKey),
                          border: `1px solid ${statusColor(order.statusKey)}44`,
                        }}
                      >
                        {order.statusAr || order.statusKey}
                      </span>
                    </td>
                    <td>
                      <span
                        className="status-badge muted"
                        style={{ fontSize: '0.74rem' }}
                      >
                        {order.deliveryStatusKey || '—'}
                      </span>
                    </td>
                    <td style={{ fontWeight: 800, color: 'var(--text-primary)' }}>
                      {formatMoney(order.price)} د.ع
                    </td>
                    <td style={{ color: 'var(--text-muted)', fontSize: '0.8rem' }}>
                      {formatDate(order.updatedAt)}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}
