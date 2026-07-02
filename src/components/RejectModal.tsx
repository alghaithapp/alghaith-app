import type { AdminAccountKind } from '../admin-types';
import { MERCHANT_REJECTION_REASONS, COURIER_REJECTION_REASONS } from '../admin-types';
import { XCircle } from 'lucide-react';
import { Modal } from './ui/Modal';
import { Button } from './ui/Button';

interface RejectModalProps {
  target: { phone: string; displayName: string; kind: AdminAccountKind } | null;
  rejectMessage: string;
  isBusy: boolean;
  onMessageChange: (msg: string) => void;
  onConfirm: () => void;
  onClose: () => void;
}

function accountKindLabel(kind: AdminAccountKind) {
  switch (kind) {
    case 'customer': return 'زبون';
    case 'merchant': return 'تاجر / مهني';
    case 'courier': return 'مندوب توصيل';
    case 'driver': return 'سائق تكسي';
    case 'admin': return 'مشرف';
    default: return kind;
  }
}

export default function RejectModal({
  target,
  rejectMessage,
  isBusy,
  onMessageChange,
  onConfirm,
  onClose,
}: RejectModalProps) {
  return (
    <Modal isOpen={!!target} onClose={onClose} title="رفض طلب التسجيل">
      {target && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <p style={{ margin: 0, color: 'var(--text-secondary)' }}>
            اكتب سبب الرفض لحساب{' '}
            <strong style={{ color: 'var(--text-primary)' }}>{target.displayName || target.phone}</strong>{' '}
            ({accountKindLabel(target.kind)}). سيظهر السبب للمستخدم في
            التطبيق ليتمكن من تصحيح بياناته.
          </p>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
            <label style={{ fontWeight: 700, fontSize: '0.9rem', color: 'var(--text-secondary)' }}>سبب الرفض</label>
            <textarea
              className="ui-input"
              rows={4}
              value={rejectMessage}
              onChange={(event) => onMessageChange(event.target.value)}
              placeholder="اكتب سبب الرفض..."
              style={{ resize: 'vertical', minHeight: '80px' }}
            />
          </div>

          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
            {(target.kind === 'merchant'
              ? MERCHANT_REJECTION_REASONS
              : target.kind === 'courier'
                ? COURIER_REJECTION_REASONS
                : []
            ).map((reason) => (
              <button
                key={reason.key}
                type="button"
                onClick={() => onMessageChange(reason.label)}
                style={{
                  background: 'var(--surface-elevated)',
                  border: '1px solid var(--border)',
                  color: 'var(--text-primary)',
                  padding: '6px 12px',
                  borderRadius: '999px',
                  fontSize: '0.8rem',
                  cursor: 'pointer',
                  transition: '0.2s',
                }}
                onMouseOver={(e) => (e.currentTarget.style.background = 'var(--surface-hover)')}
                onMouseOut={(e) => (e.currentTarget.style.background = 'var(--surface-elevated)')}
              >
                {reason.label}
              </button>
            ))}
          </div>

          <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end', marginTop: '8px' }}>
            <Button variant="secondary" onClick={onClose} disabled={isBusy}>
              إلغاء
            </Button>
            <Button
              variant="danger"
              icon={<XCircle size={16} />}
              onClick={onConfirm}
              isLoading={isBusy}
              disabled={!rejectMessage.trim()}
            >
              رفض الطلب
            </Button>
          </div>
        </div>
      )}
    </Modal>
  );
}
