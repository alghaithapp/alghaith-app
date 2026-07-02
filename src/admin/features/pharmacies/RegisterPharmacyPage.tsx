import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useQueryClient } from '@tanstack/react-query';
import { preRegisterPharmacy } from '../../../admin-api';
import { ImageUploadField } from '../../components/ImageUploadField';
import { useAdminToken } from '../../context/AuthContext';

export function RegisterPharmacyPage() {
  const token = useAdminToken();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [form, setForm] = useState({
    subscriberPhone: '',
    fullName: '',
    contactPhone: '',
    whatsapp: '',
    address: '',
    openTime: '08:00',
    closeTime: '22:00',
    profileImageUrl: '',
    clinicImageUrl: '',
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const set = (key: keyof typeof form, value: string) => setForm((f) => ({ ...f, [key]: value }));

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      await preRegisterPharmacy(token, {
        subscriberPhone: form.subscriberPhone.trim(),
        fullName: form.fullName.trim(),
        contactPhone: form.contactPhone.trim(),
        whatsapp: form.whatsapp.trim() || form.contactPhone.trim(),
        address: form.address.trim(),
        openTime: form.openTime,
        closeTime: form.closeTime,
        profileImageUrl: form.profileImageUrl || undefined,
        clinicImageUrl: form.clinicImageUrl || undefined,
      });
      await queryClient.invalidateQueries({ queryKey: ['merchants'] });
      navigate('/admin/health-beauty/pharmacies');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'فشل التسجيل');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <div className="adm-page-header">
        <h1>تسجيل صيدلية</h1>
        <button type="button" className="adm-btn adm-btn-secondary" onClick={() => navigate(-1)}>رجوع</button>
      </div>
      <form className="adm-card" style={{ maxWidth: 720 }} onSubmit={submit}>
        <div className="adm-grid adm-grid-2">
          <div className="adm-field">
            <label className="adm-label">رقم حساب التطبيق *</label>
            <input className="adm-input" dir="ltr" required value={form.subscriberPhone} onChange={(e) => set('subscriberPhone', e.target.value)} />
          </div>
          <div className="adm-field">
            <label className="adm-label">اسم الصيدلية *</label>
            <input className="adm-input" required value={form.fullName} onChange={(e) => set('fullName', e.target.value)} />
          </div>
          <div className="adm-field">
            <label className="adm-label">رقم التواصل *</label>
            <input className="adm-input" dir="ltr" required value={form.contactPhone} onChange={(e) => set('contactPhone', e.target.value)} />
          </div>
          <div className="adm-field">
            <label className="adm-label">واتساب</label>
            <input className="adm-input" dir="ltr" value={form.whatsapp} onChange={(e) => set('whatsapp', e.target.value)} />
          </div>
          <div className="adm-field">
            <label className="adm-label">من</label>
            <input className="adm-input" type="time" value={form.openTime} onChange={(e) => set('openTime', e.target.value)} />
          </div>
          <div className="adm-field">
            <label className="adm-label">إلى</label>
            <input className="adm-input" type="time" value={form.closeTime} onChange={(e) => set('closeTime', e.target.value)} />
          </div>
        </div>
        <div className="adm-field">
          <label className="adm-label">العنوان *</label>
          <textarea className="adm-textarea" rows={2} required value={form.address} onChange={(e) => set('address', e.target.value)} />
        </div>
        <div className="adm-grid adm-grid-2">
          <ImageUploadField label="شعار الصيدلية" value={form.profileImageUrl} onChange={(v) => set('profileImageUrl', v)} />
          <ImageUploadField label="صورة واجهة الصيدلية" value={form.clinicImageUrl} onChange={(v) => set('clinicImageUrl', v)} />
        </div>
        {error && <p className="adm-error">{error}</p>}
        <button type="submit" className="adm-btn adm-btn-primary" disabled={loading}>تسجيل الصيدلية</button>
      </form>
    </div>
  );
}
