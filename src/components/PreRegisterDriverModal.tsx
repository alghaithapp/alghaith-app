import { useEffect, useState } from 'react';
import { LoaderCircle, UserPlus } from 'lucide-react';
import type { DriverPreRegisterPayload } from '../admin-types';

interface PreRegisterDriverModalProps {
  open: boolean;
  isBusy: boolean;
  onClose: () => void;
  onSubmit: (payload: DriverPreRegisterPayload) => Promise<void>;
}

export default function PreRegisterDriverModal({
  open,
  isBusy,
  onClose,
  onSubmit,
}: PreRegisterDriverModalProps) {
  const [phone, setPhone] = useState('');
  const [fullName, setFullName] = useState('');
  const [note, setNote] = useState('');

  useEffect(() => {
    if (!open) return;
    setPhone('');
    setFullName('');
    setNote('');
  }, [open]);

  async function handleSubmit() {
    const driverPhone = phone.trim();
    const name = fullName.trim();
    if (!driverPhone) {
      window.alert('يرجى إدخال رقم هاتف السائق.');
      return;
    }
    if (!name) {
      window.alert('يرجى إدخال اسم السائق.');
      return;
    }

    await onSubmit({
      driverPhone,
      fullName: name,
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
            <h3>تسجيل سائق تكسي برقم هاتف</h3>
            <p>
              أضف السائق مسبقاً بالاسم والرقم حتى لو كان نفس الرقم مسجّلاً كزبون أو
              تاجر. يُفعَّل ملف السائق ويبقى الدور الحالي كما هو — يبدّل السائق إلى
              «تكسي» من التطبيق عند الحاجة.
            </p>
          </div>
        </div>

        <label className="reject-message-field">
          <span>رقم هاتف السائق *</span>
          <input
            type="tel"
            value={phone}
            onChange={(event) => setPhone(event.target.value)}
            placeholder="مثال: 07808168620"
            dir="ltr"
          />
        </label>

        <label className="reject-message-field">
          <span>اسم السائق *</span>
          <input
            type="text"
            value={fullName}
            onChange={(event) => setFullName(event.target.value)}
            placeholder="الاسم الثلاثي كما سيظهر في التطبيق"
          />
        </label>

        <label className="reject-message-field">
          <span>ملاحظة داخلية (اختياري)</span>
          <textarea
            rows={3}
            value={note}
            onChange={(event) => setNote(event.target.value)}
            placeholder="ملاحظة للإدارة فقط"
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
                تسجيل السائق
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
