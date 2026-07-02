import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { Bell, Car, MessageSquare, Send, Smartphone, Store, Truck, Users } from 'lucide-react';
import { sendPushNotification } from '../../../admin-api';
import { useAdminToken } from '../../context/AuthContext';

const AUDIENCES = [
  { key: 'all', label: 'الجميع', icon: Users },
  { key: 'customers', label: 'الزبائن', icon: Users },
  { key: 'merchants', label: 'التجار', icon: Store },
  { key: 'drivers', label: 'السائقين', icon: Car },
  { key: 'delivery', label: 'المندوبين', icon: Truck },
] as const;

const PLATFORMS = [
  { key: 'all', label: 'أندرويد + آيفون' },
  { key: 'android', label: 'أندرويد فقط' },
  { key: 'ios', label: 'آيفون فقط' },
] as const;

type AudienceKey = (typeof AUDIENCES)[number]['key'];
type PlatformKey = (typeof PLATFORMS)[number]['key'];

export function PushNotificationsPage() {
  const token = useAdminToken();
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [audience, setAudience] = useState<AudienceKey>('all');
  const [platform, setPlatform] = useState<PlatformKey>('all');
  const [storeUpdate, setStoreUpdate] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');
  const [result, setResult] = useState<{
    sent: number;
    failed: number;
    message: string;
    tokenCount?: number;
    inAppCount?: number;
  } | null>(null);

  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !body.trim()) {
      setError('يرجى إدخال عنوان الرسالة ونصها.');
      return;
    }
    setSending(true);
    setError('');
    setResult(null);
    try {
      const res = await sendPushNotification(token, {
        title: title.trim(),
        body: body.trim(),
        audience,
        platform,
        storeUpdate,
      });
      setResult(res);
      if ((res.inAppCount ?? 0) <= 0 && res.sent <= 0) {
        setError(res.message || 'لم يتم إرسال الرسالة إلى أي مستخدم.');
      }
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'فشل إرسال الرسالة.');
    } finally {
      setSending(false);
    }
  };

  return (
    <div style={{ maxWidth: 720 }}>
      <div className="adm-page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div
            style={{
              width: 48,
              height: 48,
              borderRadius: 14,
              background: 'var(--adm-surface-2)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: 'var(--adm-brand)',
            }}
          >
            <MessageSquare size={22} />
          </div>
          <div>
            <h1 style={{ margin: 0 }}>رسائل للمستخدمين</h1>
            <p style={{ margin: '4px 0 0', color: 'var(--adm-muted)', fontSize: '0.9rem' }}>
              إرسال إعلان عام لجميع المستخدمين (إشعار داخلي + push). للرد على مستخدم محدد استخدم{' '}
              <Link to="/admin/support-chat" style={{ color: 'var(--adm-brand)' }}>
                محادثات الدعم
              </Link>
              .
            </p>
          </div>
        </div>
      </div>

      <form className="adm-card" onSubmit={handleSend}>
        <div className="adm-field" style={{ marginBottom: 20 }}>
          <label className="adm-label">الجمهور المستهدف</label>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {AUDIENCES.map(({ key, label, icon: Icon }) => (
              <button
                key={key}
                type="button"
                className={`adm-btn ${audience === key ? 'adm-btn-primary' : 'adm-btn-secondary'}`}
                onClick={() => setAudience(key)}
              >
                <Icon size={16} />
                {label}
              </button>
            ))}
          </div>
        </div>

        <div className="adm-field" style={{ marginBottom: 20 }}>
          <label className="adm-label">نوع الجهاز (للإشعار الخارجي)</label>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {PLATFORMS.map(({ key, label }) => (
              <button
                key={key}
                type="button"
                className={`adm-btn ${platform === key ? 'adm-btn-primary' : 'adm-btn-secondary'}`}
                onClick={() => setPlatform(key)}
              >
                <Smartphone size={16} />
                {label}
              </button>
            ))}
          </div>
        </div>

        <div className="adm-field">
          <label className="adm-label">عنوان الرسالة</label>
          <input
            className="adm-input"
            placeholder="مثال: إعلان مهم من إدارة الغيث"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            required
          />
        </div>

        <div className="adm-field">
          <label className="adm-label">نص الرسالة</label>
          <textarea
            className="adm-textarea"
            rows={5}
            placeholder="اكتب رسالتك للمستخدمين هنا..."
            value={body}
            onChange={(e) => setBody(e.target.value)}
            required
          />
        </div>

        <label
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            marginBottom: 20,
            cursor: 'pointer',
            color: 'var(--adm-muted)',
            fontSize: '0.9rem',
          }}
        >
          <input
            type="checkbox"
            checked={storeUpdate}
            onChange={(e) => setStoreUpdate(e.target.checked)}
          />
          إشعار تحديث المتجر (يفتح شاشة التحديث عند الضغط على الإشعار الخارجي)
        </label>

        {error && <p className="adm-error">{error}</p>}

        {result && ((result.inAppCount ?? 0) > 0 || result.sent > 0) && (
          <div
            className="adm-card"
            style={{
              marginBottom: 16,
              background: 'rgba(34, 197, 94, 0.08)',
              borderColor: 'rgba(34, 197, 94, 0.35)',
            }}
          >
            <p style={{ margin: 0, color: '#86efac', fontWeight: 700 }}>تم إرسال الرسالة</p>
            <p style={{ margin: '8px 0 0', color: 'var(--adm-muted)', fontSize: '0.9rem' }}>
              {result.message}
            </p>
            <ul style={{ margin: '10px 0 0', paddingInlineStart: 20, color: 'var(--adm-muted)', fontSize: '0.9rem' }}>
              {(result.inAppCount ?? 0) > 0 && (
                <li>داخل التطبيق: {result.inAppCount} مستخدم</li>
              )}
              {result.sent > 0 && (
                <li>
                  إشعار خارجي: {result.sent} جهاز
                  {result.tokenCount != null ? ` من ${result.tokenCount} مسجّل` : ''}
                </li>
              )}
            </ul>
          </div>
        )}

        <button type="submit" className="adm-btn adm-btn-primary" disabled={sending}>
          <Send size={16} />
          {sending ? 'جاري الإرسال...' : 'إرسال الرسالة'}
        </button>
      </form>

      <div className="adm-card" style={{ marginTop: 16 }}>
        <p style={{ margin: '0 0 10px', fontWeight: 700, display: 'flex', alignItems: 'center', gap: 8 }}>
          <Bell size={16} />
          كيف تصل الرسالة؟
        </p>
        <p style={{ margin: 0, color: 'var(--adm-muted)', fontSize: '0.9rem', lineHeight: 1.7 }}>
          تُحفظ الرسالة في صندوق إشعارات كل مستخدم داخل التطبيق (شاشة الإشعارات). وإذا كان
          الجهاز مسجّلاً للإشعارات، يصل أيضاً إشعار خارجي على شاشة الهاتف. عند فتح التطبيق
          يظهر تنبيه داخلي أعلى الشاشة.
        </p>
      </div>
    </div>
  );
}
