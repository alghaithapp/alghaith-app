import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useQueryClient } from '@tanstack/react-query';
import { preRegisterDoctor } from '../../../admin-api';
import { DOCTOR_SPECIALTIES } from '../../../admin-types';
import { ImageUploadField } from '../../components/ImageUploadField';
import { useAdminToken } from '../../context/AuthContext';

export function RegisterDoctorPage() {
  const token = useAdminToken();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [form, setForm] = useState({
    subscriberPhone: '',
    fullName: '',
    specialty: '',
    doctorPhone: '',
    clinicPhone: '',
    address: '',
    openTime: '09:00',
    closeTime: '17:00',
    profileImageUrl: '',
    clinicImageUrl: '',
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const set = (key: keyof typeof form, value: string) => setForm((f) => ({ ...f, [key]: value }));

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.specialty.trim()) {
      setError('يرجى اختيار التخصص.');
      return;
    }
    setLoading(true);
    setError('');
    try {
      await preRegisterDoctor(token, {
        subscriberPhone: form.subscriberPhone.trim(),
        fullName: form.fullName.trim(),
        specialty: form.specialty.trim(),
        doctorPhone: form.doctorPhone.trim(),
        clinicPhone: form.clinicPhone.trim(),
        address: form.address.trim(),
        openTime: form.openTime,
        closeTime: form.closeTime,
        profileImageUrl: form.profileImageUrl || undefined,
        clinicImageUrl: form.clinicImageUrl || undefined,
      });
      await queryClient.invalidateQueries({ queryKey: ['merchants'] });
      navigate('/admin/health-beauty/doctors');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'فشل التسجيل');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <div className="adm-page-header">
        <h1>تسجيل دكتور</h1>
        <button type="button" className="adm-btn adm-btn-secondary" onClick={() => navigate(-1)}>رجوع</button>
      </div>
      <form className="adm-card" style={{ maxWidth: 720 }} onSubmit={submit}>
        <div className="adm-grid adm-grid-2">
          <div className="adm-field">
            <label className="adm-label">رقم حساب التطبيق *</label>
            <input className="adm-input" dir="ltr" required value={form.subscriberPhone} onChange={(e) => set('subscriberPhone', e.target.value)} />
          </div>
          <div className="adm-field">
            <label className="adm-label">اسم الطبيب *</label>
            <input className="adm-input" required value={form.fullName} onChange={(e) => set('fullName', e.target.value)} />
          </div>
          <div className="adm-field">
            <label className="adm-label">التخصص *</label>
            <select
              className="adm-select"
              required
              value={form.specialty}
              onChange={(e) => set('specialty', e.target.value)}
            >
              <option value="">اختر التخصص...</option>
              {DOCTOR_SPECIALTIES.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.labelAr}
                </option>
              ))}
            </select>
          </div>
          <div className="adm-field">
            <label className="adm-label">رقم الدكتور (تواصل) *</label>
            <input className="adm-input" dir="ltr" required value={form.doctorPhone} onChange={(e) => set('doctorPhone', e.target.value)} />
          </div>
          <div className="adm-field">
            <label className="adm-label">رقم العيادة *</label>
            <input className="adm-input" dir="ltr" required value={form.clinicPhone} onChange={(e) => set('clinicPhone', e.target.value)} />
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
          <label className="adm-label">عنوان العيادة *</label>
          <textarea className="adm-textarea" rows={2} required value={form.address} onChange={(e) => set('address', e.target.value)} />
        </div>
        <div className="adm-grid adm-grid-2">
          <ImageUploadField label="صورة البروفايل" value={form.profileImageUrl} onChange={(v) => set('profileImageUrl', v)} />
          <ImageUploadField label="صورة العيادة" value={form.clinicImageUrl} onChange={(v) => set('clinicImageUrl', v)} />
        </div>
        {error && <p className="adm-error">{error}</p>}
        <button type="submit" className="adm-btn adm-btn-primary" disabled={loading}>تسجيل الدكتور</button>
      </form>
    </div>
  );
}
