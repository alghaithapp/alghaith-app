import React, { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  BEAUTY_SUBCATEGORIES,
  MERCHANT_SIGNUP_CATEGORIES,
  SHOPPING_PRODUCT_SUBCATEGORIES,
  type MerchantCategoryUpdatePayload,
  type MerchantPreRegisterPayload,
} from '../../../admin-types';
import { preRegisterMerchant, updateMerchantCategory } from '../../../admin-api';
import { useAdminToken } from '../../context/AuthContext';

export function RegisterMerchantPage() {
  const token = useAdminToken();
  const navigate = useNavigate();
  const [phone, setPhone] = useState('');
  const [fullName, setFullName] = useState('');
  const [primaryServiceId, setPrimaryServiceId] = useState('product');
  const [serviceSubCategory, setServiceSubCategory] = useState('');
  const [note, setNote] = useState('');
  const [isBazaarMember, setIsBazaarMember] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const [convertPhone, setConvertPhone] = useState('');
  const [convertPrimary, setConvertPrimary] = useState('product');
  const [convertSubCategory, setConvertSubCategory] = useState('cosmetics');
  const [convertBazaar, setConvertBazaar] = useState(false);
  const [convertLoading, setConvertLoading] = useState(false);
  const [convertError, setConvertError] = useState('');
  const [convertSuccess, setConvertSuccess] = useState('');

  const subCategoryOptions = useMemo(() => {
    if (primaryServiceId === 'product') return SHOPPING_PRODUCT_SUBCATEGORIES;
    if (primaryServiceId === 'beauty') return BEAUTY_SUBCATEGORIES;
    return [];
  }, [primaryServiceId]);

  const convertSubOptions = useMemo(() => {
    if (convertPrimary === 'product') return SHOPPING_PRODUCT_SUBCATEGORIES;
    if (convertPrimary === 'beauty') return BEAUTY_SUBCATEGORIES;
    return [];
  }, [convertPrimary]);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setSuccess('');
    const payload: MerchantPreRegisterPayload = {
      merchantPhone: phone.trim(),
      fullName: fullName.trim(),
      primaryServiceId,
      serviceIds: [primaryServiceId],
      note: note.trim() || undefined,
      isBazaarMember,
      serviceSubCategory: serviceSubCategory.trim() || undefined,
    };
    try {
      await preRegisterMerchant(token, payload);
      setSuccess('تم تسجيل التاجر بنجاح.');
      setTimeout(() => navigate('/admin/merchants'), 800);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'فشل التسجيل');
    } finally {
      setLoading(false);
    }
  };

  const submitConvert = async (e: React.FormEvent) => {
    e.preventDefault();
    setConvertLoading(true);
    setConvertError('');
    setConvertSuccess('');
    const payload: MerchantCategoryUpdatePayload = {
      merchantPhone: convertPhone.trim(),
      primaryServiceId: convertPrimary,
      serviceIds: [convertPrimary],
      serviceSubCategory: convertSubCategory.trim() || undefined,
      isBazaarMember: convertBazaar,
    };
    try {
      const result = await updateMerchantCategory(token, payload);
      setConvertSuccess(
        `تم تحويل «${result.storeName || result.phone}» إلى ${result.primaryServiceId}${
          result.serviceSubCategory ? ` / ${result.serviceSubCategory}` : ''
        }.`,
      );
    } catch (err: unknown) {
      setConvertError(err instanceof Error ? err.message : 'فشل التحويل');
    } finally {
      setConvertLoading(false);
    }
  };

  return (
    <div>
      <div className="adm-page-header">
        <h1>تسجيل تاجر</h1>
        <button type="button" className="adm-btn adm-btn-secondary" onClick={() => navigate(-1)}>رجوع</button>
      </div>

      <form className="adm-card" style={{ maxWidth: 560, marginBottom: 24 }} onSubmit={submit}>
        <h2 style={{ marginTop: 0, fontSize: 18 }}>تسجيل تاجر جديد</h2>
        <div className="adm-field">
          <label className="adm-label">رقم هاتف التاجر *</label>
          <input className="adm-input" dir="ltr" required value={phone} onChange={(e) => setPhone(e.target.value)} />
        </div>
        <div className="adm-field">
          <label className="adm-label">اسم المتجر / التاجر</label>
          <input className="adm-input" value={fullName} onChange={(e) => setFullName(e.target.value)} />
        </div>
        <div className="adm-field">
          <label className="adm-label">القسم الرئيسي *</label>
          <select
            className="adm-select"
            value={primaryServiceId}
            onChange={(e) => {
              setPrimaryServiceId(e.target.value);
              setServiceSubCategory('');
            }}
          >
            {MERCHANT_SIGNUP_CATEGORIES.map((c) => (
              <option key={c.id} value={c.id}>{c.titleAr}</option>
            ))}
          </select>
        </div>
        {subCategoryOptions.length > 0 && (
          <div className="adm-field">
            <label className="adm-label">التخصص الفرعي</label>
            <select
              className="adm-select"
              value={serviceSubCategory}
              onChange={(e) => setServiceSubCategory(e.target.value)}
            >
              <option value="">— اختياري —</option>
              {subCategoryOptions.map((c) => (
                <option key={c.id} value={c.id}>{c.labelAr}</option>
              ))}
            </select>
          </div>
        )}
        <div className="adm-field">
          <label className="adm-label" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <input
              type="checkbox"
              checked={isBazaarMember}
              onChange={(e) => setIsBazaarMember(e.target.checked)}
            />
            تفعيل بازار ومطاعم الغيث مباشرة
          </label>
          <p style={{ margin: '6px 0 0', color: 'var(--adm-muted)', fontSize: 13 }}>
            يظهر المتجر في بازار الغيث (مطاعم + متاجر) فور التسجيل.
          </p>
        </div>
        <div className="adm-field">
          <label className="adm-label">ملاحظة</label>
          <textarea className="adm-textarea" rows={2} value={note} onChange={(e) => setNote(e.target.value)} />
        </div>
        {error && <p className="adm-error">{error}</p>}
        {success && <p style={{ color: 'var(--adm-success, #22c55e)' }}>{success}</p>}
        <button type="submit" className="adm-btn adm-btn-primary" disabled={loading}>تسجيل التاجر</button>
      </form>

      <form className="adm-card" style={{ maxWidth: 560 }} onSubmit={submitConvert}>
        <h2 style={{ marginTop: 0, fontSize: 18 }}>تحويل تصنيف تاجر موجود</h2>
        <p style={{ color: 'var(--adm-muted)', marginTop: 0 }}>
          لإصلاح التصنيف الخاطئ — مثل تحويل متجر من «الصحة والجمال» إلى «تسوق / مستحضرات تجميل».
        </p>
        <div className="adm-field">
          <label className="adm-label">رقم هاتف التاجر *</label>
          <input
            className="adm-input"
            dir="ltr"
            required
            value={convertPhone}
            onChange={(e) => setConvertPhone(e.target.value)}
          />
        </div>
        <div className="adm-field">
          <label className="adm-label">القسم الجديد *</label>
          <select
            className="adm-select"
            value={convertPrimary}
            onChange={(e) => {
              setConvertPrimary(e.target.value);
              setConvertSubCategory(e.target.value === 'product' ? 'cosmetics' : '');
            }}
          >
            {MERCHANT_SIGNUP_CATEGORIES.map((c) => (
              <option key={c.id} value={c.id}>{c.titleAr}</option>
            ))}
          </select>
        </div>
        {convertSubOptions.length > 0 && (
          <div className="adm-field">
            <label className="adm-label">التخصص الفرعي</label>
            <select
              className="adm-select"
              value={convertSubCategory}
              onChange={(e) => setConvertSubCategory(e.target.value)}
            >
              {convertSubOptions.map((c) => (
                <option key={c.id} value={c.id}>{c.labelAr}</option>
              ))}
            </select>
          </div>
        )}
        <div className="adm-field">
          <label className="adm-label" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <input
              type="checkbox"
              checked={convertBazaar}
              onChange={(e) => setConvertBazaar(e.target.checked)}
            />
            تفعيل بازار ومطاعم الغيث
          </label>
        </div>
        {convertError && <p className="adm-error">{convertError}</p>}
        {convertSuccess && <p style={{ color: 'var(--adm-success, #22c55e)' }}>{convertSuccess}</p>}
        <button type="submit" className="adm-btn adm-btn-primary" disabled={convertLoading}>
          تحويل التصنيف
        </button>
      </form>
    </div>
  );
}
