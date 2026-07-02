import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { preRegisterCustomer } from '../../../admin-api';
import { useAdminToken } from '../../context/AuthContext';

export function RegisterCustomerPage() {
  const token = useAdminToken();
  const navigate = useNavigate();
  const [phone, setPhone] = useState('');
  const [fullName, setFullName] = useState('');
  const [address, setAddress] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      await preRegisterCustomer(token, { phone: phone.trim(), fullName: fullName.trim(), address: address.trim() });
      navigate('/admin/accounts');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'فشل التسجيل');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <div className="adm-page-header">
        <h1>تسجيل زبون</h1>
        <button type="button" className="adm-btn adm-btn-secondary" onClick={() => navigate(-1)}>رجوع</button>
      </div>
      <form className="adm-card" style={{ maxWidth: 520 }} onSubmit={submit}>
        <div className="adm-field">
          <label className="adm-label">رقم الهاتف *</label>
          <input className="adm-input" dir="ltr" required value={phone} onChange={(e) => setPhone(e.target.value)} />
        </div>
        <div className="adm-field">
          <label className="adm-label">الاسم</label>
          <input className="adm-input" value={fullName} onChange={(e) => setFullName(e.target.value)} />
        </div>
        <div className="adm-field">
          <label className="adm-label">العنوان</label>
          <textarea className="adm-textarea" rows={2} value={address} onChange={(e) => setAddress(e.target.value)} />
        </div>
        {error && <p className="adm-error">{error}</p>}
        <button type="submit" className="adm-btn adm-btn-primary" disabled={loading}>
          {loading ? 'جاري الحفظ...' : 'تسجيل الزبون'}
        </button>
      </form>
    </div>
  );
}
