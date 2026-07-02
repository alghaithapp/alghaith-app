import type { AdminAccountSummary, AdminAccountKind } from '../admin-types';
import { AlertTriangle, Trash2 } from 'lucide-react';
import { Modal } from './ui/Modal';
import { Button } from './ui/Button';

interface DeleteModalProps {
  target: AdminAccountSummary | null;
  isBusy: boolean;
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

export default function DeleteModal({
  target,
  isBusy,
  onConfirm,
  onClose,
}: DeleteModalProps) {
  return (
    <Modal isOpen={!!target} onClose={onClose} title="تأكيد حذف الحساب">
      {target && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          <div>
            <p style={{ margin: '0 0 8px', color: 'var(--text-secondary)' }}>
              هل أنت متأكد من حذف حساب{' '}
              <strong style={{ color: 'var(--text-primary)' }}>{target.displayName || target.phone}</strong>؟
              <br />
              النوع: {accountKindLabel(target.kind)} ·{' '}
              <span dir="ltr" style={{ color: 'var(--text-primary)' }}>{target.phone}</span>
            </p>
          </div>

          <div style={{
            display: 'flex', gap: '12px', padding: '16px',
            background: 'var(--error-bg)', color: 'var(--error)',
            borderRadius: 'var(--radius-md)', border: '1px solid var(--error-border)'
          }}>
            <AlertTriangle size={24} style={{ flexShrink: 0 }} />
            <p style={{ margin: 0, fontSize: '0.9rem', lineHeight: 1.5 }}>
              هذا الإجراء نهائي. سيتم حذف بيانات الحساب وملفه من النظام ولا يمكن
              التراجع عنه بسهولة.
            </p>
          </div>

          <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end', marginTop: '8px' }}>
            <Button variant="secondary" onClick={onClose} disabled={isBusy}>
              إلغاء
            </Button>
            <Button
              variant="danger"
              icon={<Trash2 size={16} />}
              onClick={onConfirm}
              isLoading={isBusy}
            >
              نعم، احذف الحساب نهائياً
            </Button>
          </div>
        </div>
      )}
    </Modal>
  );
}
