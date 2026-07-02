import { AlertTriangle, BadgeCheck, LoaderCircle, Package2, Trash2, XCircle } from 'lucide-react';
import type { MerchantSummary } from '../admin-types';
import { Card } from './ui/Card';
import { Badge } from './ui/Badge';
import { Button } from './ui/Button';

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

function MiniStat({ label, value, hint }: { label: string; value: string | number; hint?: string }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', padding: '8px', background: 'var(--surface-elevated)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border)' }}>
      <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{label}</span>
      <strong style={{ fontSize: '1rem', color: 'var(--text-primary)' }}>{value}</strong>
      {hint && <em style={{ fontSize: '0.7rem', color: 'var(--text-secondary)', fontStyle: 'normal' }}>{hint}</em>}
    </div>
  );
}

export default function MerchantCard({
  merchant: m, isSelected, isPending, isRejected, freezeLoading, bazaarLoading, syncLoading,
  approvalLoading, rejectLoading, onSelect, onApprove, onReject, onFreeze, onBazaar, onSync, onDelete,
  formatMoney, serviceLabel, canRequestBazaar,
}: MerchantCardProps) {
  const isProfessional = m.isProfessional || m.primaryServiceId === 'professionals';
  
  return (
    <Card 
      padding="sm" 
      onClick={onSelect}
      style={{ 
        cursor: 'pointer', 
        borderColor: isSelected ? 'var(--brand-primary)' : 'var(--border-strong)',
        boxShadow: isSelected ? '0 0 0 1px var(--brand-primary)' : 'var(--shadow-sm)'
      }}
    >
      <div style={{ display: 'flex', flexDirection: 'column', flex: 1 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '4px' }}>
            <h4 style={{ margin: 0, fontSize: '1.1rem', color: 'var(--text-primary)' }}>
              {m.storeName || (isProfessional ? 'مهني بدون اسم' : 'متجر بدون اسم')}
            </h4>
            {isProfessional && <Badge variant="neutral">مهني</Badge>}
            {m.isApproved ? (
              <Badge variant="success">مفعّل</Badge>
            ) : isRejected ? (
              <Badge variant="error">مرفوض</Badge>
            ) : (
              <Badge variant="warning">بانتظار الموافقة</Badge>
            )}
            {m.isFrozen ? (
              <Badge variant="error">مجمّد</Badge>
            ) : !m.isOpen ? (
              <Badge variant="error">مغلق</Badge>
            ) : m.isBazaarMember ? (
              <Badge variant="info">بازار</Badge>
            ) : null}
          </div>
          
          <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
            المسؤول: {m.fullName || '—'} · <span dir="ltr">{m.phone}</span>
          </p>
          <p style={{ margin: '4px 0 0', color: 'var(--text-muted)', fontSize: '0.8rem' }}>
            القسم: {serviceLabel(m.primaryServiceId)} · الانضمام: {new Date(m.createdAt).toLocaleDateString('ar-IQ')}
          </p>
          
          {isRejected && m.rejectionReason && (
            <p style={{ margin: '8px 0 0', color: 'var(--error)', fontSize: '0.85rem', padding: '6px', background: 'var(--error-bg)', borderRadius: '6px' }}>
              سبب الرفض: {m.rejectionReason}
            </p>
          )}
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(100px, 1fr))', gap: '8px', marginTop: 'auto' }}>
        <MiniStat label="المبيعات الكلية" value={`${formatMoney(m.totalRevenue)} د.ع`} />
        <MiniStat label="أرباح التطبيق" value={`${formatMoney(m.totalAppProfit)} د.ع`} />
        <MiniStat label="الطلبات" value={m.totalOrders} hint={`تقييم: ${m.rating ? m.rating.toFixed(1) : '—'} ⭐`} />
      </div>
      </div>

      {isSelected && (
        <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginTop: '16px', paddingTop: '16px', borderTop: '1px solid var(--border)' }}>
          {isPending || isRejected ? (
            <>
              <Button variant="primary" onClick={(e) => { e.stopPropagation(); onApprove(); }} isLoading={approvalLoading} icon={<BadgeCheck size={16}/>}>
                قبول وتفعيل
              </Button>
              {!isRejected && (
                <Button variant="secondary" onClick={(e) => { e.stopPropagation(); onReject(); }} isLoading={rejectLoading} icon={<XCircle size={16}/>}>
                  رفض الطلب
                </Button>
              )}
            </>
          ) : (
            <>
              <Button variant="secondary" onClick={(e) => { e.stopPropagation(); onFreeze(); }} isLoading={freezeLoading} icon={<AlertTriangle size={16}/>}>
                {m.isFrozen ? 'إلغاء التجميد' : 'تجميد الحساب'}
              </Button>
              {canRequestBazaar && (
                <Button variant="secondary" onClick={(e) => { e.stopPropagation(); onBazaar(); }} isLoading={bazaarLoading} icon={<Package2 size={16}/>}>
                  {m.isBazaarMember ? 'إزالة من البازار' : 'إضافة للبازار'}
                </Button>
              )}
              {m.isBazaarMember && (
                <Button variant="secondary" onClick={(e) => { e.stopPropagation(); onSync(); }} isLoading={syncLoading} icon={<LoaderCircle size={16}/>}>
                  تحديث منتجات البازار
                </Button>
              )}
            </>
          )}
          <Button variant="danger" onClick={(e) => { e.stopPropagation(); onDelete(); }} icon={<Trash2 size={16}/>} style={{ marginInlineStart: 'auto' }}>
            حذف نهائي
          </Button>
        </div>
      )}
    </Card>
  );
}
