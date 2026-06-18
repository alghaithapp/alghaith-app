import type { AdminAccountKind } from '../admin-types';
import { MERCHANT_REJECTION_REASONS, COURIER_REJECTION_REASONS } from '../admin-types';
import { AlertTriangle, XCircle, LoaderCircle } from 'lucide-react';

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

export default function RejectModal({
  target,
  rejectMessage,
  isBusy,
  onMessageChange,
  onConfirm,
  onClose,
}: RejectModalProps) {
  if (!target) return null;

  return (
    <div
      className="modal-backdrop"
      role="presentation"
      onClick={onClose}
    >
      <div
        className="modal-card"
        role="dialog"
        aria-modal="true"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="panel-header">
          <div>
            <h3>رفض طلب التسجيل</h3>
            <p>
              اكتب سبب الرفض لحساب{' '}
              <strong>{target.displayName || target.phone}</strong>{' '}
              ({accountKindLabel(target.kind)}). سيظهر السبب للمستخدم في
              التطبيق ليتمكن من تصحيح بياناته.
            </p>
          </div>
        </div>

        <label className="reject-message-field">
          <span>سبب الرفض</span>
          <textarea
            rows={4}
            value={rejectMessage}
            onChange={(event) => onMessageChange(event.target.value)}
            placeholder="اكتب سبب الرفض..."
          />
        </label>

        <div className="reject-quick-fill">
          {(target.kind === 'merchant'
            ? MERCHANT_REJECTION_REASONS
            : target.kind === 'courier'
              ? COURIER_REJECTION_REASONS
              : []
          ).map((reason) => (
            <button
              key={reason.key}
              type="button"
              className="account-filter-chip"
              onClick={() => onMessageChange(reason.label)}
            >
              {reason.label}
            </button>
          ))}
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
            disabled={!rejectMessage.trim() || isBusy}
            onClick={onConfirm}
          >
            {isBusy ? (
              <LoaderCircle className="spin" size={16} />
            ) : (
              <XCircle size={16} />
            )}
            <span>حفظ وإرسال سبب الرفض</span>
          </button>
        </div>
      </div>
    </div>
  );
}
