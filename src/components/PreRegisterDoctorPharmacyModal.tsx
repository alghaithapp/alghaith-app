import { useEffect, useState } from 'react';
import { LoaderCircle, UserPlus, Stethoscope, Pill } from 'lucide-react';
import type { DoctorPharmacyPreRegisterPayload } from '../admin-types';
import { DOCTOR_SPECIALTIES } from '../admin-types';

interface Props {
  open: boolean;
  isBusy: boolean;
  onClose: () => void;
  onSubmit: (payload: DoctorPharmacyPreRegisterPayload) => Promise<void>;
}

const SUB_CATEGORIES = [
  { id: 'أطباء وعيادات', label: 'طبيب / عيادة', Icon: Stethoscope },
  { id: 'صيدلية', label: 'صيدلية', Icon: Pill },
] as const;

export default function PreRegisterDoctorPharmacyModal({ open, isBusy, onClose, onSubmit }: Props) {
  const [phone, setPhone] = useState('');
  const [fullName, setFullName] = useState('');
  const [subCategoryId, setSubCategoryId] = useState<string>('أطباء وعيادات');
  const [specialty, setSpecialty] = useState('');
  const [openTime, setOpenTime] = useState('');
  const [closeTime, setCloseTime] = useState('');
  const [description, setDescription] = useState('');
  const [address, setAddress] = useState('');
  const [contactPhone, setContactPhone] = useState('');
  const [whatsapp, setWhatsapp] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    if (!open) return;
    setPhone(''); setFullName(''); setSubCategoryId('أطباء وعيادات');
    setSpecialty(''); setOpenTime(''); setCloseTime(''); setDescription(''); setAddress(''); setContactPhone(''); setWhatsapp('');
    setError('');
  }, [open]);

  async function handleSubmit() {
    if (!phone.trim()) { setError('رقم الهاتف مطلوب.'); return; }
    if (!fullName.trim()) { setError('الاسم مطلوب.'); return; }
    if (subCategoryId === 'أطباء وعيادات' && !specialty.trim()) {
      setError('يرجى اختيار التخصص.');
      return;
    }
    setError('');
    await onSubmit({ subscriberPhone: phone.trim(), fullName: fullName.trim(), subCategoryId: subCategoryId as 'أطباء وعيادات' | 'صيدلية',
      ...(subCategoryId === 'أطباء وعيادات' ? { specialty: specialty.trim() as DoctorPharmacyPreRegisterPayload['specialty'] } : {}),
      ...(openTime.trim() ? { openTime: openTime.trim() } : {}),
      ...(closeTime.trim() ? { closeTime: closeTime.trim() } : {}),
      ...(description.trim() ? { description: description.trim() } : {}),
      ...(address.trim() ? { address: address.trim() } : {}),
      ...(contactPhone.trim() ? { contactPhone: contactPhone.trim() } : {}),
      ...(whatsapp.trim() ? { whatsapp: whatsapp.trim() } : {}),
    });
  }

  if (!open) return null;

  return (
    <div className="modal-backdrop" role="presentation" onClick={onClose}>
      <div className="modal-card" role="dialog" aria-modal="true" onClick={(event) => event.stopPropagation()} style={{ maxWidth: 560, display: 'flex', flexDirection: 'column', maxHeight: '90vh' }}>
        <div className="panel-header">
          <div>
            <h3>إضافة طبيب / صيدلية</h3>
            <p>سجّل حساب طبيب أو صيدلية برقم الهاتف — عند تسجيل الدخول سيجد ملفه جاهزاً.</p>
          </div>
        </div>

        {error ? <div className="delete-warning-box" style={{ marginBottom: 16, color: 'var(--error-text)' }}>{error}</div> : null}

        <div style={{ overflowY: 'auto', flex: 1, paddingRight: 4 }}>
          <label className="reject-message-field">
            <span>نوع التسجيل <span style={{ color: 'var(--error-text)' }}>*</span></span>
            <div style={{ display: 'flex', gap: 8 }}>
              {SUB_CATEGORIES.map((cat) => (
                <button key={cat.id} type="button" onClick={() => setSubCategoryId(cat.id)} style={{
                  flex: 1, padding: '10px', borderRadius: 10, border: subCategoryId === cat.id ? '2px solid var(--primary)' : '1px solid var(--border)',
                  background: subCategoryId === cat.id ? 'var(--primary-light)' : 'var(--surface)', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8, justifyContent: 'center',
                }}>
                  <cat.Icon size={18} color={subCategoryId === cat.id ? 'var(--primary)' : 'var(--text-secondary)'} />
                  <span style={{ fontWeight: 600, fontSize: 14 }}>{cat.label}</span>
                </button>
              ))}
            </div>
          </label>

          <label className="reject-message-field">
            <span>رقم الهاتف <span style={{ color: 'var(--error-text)' }}>*</span></span>
            <input type="tel" value={phone} onChange={(event) => setPhone(event.target.value)} placeholder="مثال: 07701234567" dir="ltr" disabled={isBusy} />
          </label>

          <label className="reject-message-field">
            <span>الاسم <span style={{ color: 'var(--error-text)' }}>*</span></span>
            <input type="text" value={fullName} onChange={(event) => setFullName(event.target.value)} placeholder="اسم الطبيب / الصيدلية" disabled={isBusy} />
          </label>

          {subCategoryId === 'أطباء وعيادات' && (
            <label className="reject-message-field">
              <span>التخصص <span style={{ color: 'var(--error-text)' }}>*</span></span>
              <select value={specialty} onChange={(event) => setSpecialty(event.target.value)} disabled={isBusy}>
                <option value="">اختر التخصص...</option>
                {DOCTOR_SPECIALTIES.map((item) => (
                  <option key={item.id} value={item.id}>{item.labelAr}</option>
                ))}
              </select>
            </label>
          )}
          {subCategoryId === 'أطباء وعيادات' && (
            <div style={{ display: 'flex', gap: 8 }}>
              <label className="reject-message-field" style={{ flex: 1 }}>
                <span>وقت الفتح</span>
                <input type="time" value={openTime} onChange={(event) => setOpenTime(event.target.value)} disabled={isBusy} />
              </label>
              <label className="reject-message-field" style={{ flex: 1 }}>
                <span>وقت الإغلاق</span>
                <input type="time" value={closeTime} onChange={(event) => setCloseTime(event.target.value)} disabled={isBusy} />
              </label>
            </div>
          )}
          <label className="reject-message-field">
            <span>رقم تواصل (اختياري)</span>
            <input type="tel" value={contactPhone} onChange={(event) => setContactPhone(event.target.value)} placeholder="رقم إضافي للاتصال" dir="ltr" disabled={isBusy} />
          </label>

          <label className="reject-message-field">
            <span>رقم واتساب (اختياري)</span>
            <input type="tel" value={whatsapp} onChange={(event) => setWhatsapp(event.target.value)} placeholder="رقم الواتساب" dir="ltr" disabled={isBusy} />
          </label>

          <label className="reject-message-field">
            <span>العنوان (اختياري)</span>
            <input type="text" value={address} onChange={(event) => setAddress(event.target.value)} placeholder="عنوان العيادة / الصيدلية" disabled={isBusy} />
          </label>

          <label className="reject-message-field">
            <span>وصف (اختياري)</span>
            <textarea rows={3} value={description} onChange={(event) => setDescription(event.target.value)} placeholder="وصف مختصر للخدمات" disabled={isBusy} />
          </label>
        </div>

        <div className="modal-actions">
          <button className="ghost-button" type="button" onClick={onClose} disabled={isBusy}>إلغاء</button>
          <button className="primary-button" type="button" onClick={() => void handleSubmit()} disabled={isBusy}>
            {isBusy ? <><LoaderCircle size={16} className="spin" /> جارٍ التسجيل...</> : <><UserPlus size={16} /> تسجيل</>}
          </button>
        </div>
      </div>
    </div>
  );
}
