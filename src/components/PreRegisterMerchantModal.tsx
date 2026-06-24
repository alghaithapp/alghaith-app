import { useEffect, useMemo, useState } from 'react';
import { LoaderCircle, UserPlus } from 'lucide-react';
import { MERCHANT_SIGNUP_CATEGORIES } from '../admin-types';
import type { MerchantPreRegisterPayload } from '../admin-types';

interface PreRegisterMerchantModalProps {
  open: boolean;
  isBusy: boolean;
  onClose: () => void;
  onSubmit: (payload: MerchantPreRegisterPayload) => Promise<void>;
}

export default function PreRegisterMerchantModal({
  open,
  isBusy,
  onClose,
  onSubmit,
}: PreRegisterMerchantModalProps) {
  const [phone, setPhone] = useState('');
  const [fullName, setFullName] = useState('');
  const [note, setNote] = useState('');
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  const [primaryServiceId, setPrimaryServiceId] = useState('');

  useEffect(() => {
    if (!open) return;
    setPhone('');
    setFullName('');
    setNote('');
    setSelectedIds([]);
    setPrimaryServiceId('');
  }, [open]);

  const selectedCategories = useMemo(
    () => MERCHANT_SIGNUP_CATEGORIES.filter((item) => selectedIds.includes(item.id)),
    [selectedIds],
  );

  function toggleCategory(id: string) {
    setSelectedIds((current) => {
      if (current.includes(id)) {
        const next = current.filter((item) => item !== id);
        if (primaryServiceId === id) {
          setPrimaryServiceId(next[0] ?? '');
        }
        return next;
      }
      const next = [...current, id];
      if (!primaryServiceId) {
        setPrimaryServiceId(id);
      }
      return next;
    });
  }

  async function handleSubmit() {
    const merchantPhone = phone.trim();
    if (!merchantPhone) {
      window.alert('يرجى إدخال رقم هاتف التاجر.');
      return;
    }
    if (selectedIds.length === 0) {
      window.alert('يرجى اختيار قسم واحد على الأقل.');
      return;
    }
    const primary = primaryServiceId && selectedIds.includes(primaryServiceId)
      ? primaryServiceId
      : selectedIds[0];

    await onSubmit({
      merchantPhone,
      fullName: fullName.trim() || undefined,
      primaryServiceId: primary,
      serviceIds: selectedIds,
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
        style={{ maxWidth: 720 }}
      >
        <div className="panel-header">
          <div>
            <h3>تسجيل تاجر برقم هاتف</h3>
            <p>
              أنشئ حساب تاجر مسبقاً واختر الأقسام كما في التطبيق. عند تسجيل الدخول
              لأول مرة، يجد التاجر حسابه جاهزاً ويكمل فقط بيانات المتجر.
            </p>
          </div>
        </div>

        <label className="reject-message-field">
          <span>رقم هاتف التاجر *</span>
          <input
            type="tel"
            value={phone}
            onChange={(event) => setPhone(event.target.value)}
            placeholder="مثال: 07808168620"
            dir="ltr"
          />
        </label>

        <label className="reject-message-field">
          <span>اسم التاجر (اختياري)</span>
          <input
            type="text"
            value={fullName}
            onChange={(event) => setFullName(event.target.value)}
            placeholder="يظهر في لوحة الإدارة فقط حتى يكمل التاجر ملفه"
          />
        </label>

        <div style={{ marginBottom: 16 }}>
          <span style={{ display: 'block', marginBottom: 8, fontWeight: 700 }}>
            الأقسام المتاحة للتاجر *
          </span>
          <div className="reject-quick-fill">
            {MERCHANT_SIGNUP_CATEGORIES.map((category) => {
              const active = selectedIds.includes(category.id);
              return (
                <button
                  key={category.id}
                  type="button"
                  className={active ? 'filter-chip active' : 'filter-chip'}
                  onClick={() => toggleCategory(category.id)}
                >
                  {category.titleAr}
                </button>
              );
            })}
          </div>
        </div>

        {selectedCategories.length > 1 ? (
          <label className="reject-message-field">
            <span>القسم الرئيسي</span>
            <select
              value={primaryServiceId || selectedIds[0] || ''}
              onChange={(event) => setPrimaryServiceId(event.target.value)}
            >
              {selectedCategories.map((category) => (
                <option key={category.id} value={category.id}>
                  {category.titleAr}
                </option>
              ))}
            </select>
          </label>
        ) : null}

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
                تسجيل حساب التاجر
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
