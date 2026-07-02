import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useQueryClient } from '@tanstack/react-query';
import { PROFESSIONAL_CATEGORIES } from '../../../admin-types';
import { preRegisterProfessional } from '../../../admin-api';
import { ImageUploadField } from '../../components/ImageUploadField';
import { useAdminToken } from '../../context/AuthContext';

export function RegisterProfessionalPage() {
  const token = useAdminToken();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [form, setForm] = useState({
    professionalPhone: '',
    fullName: '',
    professionId: 'plumber',
    address: '',
    contactPhone: '',
    whatsapp: '',
    openTime: '08:00',
    closeTime: '18:00',
    profileImageUrl: '',
    workSampleUrls: [] as string[],
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const set = (key: keyof typeof form, value: string | string[]) =>
    setForm((f) => ({ ...f, [key]: value }));

  const addWorkSample = (url: string) => {
    if (url) set('workSampleUrls', [...form.workSampleUrls, url]);
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      await preRegisterProfessional(token, {
        professionalPhone: form.professionalPhone.trim(),
        fullName: form.fullName.trim(),
        professionId: form.professionId,
        address: form.address.trim(),
        contactPhone: form.contactPhone.trim(),
        whatsapp: form.whatsapp.trim(),
        openTime: form.openTime,
        closeTime: form.closeTime,
        profileImageUrl: form.profileImageUrl || undefined,
        workSampleUrls: form.workSampleUrls.length ? form.workSampleUrls : undefined,
      });
      await qc.invalidateQueries({ queryKey: ['professionals'] });
      navigate('/admin/professionals/list');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'فشل التسجيل');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <div className="adm-page-header">
        <h1>تسجيل مهني</h1>
        <button type="button" className="adm-btn adm-btn-secondary" onClick={() => navigate(-1)}>رجوع</button>
      </div>
      <form className="adm-card" style={{ maxWidth: 720 }} onSubmit={submit}>
        <div className="adm-grid adm-grid-2">
          <div className="adm-field">
            <label className="adm-label">رقم الهاتف *</label>
            <input className="adm-input" dir="ltr" required value={form.professionalPhone} onChange={(e) => set('professionalPhone', e.target.value)} />
          </div>
          <div className="adm-field">
            <label className="adm-label">الاسم *</label>
            <input className="adm-input" required value={form.fullName} onChange={(e) => set('fullName', e.target.value)} />
          </div>
          <div className="adm-field">
            <label className="adm-label">المهنة *</label>
            <select className="adm-select" value={form.professionId} onChange={(e) => set('professionId', e.target.value)}>
              {PROFESSIONAL_CATEGORIES.map((p) => (
                <option key={p.id} value={p.id}>{p.label}</option>
              ))}
            </select>
          </div>
          <div className="adm-field">
            <label className="adm-label">هاتف التواصل</label>
            <input className="adm-input" dir="ltr" value={form.contactPhone} onChange={(e) => set('contactPhone', e.target.value)} />
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
          <label className="adm-label">العنوان</label>
          <textarea className="adm-textarea" rows={2} value={form.address} onChange={(e) => set('address', e.target.value)} />
        </div>
        <ImageUploadField label="صورة البروفايل" value={form.profileImageUrl} onChange={(v) => set('profileImageUrl', v)} />
        <div className="adm-field">
          <label className="adm-label">نماذج الأعمال</label>
          <ImageUploadField label="إضافة صورة نموذج" value="" onChange={addWorkSample} />
          {form.workSampleUrls.length > 0 && (
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 12 }}>
              {form.workSampleUrls.map((url, i) => (
                <div key={url} style={{ position: 'relative' }}>
                  <img src={url} alt="" style={{ width: 80, height: 80, objectFit: 'cover', borderRadius: 8 }} />
                  <button
                    type="button"
                    className="adm-btn adm-btn-danger"
                    style={{ position: 'absolute', top: 2, left: 2, padding: '2px 6px', fontSize: '0.7rem' }}
                    onClick={() => set('workSampleUrls', form.workSampleUrls.filter((_, j) => j !== i))}
                  >
                    ×
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
        {error && <p className="adm-error">{error}</p>}
        <button type="submit" className="adm-btn adm-btn-primary" disabled={loading}>تسجيل المهني</button>
      </form>
    </div>
  );
}
