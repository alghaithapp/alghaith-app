import { useEffect, useState } from 'react';
import { Bike, LoaderCircle, UserPlus } from 'lucide-react';
import type { CourierPreRegisterPayload } from '../admin-types';

interface PreRegisterCourierModalProps {
  open: boolean;
  isBusy: boolean;
  onClose: () => void;
  onSubmit: (payload: CourierPreRegisterPayload) => Promise<void>;
}

export default function PreRegisterCourierModal({
  open,
  isBusy,
  onClose,
  onSubmit,
}: PreRegisterCourierModalProps) {
  const [phone, setPhone] = useState('');
  const [fullName, setFullName] = useState('');
  const [note, setNote] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    if (!open) return;
    setPhone('');
    setFullName('');
    setNote('');
    setError('');
  }, [open]);

  async function handleSubmit() {
    const trimmedPhone = phone.trim();
    const trimmedName = fullName.trim();
    if (!trimmedPhone) {
      setError('رقم الهاتف مطلوب.');
      return;
    }
    if (!trimmedName) {
      setError('اسم المندوب مطلوب.');
      return;
    }
    setError('');
    await onSubmit({
      courierPhone: trimmedPhone,
      fullName: trimmedName,
      note: note.trim() || undefined,
    });
  }

  if (!open) return null;

  return (
    <div className="modal-backdrop" role="presentation" onClick={onClose}>
      <div
        className="modal-card"
        role="dialog"
        aria-modal="true"
        onClick={(event) => event.stopPropagation()}
        style={{ maxWidth: 560 }}
      >
        <div className="panel-header">
          <div>
            <h3>تسجيل مندوب توصيل برقم</h3>
            <p>
              أضف المندوب مسبقاً بالاسم والرقم. عند تسجيل الدخول سيجد حسابه جاهزاً—
              يكمل فقط رفع صور الدراجة والمستندات.
            </p>
          </div>
        </div>

        {error ? (
          <div className="delete-warning-box" style={{ marginBottom: 16, color: 'var(--error-text)' }}>
            <span>{error}</span>
          </div>
        ) : null}

        <label className="reject-message-field">
          <span>رقم الهاتف <span style={{ color: 'var(--error-text)' }}>*</span></span>
          <input
            type="tel"
            value={phone}
            onChange={(event) => setPhone(event.target.value)}
            placeholder="مثال: 07701234567"
            dir="ltr"
            disabled={isBusy}
          />
        </label>

        <label className="reject-message-field">
          <span>الاسم الكامل <span style={{ color: 'var(--error-text)' }}>*</span></span>
          <input
            type="text"
            value={fullName}
            onChange={(event) => setFullName(event.target.value)}
            placeholder="اسم المندوب كما سيظهر في التطبيق"
            disabled={isBusy}
          />
        </label>

        <label className="reject-message-field">
          <span>ملاحظة داخلية (اختياري)</span>
          <textarea
            rows={3}
            value={note}
            onChange={(event) => setNote(event.target.value)}
            placeholder="ملاحظة للإدارة فقط"
            disabled={isBusy}
          />
        </label>

        <div className="modal-actions">
          <button className="ghost-button" type="button" onClick={onClose} disabled={isBusy}>
            إلغاء
          </button>
          <button
            className="primary-button"
            type="button"
            onClick={() => void handleSubmit()}
            disabled={isBusy}
          >
            {isBusy ? (
              <>
                <LoaderCircle size={16} className="spin" />
                جارٍ التسجيل...
              </>
            ) : (
              <>
                <UserPlus size={16} />
                تسجيل المندوب
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
