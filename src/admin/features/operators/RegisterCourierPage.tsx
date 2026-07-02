import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { preRegisterCourier } from '../../../admin-api';
import { useAdminToken } from '../../context/AuthContext';

export function RegisterCourierPage() {
  const token = useAdminToken();
  const navigate = useNavigate();
  const [courierPhone, setCourierPhone] = useState('');
  const [fullName, setFullName] = useState('');
  const [note, setNote] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const result = await preRegisterCourier(token, {
        courierPhone: courierPhone.trim(),
        fullName: fullName.trim(),
        note: note.trim() || undefined,
      });
      navigate(`/admin/couriers/${encodeURIComponent(result.phone)}`);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'فشل التسجيل');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <div className="adm-page-header">
        <h1>تسجيل مندوب توصيل</h1>
        <button type="button" className="adm-btn adm-btn-secondary" onClick={() => navigate('/admin/couriers')}>
          رجوع
        </button>
      </div>
      <form className="adm-card" style={{ maxWidth: 520 }} onSubmit={submit}>
        <p style={{ marginTop: 0, color: 'var(--adm-muted)', lineHeight: 1.7 }}>
          يُنشأ حساب المندوب ويُرسل له إشعار لإكمال المستندات من التطبيق.
        </p>
        <div className="adm-field">
          <label className="adm-label">رقم هاتف المندوب *</label>
          <input
            className="adm-input"
            dir="ltr"
            required
            value={courierPhone}
            onChange={(e) => setCourierPhone(e.target.value)}
          />
        </div>
        <div className="adm-field">
          <label className="adm-label">الاسم الثلاثي *</label>
          <input
            className="adm-input"
            required
            value={fullName}
            onChange={(e) => setFullName(e.target.value)}
          />
        </div>
        <div className="adm-field">
          <label className="adm-label">ملاحظة داخلية</label>
          <textarea className="adm-textarea" rows={2} value={note} onChange={(e) => setNote(e.target.value)} />
        </div>
        {error ? <p className="adm-error">{error}</p> : null}
        <button type="submit" className="adm-btn adm-btn-primary" disabled={loading}>
          {loading ? 'جاري التسجيل...' : 'تسجيل المندوب'}
        </button>
      </form>
    </div>
  );
}
