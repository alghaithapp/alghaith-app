import { LoaderCircle, Building2 } from 'lucide-react';
import type { MerchantDetails } from '../../admin-types';

interface MerchantDetailPanelProps {
  merchantDetails: MerchantDetails | null;
  isLoadingDetails: boolean;
  selectedMerchantPhone: string;
  formatMoney: (value: number) => string;
  formatDate: (value: string | null | undefined) => string;
}

function serviceLabel(serviceId: string) {
  switch (serviceId) {
    case 'restaurant':
      return 'مطعم';
    case 'product':
      return 'متجر';
    case 'real_estate':
      return 'عقار';
    case 'professionals':
      return 'مهني';
    default:
      return serviceId || 'غير محدد';
  }
}

function DetailStat({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="detail-stat">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function MetaRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="meta-row">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

export default function MerchantDetailPanel({
  merchantDetails,
  isLoadingDetails,
  selectedMerchantPhone,
  formatMoney,
  formatDate,
}: MerchantDetailPanelProps) {
  return (
    <div className="panel details">
      <div className="panel-header">
        <div>
          <h3>تفاصيل التاجر</h3>
          <p>الأرباح، الطلبات الأخيرة، والمنتجات الحالية.</p>
        </div>
        {merchantDetails?.merchant.isFrozen ? (
          <span className="panel-chip danger">الحساب مجمّد</span>
        ) : null}
      </div>

      {isLoadingDetails ? (
        <div className="loading-state compact">
          <LoaderCircle className="spin" size={22} />
          <span>جار تحميل تفاصيل التاجر...</span>
        </div>
      ) : merchantDetails ? (
        <>
          <div className="detail-hero">
            <div>
              <p className="eyebrow">ملخص التاجر</p>
              <h3>{merchantDetails.merchant.storeName || 'متجر بدون اسم'}</h3>
              <p className="merchant-meta">
                {merchantDetails.merchant.fullName || 'بدون اسم مالك'} ·{' '}
                {serviceLabel(merchantDetails.merchant.primaryServiceId)}
              </p>
            </div>
            <div className="hero-badges">
              <span className="status-badge success">
                {merchantDetails.merchant.isBazaarMember
                  ? 'مصرح له في البازار'
                  : 'غير مصرح له في البازار'}
              </span>
              <span className="status-badge muted" dir="ltr">
                {merchantDetails.merchant.phone}
              </span>
            </div>
          </div>

          <div className="detail-stats-grid">
            <DetailStat
              label="إجمالي الأرباح"
              value={`${formatMoney(merchantDetails.stats.totalRevenue)} د.ع`}
            />
            <DetailStat
              label="الطلبات الكلية"
              value={merchantDetails.stats.totalOrders}
            />
            <DetailStat
              label="متوسط الطلب"
              value={`${formatMoney(
                merchantDetails.stats.averageOrderValue,
              )} د.ع`}
            />
            <DetailStat
              label="عدد المنتجات"
              value={merchantDetails.stats.totalProducts}
            />
          </div>

          <div className="detail-meta-list">
            <MetaRow
              label="العنوان"
              value={merchantDetails.merchant.address || 'غير محفوظ'}
            />
            <MetaRow
              label="رسوم التوصيل"
              value={`${formatMoney(merchantDetails.merchant.deliveryFee)} د.ع`}
            />
            <MetaRow
              label="تاريخ الانضمام"
              value={formatDate(merchantDetails.merchant.createdAt)}
            />
            <MetaRow
              label="آخر تحديث"
              value={formatDate(merchantDetails.merchant.updatedAt)}
            />
          </div>

          <div className="subpanel">
            <h4>الطلبات الأخيرة</h4>
            <div className="order-list">
              {merchantDetails.recentOrders.map((order) => (
                <article key={order.id} className="order-row">
                  <div>
                    <strong>{order.orderNumber}</strong>
                    <p>
                      {order.customerName || 'عميل غير معروف'} ·{' '}
                      {order.statusAr || order.statusKey}
                    </p>
                  </div>
                  <div className="order-row-meta">
                    <span>{formatMoney(order.price)} د.ع</span>
                    <small>{formatDate(order.updatedAt)}</small>
                  </div>
                </article>
              ))}
            </div>
          </div>

          <div className="subpanel">
            <h4>منتجات مختصرة</h4>
            <div className="product-list">
              {merchantDetails.products.map((product) => (
                <article key={product.id} className="product-row">
                  <div>
                    <strong>{product.name || 'منتج بدون اسم'}</strong>
                    <p>
                      {serviceLabel(product.category)} ·{' '}
                      {product.subCategory || 'بدون تصنيف'}
                    </p>
                  </div>
                  <div className="order-row-meta">
                    <span>{formatMoney(product.price)} د.ع</span>
                    <small>
                      {product.isAvailable ? 'متاح' : 'غير متاح'}
                    </small>
                  </div>
                </article>
              ))}
            </div>
          </div>
        </>
      ) : (
        <div className="empty-state">
          <Building2 size={22} />
          <p>اختر تاجراً من القائمة لعرض أرباحه وطلباته وتفاصيله.</p>
        </div>
      )}
    </div>
  );
}
