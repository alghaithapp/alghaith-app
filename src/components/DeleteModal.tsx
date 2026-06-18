import type { AdminAccountSummary, AdminAccountKind } from '../admin-types';
import { AlertTriangle, Trash2, LoaderCircle } from 'lucide-react';

interface DeleteModalProps {
  target: AdminAccountSummary | null;
  isBusy: boolean;
  onConfirm: () => void;
  onClose: () => void;
}

function accountKindLabel(kind: AdminAccountKind) {
  switch (kind) {
    case 'customer':
      return 'زبون';
    case 'merchant':
      return 'تاجر / مهني';
    case 'courier':
      return 'مندوب توصيل';
    case 'driver':
      return 'سائق تكسي';
    case 'admin':
      return 'مشرف';
    default:
      return kind;
  }
}

export default function DeleteModal({
  target,
  isBusy,
  onConfirm,
  onClose,
}: DeleteModalProps) {
  if (!target) return null;

  return (
    <div
      className="modal-backdrop"
      role="presentation"
      onClick={onClose}
    >
      <div
        className="modal-card danger-modal"
        role="dialog"
        aria-modal="true"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="panel-header">
          <div>
            <h3>تأكيد حذف الحساب</h3>
            <p>
              هل أنت متأكد من حذف حساب{' '}
              <strong>{target.displayName || target.phone}</strong>؟
              <br />
              النوع: {accountKindLabel(target.kind)} ·{' '}
              <span dir="ltr">{target.phone}</span>
            </p>
          </div>
        </div>

        <div className="delete-warning-box">
          <AlertTriangle size={20} />
          <p>
            هذا الإجراء نهائي. سيتم حذف بيانات الحساب وملفه من النظام ولا يمكن
            التراجع عنه بسهولة.
          </p>
        </div>

        <div className="modal-actions">
          <button
            className="ghost-button"
            type="button"
            onClick={onClose}
          >
            إلغاء
          </button>
          <button
            className="soft-button danger"
            type="button"
            disabled={isBusy}
            onClick={onConfirm}
          >
            {isBusy ? (
              <LoaderCircle className="spin" size={16} />
            ) : (
              <Trash2 size={16} />
            )}
            <span>نعم، احذف الحساب نهائياً</span>
          </button>
        </div>
      </div>
    </div>
  );
}
