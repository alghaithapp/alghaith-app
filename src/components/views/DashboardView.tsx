import React, { ReactNode } from 'react';
import {
  ShoppingBag,
  Store,
  Users,
  BarChart3,
  BadgeCheck,
  Bike,
  Store as StoreIcon,
  Snowflake,
} from 'lucide-react';
import type { AdminReports, MerchantSummary, CourierSummary } from '../../admin-types';

interface DashboardViewProps {
  reports: AdminReports | null;
  pendingMerchantQueue: MerchantSummary[];
  pendingCourierQueue: CourierSummary[];
  approvalQueue: MerchantSummary[];
  frozenMerchants: number;
  onSwitchView: (view: string) => void;
  onSetMerchantFilter: (filter: string) => void;
  formatMoney: (value: number) => string;
  formatDate: (value: string | null | undefined) => string;
}

function MetricCard({
  icon,
  title,
  value,
  hint,
}: {
  icon: ReactNode;
  title: string;
  value: string;
  hint: string;
}) {
  return (
    <article className="metric-card">
      <div className="metric-icon">{icon}</div>
      <div>
        <p>{title}</p>
        <strong>{value}</strong>
        <span>{hint}</span>
      </div>
    </article>
  );
}

export default function DashboardView({
  reports,
  pendingMerchantQueue,
  pendingCourierQueue,
  approvalQueue,
  frozenMerchants,
  onSwitchView,
  onSetMerchantFilter,
  formatMoney,
  formatDate,
}: DashboardViewProps) {
  return (
    <>
      <section className="metrics-grid">
        <MetricCard
          icon={<ShoppingBag size={18} />}
          title="إجمالي الطلبات"
          value={String(reports?.totalOrders || 0)}
          hint={`${reports?.completedOrders || 0} مكتمل`}
        />
        <MetricCard
          icon={<Store size={18} />}
          title="التجار النشطون"
          value={String(reports?.openMerchants || 0)}
          hint={`${reports?.totalMerchants || 0} إجمالي`}
        />
        <MetricCard
          icon={<Users size={18} />}
          title="إجمالي المستخدمين"
          value={String(reports?.totalUsers || 0)}
          hint={`${reports?.totalProducts || 0} منتج`}
        />
        <MetricCard
          icon={<BarChart3 size={18} />}
          title="إجمالي المبيعات"
          value={`${formatMoney(reports?.totalSales || 0)} د.ع`}
          hint={`${formatMoney(reports?.codCollected || 0)} COD`}
        />
      </section>

      <section className="quick-actions-grid">
        <article className="quick-action-card">
          <p>طلبات موافقة البازار</p>
          <strong>{approvalQueue.length}</strong>
          <button
            className="soft-button"
            type="button"
            onClick={() => onSwitchView('approvals')}
          >
            <BadgeCheck size={16} />
            <span>مراجعة طلبات البازار</span>
          </button>
        </article>
        <article className="quick-action-card">
          <p>مندوبون بانتظار الموافقة</p>
          <strong>{pendingCourierQueue.length}</strong>
          <button
            className="soft-button"
            type="button"
            onClick={() => onSwitchView('couriers')}
          >
            <Bike size={16} />
            <span>مراجعة المندوبين</span>
          </button>
        </article>
        <article className="quick-action-card">
          <p>تجار بانتظار الموافقة</p>
          <strong>{pendingMerchantQueue.length}</strong>
          <button
            className="soft-button"
            type="button"
            onClick={() => {
              onSetMerchantFilter('pending');
              onSwitchView('merchants');
            }}
          >
            <StoreIcon size={16} />
            <span>مراجعة التجار والمهنيين</span>
          </button>
        </article>
        <article className="quick-action-card">
          <p>تجار مجمّدون</p>
          <strong>{frozenMerchants}</strong>
          <button
            className="soft-button"
            type="button"
            onClick={() => onSwitchView('merchants')}
          >
            <Snowflake size={16} />
            <span>إدارة التجار</span>
          </button>
        </article>
      </section>

      <section className="panel recent-orders-panel">
        <div className="panel-header">
          <div>
            <h3>آخر طلبات المنصة</h3>
            <p>لمتابعة حركة الطلبات العامة داخل التطبيق.</p>
          </div>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>رقم الطلب</th>
                <th>المتجر</th>
                <th>العميل</th>
                <th>الحالة</th>
                <th>القيمة</th>
                <th>آخر تحديث</th>
              </tr>
            </thead>
            <tbody>
              {(reports?.recentOrders || []).map((order) => (
                <tr key={order.id}>
                  <td>{order.orderNumber || order.id}</td>
                  <td>{order.merchantStoreName || 'غير معروف'}</td>
                  <td>{order.customerNameAr || 'غير معروف'}</td>
                  <td>{order.statusAr || order.statusKey}</td>
                  <td>{formatMoney(order.price)} د.ع</td>
                  <td>{formatDate(order.updatedAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}
