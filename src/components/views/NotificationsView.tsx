import React, { useState } from 'react';
import { Send, CheckCircle, AlertCircle, LoaderCircle } from 'lucide-react';
import { sendPushNotification } from '../../admin-api';

interface Props {
  token: string;
  onError: (msg: string) => void;
  onSuccess: (msg: string) => void;
}

const AUDIENCES: { key: string; label: string }[] = [
  { key: 'all', label: 'الجميع' },
  { key: 'customers', label: 'الزبائن' },
  { key: 'merchants', label: 'التجار' },
  { key: 'drivers', label: 'السائقين' },
];

export default function NotificationsView({ token, onError, onSuccess }: Props) {
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [audience, setAudience] = useState('all');
  const [sending, setSending] = useState(false);
  const [result, setResult] = useState<{ sent: number; failed: number; message: string } | null>(null);

  const handleSend = async () => {
    if (!title.trim() || !body.trim()) {
      onError('يرجى إدخال العنوان والنص');
      return;
    }
    setSending(true);
    setResult(null);
    try {
      const res = await sendPushNotification(token, { title: title.trim(), body: body.trim(), audience });
      setResult(res);
      if (res.sent > 0) onSuccess(`تم الإرسال إلى ${res.sent} جهاز${res.failed > 0 ? `، فشل: ${res.failed}` : ''}.`);
      else onError(res.message || 'لم يتم الإرسال');
    } catch (e) {
      onError(String(e));
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="view-card">
      <div className="view-header">
        <h2>إرسال إشعار يدوي</h2>
        <p className="view-subtitle">اكتب العنوان والنص واختر الجمهور المستهدف لإرسال الإشعار</p>
      </div>

      <div className="form-group">
        <label className="form-label">الجمهور المستهدف</label>
        <div className="chip-group">
          {AUDIENCES.map((a) => (
            <button
              key={a.key}
              type="button"
              className={`chip ${audience === a.key ? 'chip-active' : ''}`}
              onClick={() => setAudience(a.key)}
            >
              {a.label}
            </button>
          ))}
        </div>
      </div>

      <div className="form-group">
        <label className="form-label">العنوان</label>
        <input
          type="text"
          className="form-input"
          placeholder="مثال: تحديث جديد في التطبيق"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
        />
      </div>

      <div className="form-group">
        <label className="form-label">النص</label>
        <textarea
          className="form-input form-textarea"
          placeholder="مثال: تم إضافة ميزة جديدة يمكنك تجربتها الآن"
          rows={4}
          value={body}
          onChange={(e) => setBody(e.target.value)}
        />
      </div>

      <button
        type="button"
        className="btn-primary"
        onClick={handleSend}
        disabled={sending}
        style={{ display: 'flex', alignItems: 'center', gap: 8, justifyContent: 'center' }}
      >
        {sending ? (
          <LoaderCircle className="spin" size={18} />
        ) : (
          <Send size={18} />
        )}
        {sending ? 'جار الإرسال...' : 'إرسال الإشعار'}
      </button>

      {result && (
        <div className={`result-banner ${result.sent > 0 ? 'result-banner-success' : 'result-banner-info'}`} style={{ marginTop: 16 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            {result.sent > 0 ? <CheckCircle size={18} /> : <AlertCircle size={18} />}
            <span>تم الإرسال إلى {result.sent} جهاز{result.failed > 0 ? `، فشل: ${result.failed}` : ''}</span>
          </div>
        </div>
      )}
    </div>
  );
}
