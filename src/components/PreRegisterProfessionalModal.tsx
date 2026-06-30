import React, { useState, useRef } from 'react';
import { LoaderCircle, Upload, X, Image } from 'lucide-react';
import type { ProfessionalPreRegisterPayload } from '../admin-types';
import { PROFESSIONAL_CATEGORIES } from '../admin-types';
import { uploadImage } from '../admin-api';

interface PreRegisterProfessionalModalProps {
  token: string;
  isBusy: boolean;
  onPreRegister: (payload: ProfessionalPreRegisterPayload) => Promise<void>;
  onClose: () => void;
}

export default function PreRegisterProfessionalModal({
  token,
  isBusy,
  onPreRegister,
  onClose,
}: PreRegisterProfessionalModalProps) {
  const [phone, setPhone] = useState('');
  const [fullName, setFullName] = useState('');
  const [professionId, setProfessionId] = useState('');
  const [description, setDescription] = useState('');
  const [address, setAddress] = useState('');
  const [contactPhone, setContactPhone] = useState('');
  const [whatsapp, setWhatsapp] = useState('');
  const [openTime, setOpenTime] = useState('');
  const [closeTime, setCloseTime] = useState('');
  const [profileImageUrl, setProfileImageUrl] = useState('');
  const [workSampleUrls, setWorkSampleUrls] = useState<string[]>([]);
  const [isUploading, setIsUploading] = useState(false);
  const [uploadError, setUploadError] = useState('');
  const profileInputRef = useRef<HTMLInputElement>(null);
  const workInputRef = useRef<HTMLInputElement>(null);

  async function handleProfileImageUpload(file: File) {
    if (!file) return;
    setIsUploading(true);
    setUploadError('');
    try {
      const url = await uploadImage(token, file);
      setProfileImageUrl(url);
    } catch (error) {
      setUploadError(error instanceof Error ? error.message : 'فشل رفع الصورة');
    } finally {
      setIsUploading(false);
    }
  }

  async function handleWorkSampleUpload(file: File) {
    if (!file) return;
    setIsUploading(true);
    setUploadError('');
    try {
      const url = await uploadImage(token, file);
      setWorkSampleUrls((prev) => [...prev, url]);
    } catch (error) {
      setUploadError(error instanceof Error ? error.message : 'فشل رفع الصورة');
    } finally {
      setIsUploading(false);
    }
  }

  function removeWorkSample(index: number) {
    setWorkSampleUrls((prev) => prev.filter((_, i) => i !== index));
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!phone.trim() || !fullName.trim() || !professionId) return;

    const payload: ProfessionalPreRegisterPayload = {
      professionalPhone: phone.trim(),
      fullName: fullName.trim(),
      professionId,
      description: description.trim() || undefined,
      address: address.trim() || undefined,
      contactPhone: contactPhone.trim() || undefined,
      whatsapp: whatsapp.trim() || undefined,
      openTime: openTime.trim() || undefined,
      closeTime: closeTime.trim() || undefined,
      profileImageUrl: profileImageUrl || undefined,
      workSampleUrls: workSampleUrls.length > 0 ? workSampleUrls : undefined,
      showPhoneToCustomers: true,
      showWhatsAppToCustomers: true,
    };

    await onPreRegister(payload);
  }

  const isFormValid = phone.trim() && fullName.trim() && professionId;

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-card wide-modal" onClick={(e) => e.stopPropagation()}>
        <div className="form-modal-header">
          <h3>إضافة مهني جديد</h3>
          <button type="button" className="ghost-button" onClick={onClose}>
            <X size={20} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="form-modal-body">
          {uploadError ? (
            <div className="message error">{uploadError}</div>
          ) : null}

          <div className="form-grid">
            <div className="form-field">
              <label className="form-label">رقم الهاتف *</label>
              <input type="tel" className="form-input" placeholder="07xxxxxxxxx" value={phone} onChange={(e) => setPhone(e.target.value)} dir="ltr" required />
            </div>
            <div className="form-field">
              <label className="form-label">الاسم الكامل *</label>
              <input type="text" className="form-input" placeholder="اسم المهني" value={fullName} onChange={(e) => setFullName(e.target.value)} required />
            </div>
            <div className="form-field">
              <label className="form-label">التخصص *</label>
              <select className="form-input" value={professionId} onChange={(e) => setProfessionId(e.target.value)} required>
                <option value="">-- اختر التخصص --</option>
                {PROFESSIONAL_CATEGORIES.map((cat) => (
                  <option key={cat.id} value={cat.id}>{cat.label}</option>
                ))}
              </select>
            </div>
            <div className="form-field">
              <label className="form-label">رقم واتساب</label>
              <input type="tel" className="form-input" placeholder="07xxxxxxxxx" value={whatsapp} onChange={(e) => setWhatsapp(e.target.value)} dir="ltr" />
            </div>
            <div className="form-field">
              <label className="form-label">رقم الهاتف للتواصل</label>
              <input type="tel" className="form-input" placeholder="07xxxxxxxxx" value={contactPhone} onChange={(e) => setContactPhone(e.target.value)} dir="ltr" />
            </div>
            <div className="form-field-row">
              <div className="form-field" style={{ flex: 1 }}>
                <label className="form-label">وقت الفتح</label>
                <input type="time" className="form-input" value={openTime} onChange={(e) => setOpenTime(e.target.value)} />
              </div>
              <div className="form-field" style={{ flex: 1 }}>
                <label className="form-label">وقت الإغلاق</label>
                <input type="time" className="form-input" value={closeTime} onChange={(e) => setCloseTime(e.target.value)} />
              </div>
            </div>
          </div>

          <div className="form-field">
            <label className="form-label">العنوان</label>
            <input type="text" className="form-input" placeholder="العنوان" value={address} onChange={(e) => setAddress(e.target.value)} />
          </div>

          <div className="form-field">
            <label className="form-label">الوصف</label>
            <textarea className="form-input" placeholder="وصف المهنة والخدمات المقدمة" value={description} onChange={(e) => setDescription(e.target.value)} rows={3} />
          </div>

          <div className="form-field">
            <label className="form-label">الصورة الشخصية</label>
            <div className="form-upload-row">
              <input ref={profileInputRef} type="file" accept="image/*" className="form-file-input" onChange={(e) => { const file = e.target.files?.[0]; if (file) handleProfileImageUpload(file); e.target.value = ''; }} />
              <button type="button" className="soft-button" onClick={() => profileInputRef.current?.click()} disabled={isUploading}>
                {isUploading ? <LoaderCircle className="spin" size={16} /> : <Upload size={16} />}
                اختر صورة
              </button>
              {profileImageUrl ? (
                <div className="form-upload-preview">
                  <img src={profileImageUrl} alt="صورة شخصية" className="profile-preview-img" />
                  <button type="button" className="ghost-button" onClick={() => setProfileImageUrl('')}><X size={14} /></button>
                </div>
              ) : null}
            </div>
          </div>

          <div className="form-field">
            <label className="form-label">صور الأعمال</label>
            <div className="work-sample-grid">
              {workSampleUrls.map((url, index) => (
                <div key={index} className="work-sample-thumb">
                  <img src={url} alt={`عمل ${index + 1}`} />
                  <button type="button" className="work-sample-remove" onClick={() => removeWorkSample(index)}><X size={12} /></button>
                </div>
              ))}
            </div>
            <input ref={workInputRef} type="file" accept="image/*" className="form-file-input" onChange={(e) => { const file = e.target.files?.[0]; if (file) handleWorkSampleUpload(file); e.target.value = ''; }} />
            <button type="button" className="soft-button" onClick={() => workInputRef.current?.click()} disabled={isUploading}>
              {isUploading ? <LoaderCircle className="spin" size={16} /> : <Image size={16} />}
              إضافة صورة عمل
            </button>
          </div>

          <div className="modal-actions">
            <button type="submit" className="primary-button" disabled={isBusy || !isFormValid}>
              {isBusy ? <LoaderCircle className="spin" size={16} /> : null}
              {isBusy ? 'جار الإضافة...' : 'إضافة المهني'}
            </button>
            <button type="button" className="ghost-button" onClick={onClose}>إلغاء</button>
          </div>
        </form>
      </div>
    </div>
  );
}
