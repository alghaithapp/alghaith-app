import {
  AlertTriangle,
  BadgeCheck,
  LoaderCircle,
  Package2,
  Trash2,
  XCircle,
} from 'lucide-react';
import type { MerchantSummary } from '../admin-types';

interface MerchantCardProps {
  merchant: MerchantSummary;
  isSelected: boolean;
  isPending: boolean;
  isRejected: boolean;
  freezeLoading: boolean;
  bazaarLoading: boolean;
  syncLoading: boolean;
  approvalLoading: boolean;
  rejectLoading: boolean;
  onSelect: () => void;
  onApprove: () => void;
  onReject: () => void;
  onFreeze: () => void;
  onBazaar: () => void;
  onSync: () => void;
  onDelete: () => void;
  formatMoney: (value: number) => string;
  serviceLabel: (id: string) => string;
  canRequestBazaar: boolean;
}

function MiniStat({
  label,
  value,
  hint,
}: {
  label: string;
  value: string | number;
  hint?: string;
}) {
  return (
    <div className="mini-stat">
      <span>{label}</span>
      <strong>{value}</strong>
      {hint ? <em>{hint}</em> : null}
    </div>
  );
}

export default function MerchantCard({
  merchant: m,
  isSelected,
  isPending,
  isRejected,
  freezeLoading,
  bazaarLoading,
  syncLoading,
  approvalLoading,
  rejectLoading,
  onSelect,
  onApprove,
  onReject,
  onFreeze,
  onBazaar,
  onSync,
  onDelete,
  formatMoney,
  serviceLabel,
  canRequestBazaar,
}: MerchantCardProps) {
  return (
    <article
      className={isSelected ? 'merchant-card selected' : 'merchant-card'}
      onClick={onSelect}
    >
      <div className="merchant-main">
        <div>
          <div className="merchant-title-row">
            <h4>
              {m.storeName ||
                (m.isProfessional || m.primaryServiceId === 'professionals'
                  ? 'مهني بدون اسم'
                  : 'متجر بدون اسم')}
            </h4>
            {m.isProfessional || m.primaryServiceId === 'professionals' ? (
              <span className="status-badge muted">مهني</span>
            ) : null}
            {m.isApproved ? (
              <span className="status-badge success">مفعّل</span>
            ) : isRejected ? (
              <span className="status-badge danger">مرفوض</span>
            ) : (
              <span className="status-badge warning">بانتظار الموافقة</span>
            )}
            {m.isFrozen ? (
              <span className="status-badge danger">مجمّد</span>
            ) : !m.isOpen ? (
              <span className="status-badge danger">المتجر مغلق</span>
            ) : m.isBazaarMember ? (
              <span className="status-badge success">مفعل في البازار</span>
            ) : (
              <span className="status-badge muted">بانتظار/خارج البازار</span>
            )}
            {m.isBazaarMember ? (
              m.visibleToCustomers ? (
                <span className="status-badge success">
                  ظاهر للزبائن ({m.visibleProductCount})
                </span>
              ) : (
                <span className="status-badge danger">غير ظاهر للزبائن</span>
              )
            ) : null}
          </div>
          <p className="merchant-meta">
            {m.fullName || 'بدون اسم مالك'} · {serviceLabel(m.primaryServiceId)} ·{' '}
            <span dir="ltr">{m.phone}</span>
          </p>
          <p className="merchant-description">
            {m.description || 'لا يوجد وصف محفوظ.'}
          </p>
          {isRejected && m.rejectionMessageAr ? (
            <p className="courier-rejection-note">
              سبب الرفض: {m.rejectionMessageAr}
            </p>
          ) : null}
          {m.isBazaarMember && !m.visibleToCustomers && m.visibilityNotes?.length ? (
            <p className="merchant-visibility-note">
              سبب عدم الظهور: {m.visibilityNotes.join(' · ')}
            </p>
          ) : null}
        </div>
        <div className="merchant-stats-inline">
          <MiniStat
            label="المنتجات"
            value={m.totalProducts ?? 0}
            hint={
              m.availableProducts !== m.totalProducts
                ? `${m.availableProducts ?? 0} متاح`
                : undefined
            }
          />
          <MiniStat label="الطلبات" value={m.totalOrders} />
          <MiniStat label="المكتمل" value={m.completedOrders} />
          <MiniStat label="الأرباح" value={`${formatMoney(m.totalRevenue)} د.ع`} />
        </div>
      </div>
      <div className="merchant-actions">
        <button
          className={m.isApproved ? 'soft-button danger' : 'soft-button success'}
          disabled={approvalLoading || rejectLoading}
          onClick={(event) => {
            event.stopPropagation();
            onApprove();
          }}
        >
          {approvalLoading ? (
            <LoaderCircle className="spin" size={16} />
          ) : (
            <BadgeCheck size={16} />
          )}
          <span>
            {m.isApproved ? 'إلغاء تفعيل الحساب' : 'موافقة وتفعيل'}
          </span>
        </button>
        {isPending || isRejected ? (
          <button
            className="soft-button danger"
            disabled={approvalLoading || rejectLoading}
            onClick={(event) => {
              event.stopPropagation();
              onReject();
            }}
          >
            {rejectLoading ? (
              <LoaderCircle className="spin" size={16} />
            ) : (
              <XCircle size={16} />
            )}
            <span>رفض الطلب</span>
          </button>
        ) : null}
        <button
          className={m.isFrozen ? 'soft-button' : 'soft-button danger'}
          disabled={freezeLoading}
          onClick={(event) => {
            event.stopPropagation();
            onFreeze();
          }}
        >
          {freezeLoading ? (
            <LoaderCircle className="spin" size={16} />
          ) : (
            <AlertTriangle size={16} />
          )}
          <span>{m.isFrozen ? 'فك التجميد' : 'تجميد التاجر'}</span>
        </button>
        {canRequestBazaar ? (
          <button
            className={m.isBazaarMember ? 'soft-button' : 'soft-button success'}
            disabled={bazaarLoading}
            onClick={(event) => {
              event.stopPropagation();
              onBazaar();
            }}
          >
            {bazaarLoading ? (
              <LoaderCircle className="spin" size={16} />
            ) : (
              <BadgeCheck size={16} />
            )}
            <span>
              {m.isBazaarMember ? 'سحب الموافقة' : 'موافقة على البازار'}
            </span>
          </button>
        ) : (
          <span className="status-badge muted">لا ينطبق على هذا القسم</span>
        )}
        {m.isBazaarMember && !m.visibleToCustomers ? (
          <button
            className="soft-button success"
            disabled={syncLoading}
            onClick={(event) => {
              event.stopPropagation();
              onSync();
            }}
          >
            {syncLoading ? (
              <LoaderCircle className="spin" size={16} />
            ) : (
              <Package2 size={16} />
            )}
            <span>إصلاح الظهور في البازار</span>
          </button>
        ) : null}
        <button
          className="soft-button danger"
          disabled={approvalLoading || rejectLoading || freezeLoading}
          onClick={(event) => {
            event.stopPropagation();
            onDelete();
          }}
        >
          <Trash2 size={16} />
          <span>حذف الحساب</span>
        </button>
      </div>
    </article>
  );
}
