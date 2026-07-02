import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { Headphones, MessageCircle, RefreshCw, Send } from 'lucide-react';
import {
  loadSupportMessages,
  loadSupportThreads,
  markSupportThreadRead,
  sendSupportMessage,
  type SupportChatMessage,
  type SupportChatThread,
} from '../../../admin-api';
import { useAdminToken } from '../../context/AuthContext';

function formatTime(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  return date.toLocaleString('ar-IQ', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function SupportChatPage() {
  const token = useAdminToken();
  const [threads, setThreads] = useState<SupportChatThread[]>([]);
  const [messages, setMessages] = useState<SupportChatMessage[]>([]);
  const [selectedPhone, setSelectedPhone] = useState<string | null>(null);
  const [draft, setDraft] = useState('');
  const [loadingThreads, setLoadingThreads] = useState(true);
  const [loadingMessages, setLoadingMessages] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');
  const messagesEndRef = useRef<HTMLDivElement | null>(null);

  const selectedThread = threads.find((item) => item.thread_id === selectedPhone) ?? null;

  const refreshThreads = useCallback(async () => {
    if (!token) return;
    setLoadingThreads(true);
    setError('');
    try {
      const rows = await loadSupportThreads(token);
      setThreads(rows);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'تعذّر تحميل المحادثات.');
    } finally {
      setLoadingThreads(false);
    }
  }, [token]);

  const refreshMessages = useCallback(async () => {
    if (!token || !selectedPhone) return;
    setLoadingMessages(true);
    try {
      const rows = await loadSupportMessages(token, selectedPhone);
      setMessages(rows);
      await markSupportThreadRead(token, selectedPhone);
      setThreads((prev) =>
        prev.map((item) =>
          item.thread_id === selectedPhone
            ? { ...item, unread_count: 0, has_unread: false }
            : item,
        ),
      );
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'تعذّر تحميل الرسائل.');
    } finally {
      setLoadingMessages(false);
    }
  }, [token, selectedPhone]);

  useEffect(() => {
    refreshThreads();
    const timer = window.setInterval(refreshThreads, 15000);
    return () => window.clearInterval(timer);
  }, [refreshThreads]);

  useEffect(() => {
    if (!selectedPhone) {
      setMessages([]);
      return;
    }
    refreshMessages();
    const timer = window.setInterval(refreshMessages, 5000);
    return () => window.clearInterval(timer);
  }, [selectedPhone, refreshMessages]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, selectedPhone]);

  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!token || !selectedPhone || !draft.trim() || sending) return;
    setSending(true);
    setError('');
    try {
      const saved = await sendSupportMessage(token, selectedPhone, draft.trim());
      setDraft('');
      setMessages((prev) => [...prev, saved]);
      await refreshThreads();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'تعذّر إرسال الرسالة.');
    } finally {
      setSending(false);
    }
  };

  return (
    <div style={{ maxWidth: 1100 }}>
      <div className="adm-page-header" style={{ marginBottom: 16 }}>
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
            <Headphones size={22} />
          </div>
          <div>
            <h1 style={{ margin: 0 }}>محادثات الدعم</h1>
            <p style={{ margin: '4px 0 0', color: 'var(--adm-muted)', fontSize: '0.9rem' }}>
              راسل المستخدمين وردّ على رسائلهم داخل التطبيق — محادثة ثنائية الاتجاه
            </p>
          </div>
        </div>
        <button
          type="button"
          className="adm-btn adm-btn-ghost"
          onClick={() => {
            refreshThreads();
            if (selectedPhone) refreshMessages();
          }}
          style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
        >
          <RefreshCw size={16} />
          تحديث
        </button>
      </div>

      <p style={{ margin: '0 0 16px', color: 'var(--adm-muted)', fontSize: '0.88rem' }}>
        للإعلانات العامة لجميع المستخدمين استخدم{' '}
        <Link to="/admin/notifications" style={{ color: 'var(--adm-brand)' }}>
          رسائل المستخدمين
        </Link>
        .
      </p>

      {error ? (
        <div className="adm-alert adm-alert-error" style={{ marginBottom: 12 }}>
          {error}
        </div>
      ) : null}

      <div
        className="adm-card"
        style={{
          display: 'grid',
          gridTemplateColumns: 'minmax(260px, 320px) 1fr',
          minHeight: 520,
          padding: 0,
          overflow: 'hidden',
        }}
      >
        <aside
          style={{
            borderLeft: '1px solid var(--adm-border)',
            background: 'var(--adm-surface-2)',
            display: 'flex',
            flexDirection: 'column',
          }}
        >
          <div style={{ padding: '14px 16px', borderBottom: '1px solid var(--adm-border)' }}>
            <strong>المحادثات</strong>
            {loadingThreads ? (
              <span style={{ color: 'var(--adm-muted)', marginRight: 8, fontSize: '0.85rem' }}>
                جاري التحميل...
              </span>
            ) : null}
          </div>
          <div style={{ overflowY: 'auto', flex: 1 }}>
            {!loadingThreads && threads.length === 0 ? (
              <p style={{ padding: 16, color: 'var(--adm-muted)', margin: 0 }}>
                لا توجد محادثات دعم بعد. عندما يرسل مستخدم رسالة من التطبيق ستظهر هنا.
              </p>
            ) : null}
            {threads.map((thread) => {
              const active = thread.thread_id === selectedPhone;
              const title =
                thread.other_party_name || thread.thread_title || thread.thread_id;
              return (
                <button
                  key={thread.thread_id}
                  type="button"
                  onClick={() => setSelectedPhone(thread.thread_id)}
                  style={{
                    width: '100%',
                    textAlign: 'right',
                    border: 'none',
                    borderBottom: '1px solid var(--adm-border)',
                    background: active ? 'var(--adm-surface)' : 'transparent',
                    padding: '12px 14px',
                    cursor: 'pointer',
                  }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
                    <strong style={{ fontSize: '0.95rem' }}>{title}</strong>
                    {thread.has_unread ? (
                      <span
                        style={{
                          background: 'var(--adm-brand)',
                          color: '#fff',
                          borderRadius: 999,
                          minWidth: 20,
                          height: 20,
                          display: 'inline-flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          fontSize: '0.75rem',
                          padding: '0 6px',
                        }}
                      >
                        {thread.unread_count}
                      </span>
                    ) : null}
                  </div>
                  <div
                    style={{
                      color: 'var(--adm-muted)',
                      fontSize: '0.82rem',
                      marginTop: 4,
                      whiteSpace: 'nowrap',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                    }}
                  >
                    {thread.last_message || '—'}
                  </div>
                  <div style={{ color: 'var(--adm-muted)', fontSize: '0.75rem', marginTop: 4 }}>
                    {formatTime(thread.last_at)}
                  </div>
                </button>
              );
            })}
          </div>
        </aside>

        <section style={{ display: 'flex', flexDirection: 'column', minHeight: 520 }}>
          {!selectedPhone ? (
            <div
              style={{
                flex: 1,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                color: 'var(--adm-muted)',
                gap: 10,
                padding: 24,
              }}
            >
              <MessageCircle size={40} strokeWidth={1.5} />
              <p style={{ margin: 0 }}>اختر محادثة من القائمة للرد على المستخدم</p>
            </div>
          ) : (
            <>
              <div
                style={{
                  padding: '14px 18px',
                  borderBottom: '1px solid var(--adm-border)',
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                }}
              >
                <div>
                  <strong>
                    {selectedThread?.other_party_name ||
                      selectedThread?.thread_title ||
                      selectedPhone}
                  </strong>
                  <div style={{ color: 'var(--adm-muted)', fontSize: '0.82rem', marginTop: 2 }}>
                    {selectedPhone}
                  </div>
                </div>
                {loadingMessages ? (
                  <span style={{ color: 'var(--adm-muted)', fontSize: '0.85rem' }}>
                    جاري التحميل...
                  </span>
                ) : null}
              </div>

              <div
                style={{
                  flex: 1,
                  overflowY: 'auto',
                  padding: '16px 18px',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 10,
                  background: 'var(--adm-surface)',
                }}
              >
                {messages.map((msg) => {
                  const fromUser = msg.thread_id === msg.sender_phone;
                  return (
                    <div
                      key={msg.id}
                      style={{
                        alignSelf: fromUser ? 'flex-start' : 'flex-end',
                        maxWidth: '78%',
                        background: fromUser ? 'var(--adm-surface-2)' : 'var(--adm-brand)',
                        color: fromUser ? 'inherit' : '#fff',
                        borderRadius: 14,
                        padding: '10px 14px',
                      }}
                    >
                      {fromUser && msg.sender_name ? (
                        <div style={{ fontSize: '0.78rem', opacity: 0.8, marginBottom: 4 }}>
                          {msg.sender_name}
                        </div>
                      ) : null}
                      <div style={{ whiteSpace: 'pre-wrap', lineHeight: 1.5 }}>{msg.content}</div>
                      <div
                        style={{
                          fontSize: '0.72rem',
                          opacity: 0.75,
                          marginTop: 6,
                          textAlign: 'left',
                        }}
                      >
                        {formatTime(msg.created_at)}
                      </div>
                    </div>
                  );
                })}
                <div ref={messagesEndRef} />
              </div>

              <form
                onSubmit={handleSend}
                style={{
                  padding: '12px 14px',
                  borderTop: '1px solid var(--adm-border)',
                  display: 'flex',
                  gap: 10,
                  alignItems: 'flex-end',
                }}
              >
                <textarea
                  className="adm-input"
                  rows={2}
                  value={draft}
                  onChange={(e) => setDraft(e.target.value)}
                  placeholder="اكتب ردك للمستخدم..."
                  style={{ flex: 1, resize: 'none', minHeight: 52 }}
                />
                <button
                  type="submit"
                  className="adm-btn adm-btn-primary"
                  disabled={sending || !draft.trim()}
                  style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
                >
                  <Send size={16} />
                  إرسال
                </button>
              </form>
            </>
          )}
        </section>
      </div>
    </div>
  );
}
