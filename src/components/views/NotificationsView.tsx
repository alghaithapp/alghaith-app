import React, { useState } from 'react';
import { Send, CheckCircle, AlertCircle, LoaderCircle, Bell, Users, MessageSquare, Store, Car } from 'lucide-react';
import { sendPushNotification } from '../../admin-api';

interface Props {
  token: string;
  onError: (msg: string) => void;
  onSuccess: (msg: string) => void;
}

const AUDIENCES: { key: string; label: string; icon: React.ReactNode }[] = [
  { key: 'all', label: 'الجميع', icon: <Users size={16} /> },
  { key: 'customers', label: 'الزبائن', icon: <Users size={16} /> },
  { key: 'merchants', label: 'التجار', icon: <Store size={16} /> },
  { key: 'drivers', label: 'السائقين', icon: <Car size={16} /> },
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
    <div style={{
      maxWidth: 680,
      margin: '0 auto',
      padding: '32px 24px',
    }}>
      {/* Header */}
      <div style={{
        display: 'flex',
        alignItems: 'center',
        gap: 16,
        marginBottom: 32,
      }}>
        <div style={{
          width: 52,
          height: 52,
          borderRadius: 16,
          background: 'linear-gradient(135deg, #0EA5E9, #8B5CF6)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          boxShadow: '0 8px 24px rgba(14,165,233,0.25)',
        }}>
          <Bell size={24} color="white" />
        </div>
        <div>
          <h2 style={{
            fontFamily: 'Cairo, sans-serif',
            fontSize: 24,
            fontWeight: 800,
            color: '#1A1A1A',
            margin: 0,
          }}>إرسال إشعار</h2>
          <p style={{
            fontFamily: 'Cairo, sans-serif',
            fontSize: 13,
            color: '#6B7280',
            margin: '4px 0 0',
          }}>اكتب العنوان والنص ثم اختر الجمهور المستهدف</p>
        </div>
      </div>

      {/* Audience Selection */}
      <div style={{
        background: 'white',
        borderRadius: 20,
        padding: 24,
        boxShadow: '0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04)',
        marginBottom: 16,
        border: '1px solid #F0F0F0',
      }}>
        <label style={{
          fontFamily: 'Cairo, sans-serif',
          fontSize: 13,
          fontWeight: 700,
          color: '#374151',
          display: 'block',
          marginBottom: 12,
        }}>
          <Users size={14} style={{ marginLeft: 6, verticalAlign: 'middle' }} />
          الجمهور المستهدف
        </label>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {AUDIENCES.map((a) => {
            const isActive = audience === a.key;
            return (
              <button
                key={a.key}
                type="button"
                onClick={() => setAudience(a.key)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 6,
                  padding: '10px 18px',
                  borderRadius: 12,
                  border: isActive ? '1.5px solid #0EA5E9' : '1.5px solid #E5E7EB',
                  background: isActive ? 'linear-gradient(135deg, #0EA5E9, #8B5CF6)' : 'white',
                  color: isActive ? 'white' : '#374151',
                  fontFamily: 'Cairo, sans-serif',
                  fontSize: 13,
                  fontWeight: 700,
                  cursor: 'pointer',
                  transition: 'all 0.2s',
                  boxShadow: isActive ? '0 4px 12px rgba(14,165,233,0.25)' : 'none',
                }}
              >
                {a.icon}
                {a.label}
              </button>
            );
          })}
        </div>
      </div>

      {/* Message Card */}
      <div style={{
        background: 'white',
        borderRadius: 20,
        padding: 24,
        boxShadow: '0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04)',
        marginBottom: 16,
        border: '1px solid #F0F0F0',
      }}>
        <div style={{ marginBottom: 20 }}>
          <label style={{
            fontFamily: 'Cairo, sans-serif',
            fontSize: 13,
            fontWeight: 700,
            color: '#374151',
            display: 'block',
            marginBottom: 8,
          }}>
            <MessageSquare size={14} style={{ marginLeft: 6, verticalAlign: 'middle' }} />
            عنوان الإشعار
          </label>
          <input
            type="text"
            placeholder="مثال: تحديث جديد في التطبيق"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            style={{
              width: '100%',
              padding: '14px 16px',
              borderRadius: 14,
              border: '1.5px solid #E5E7EB',
              fontFamily: 'Cairo, sans-serif',
              fontSize: 14,
              fontWeight: 600,
              color: '#1A1A1A',
              background: '#FAFAFA',
              outline: 'none',
              boxSizing: 'border-box',
              transition: 'border-color 0.2s',
            }}
            onFocus={(e) => { e.target.style.borderColor = '#0EA5E9'; e.target.style.background = 'white'; }}
            onBlur={(e) => { e.target.style.borderColor = '#E5E7EB'; e.target.style.background = '#FAFAFA'; }}
          />
        </div>

        <div style={{ marginBottom: 4 }}>
          <label style={{
            fontFamily: 'Cairo, sans-serif',
            fontSize: 13,
            fontWeight: 700,
            color: '#374151',
            display: 'block',
            marginBottom: 8,
          }}>
            <MessageSquare size={14} style={{ marginLeft: 6, verticalAlign: 'middle' }} />
            نص الإشعار
          </label>
          <textarea
            placeholder="مثال: تم إضافة ميزة جديدة يمكنك تجربتها الآن"
            rows={4}
            value={body}
            onChange={(e) => setBody(e.target.value)}
            style={{
              width: '100%',
              padding: '14px 16px',
              borderRadius: 14,
              border: '1.5px solid #E5E7EB',
              fontFamily: 'Cairo, sans-serif',
              fontSize: 14,
              fontWeight: 600,
              color: '#1A1A1A',
              background: '#FAFAFA',
              outline: 'none',
              resize: 'vertical',
              minHeight: 100,
              boxSizing: 'border-box',
              transition: 'border-color 0.2s',
            }}
            onFocus={(e) => { e.target.style.borderColor = '#0EA5E9'; e.target.style.background = 'white'; }}
            onBlur={(e) => { e.target.style.borderColor = '#E5E7EB'; e.target.style.background = '#FAFAFA'; }}
          />
        </div>
      </div>

      {/* Send Button */}
      <button
        type="button"
        onClick={handleSend}
        disabled={sending}
        style={{
          width: '100%',
          padding: '16px 24px',
          borderRadius: 16,
          border: 'none',
          background: sending
            ? 'linear-gradient(135deg, #94A3B8, #CBD5E1)'
            : 'linear-gradient(135deg, #0EA5E9, #8B5CF6)',
          color: 'white',
          fontFamily: 'Cairo, sans-serif',
          fontSize: 16,
          fontWeight: 800,
          cursor: sending ? 'not-allowed' : 'pointer',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 10,
          boxShadow: sending ? 'none' : '0 8px 24px rgba(14,165,233,0.3)',
          transition: 'all 0.2s',
          opacity: sending ? 0.7 : 1,
        }}
        onMouseEnter={(e) => { if (!sending) e.currentTarget.style.transform = 'translateY(-2px)'; }}
        onMouseLeave={(e) => { e.currentTarget.style.transform = 'translateY(0)'; }}
      >
        {sending ? (
          <LoaderCircle size={20} className="spin" />
        ) : (
          <Send size={20} />
        )}
        {sending ? 'جار الإرسال...' : 'إرسال الإشعار'}
      </button>

      {/* Result */}
      {result && (
        <div style={{
          marginTop: 20,
          padding: '18px 20px',
          borderRadius: 16,
          background: result.sent > 0 ? '#ECFDF5' : '#FEF2F2',
          border: `1px solid ${result.sent > 0 ? '#A7F3D0' : '#FECACA'}`,
          display: 'flex',
          alignItems: 'center',
          gap: 12,
        }}>
          {result.sent > 0
            ? <CheckCircle size={22} color="#10B981" />
            : <AlertCircle size={22} color="#EF4444" />
          }
          <div>
            <div style={{
              fontFamily: 'Cairo, sans-serif',
              fontSize: 14,
              fontWeight: 700,
              color: result.sent > 0 ? '#065F46' : '#991B1B',
            }}>
              {result.sent > 0 ? '✅ تم الإرسال بنجاح' : '❌ فشل الإرسال'}
            </div>
            <div style={{
              fontFamily: 'Cairo, sans-serif',
              fontSize: 12,
              color: result.sent > 0 ? '#047857' : '#B91C1C',
              marginTop: 2,
            }}>
              تم الإرسال إلى {result.sent} جهاز
              {result.failed > 0 ? `، فشل: ${result.failed}` : ''}
              {result.message && result.message !== `تم الإرسال إلى ${result.sent} جهاز${result.failed > 0 ? `، فشل: ${result.failed}` : ''}.` ? ` — ${result.message}` : ''}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
