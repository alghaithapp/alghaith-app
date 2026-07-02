import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { sendCode, verifyCode } from '../../../admin-api';
import { useAuth } from '../../context/AuthContext';

export function LoginPage() {
  const { setToken } = useAuth();
  const navigate = useNavigate();
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [channel, setChannel] = useState<'whatsapp' | 'sms'>('whatsapp');
  const [sent, setSent] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const onSend = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!phone.trim()) return;
    setLoading(true);
    setError('');
    try {
      await sendCode(phone.trim(), channel);
      setSent(true);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'فشل الإرسال');
    } finally {
      setLoading(false);
    }
  };

  const onVerify = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!code.trim()) return;
    setLoading(true);
    setError('');
    try {
      const session = await verifyCode(phone.trim(), code.trim());
      setToken(session.token);
      navigate('/admin');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'رمز غير صحيح');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="admin-v2 adm-auth">
      <div className="adm-auth-card">
        <h1 style={{ margin: '0 0 8px', color: 'var(--adm-brand)' }}>الغيث</h1>
        <p style={{ margin: '0 0 24px', color: 'var(--adm-muted)' }}>تسجيل دخول المشرفين</p>

        <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
          <button
            type="button"
            className={`adm-btn ${channel === 'whatsapp' ? 'adm-btn-primary' : 'adm-btn-secondary'}`}
            onClick={() => setChannel('whatsapp')}
          >
            واتساب
          </button>
          <button
            type="button"
            className={`adm-btn ${channel === 'sms' ? 'adm-btn-primary' : 'adm-btn-secondary'}`}
            onClick={() => setChannel('sms')}
          >
            SMS
          </button>
        </div>

        {!sent ? (
          <form onSubmit={onSend}>
            <div className="adm-field">
              <label className="adm-label">رقم الهاتف</label>
              <input
                className="adm-input"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="07XXXXXXXXX"
                dir="ltr"
              />
            </div>
            <button type="submit" className="adm-btn adm-btn-primary" style={{ width: '100%' }} disabled={loading}>
              {loading ? 'جاري الإرسال...' : 'إرسال رمز التحقق'}
            </button>
          </form>
        ) : (
          <form onSubmit={onVerify}>
            <div className="adm-field">
              <label className="adm-label">رمز التحقق</label>
              <input
                className="adm-input"
                value={code}
                onChange={(e) => setCode(e.target.value)}
                placeholder="6 أرقام"
                dir="ltr"
                maxLength={6}
              />
            </div>
            <button type="submit" className="adm-btn adm-btn-primary" style={{ width: '100%' }} disabled={loading}>
              {loading ? 'جاري التحقق...' : 'دخول'}
            </button>
            <button
              type="button"
              className="adm-btn adm-btn-secondary"
              style={{ width: '100%', marginTop: 8 }}
              onClick={() => setSent(false)}
            >
              تغيير الرقم
            </button>
          </form>
        )}
        {error && <p className="adm-error">{error}</p>}
      </div>
    </div>
  );
}
