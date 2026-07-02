import React from 'react';
import { BadgeCheck, Lock, Shield, MessageCircle, Smartphone } from 'lucide-react';
import { Button } from './ui/Button';
import { Input } from './ui/Input';

interface LoginViewProps {
  inputPhone: string;
  otpCode: string;
  otpSent: boolean;
  isSendingCode: boolean;
  isVerifyingCode: boolean;
  bootError: string;
  authChannel: 'sms' | 'whatsapp';
  onInputPhoneChange: (value: string) => void;
  onOtpCodeChange: (value: string) => void;
  onAuthChannelChange: (channel: 'sms' | 'whatsapp') => void;
  onSendCode: (event: React.FormEvent) => Promise<void>;
  onVerifyCode: (event: React.FormEvent) => Promise<void>;
}

export default function LoginView({
  inputPhone,
  otpCode,
  otpSent,
  isSendingCode,
  isVerifyingCode,
  bootError,
  authChannel,
  onInputPhoneChange,
  onOtpCodeChange,
  onAuthChannelChange,
  onSendCode,
  onVerifyCode,
}: LoginViewProps) {
  return (
    <main className="login-split-container">
      {/* Left side: Premium Hero Info (Visible on Desktop) */}
      <section className="login-hero-side">
        <div className="login-hero-content">
          <div className="brand-logo-large">
            <Shield size={36} color="#FFFFFF" />
          </div>
          <h1>الغيث للتوصيل</h1>
          <p>منصة الإدارة والتحكم المركزية لإدارة المندوبين، التجار، وسائقي التكسي وتسيير شحنات المنصة بالكامل.</p>
          
          <div className="login-hero-features">
            <div className="feature-item">
              <span className="feature-dot"></span>
              <span>مراقبة وإدارة حسابات التجار والمندوبين</span>
            </div>
            <div className="feature-item">
              <span className="feature-dot"></span>
              <span>متابعة فورية للطلبات والعمليات المالية</span>
            </div>
            <div className="feature-item">
              <span className="feature-dot"></span>
              <span>تعيين وتعديل صلاحيات المشرفين بدقة</span>
            </div>
          </div>
        </div>
      </section>

      {/* Right side: Modern Login Form */}
      <section className="login-form-side">
        <div className="login-form-wrapper">
          {/* Logo visible only on mobile/tablet */}
          <div className="mobile-only-logo">
            <div style={{
              width: '60px',
              height: '60px',
              borderRadius: '18px',
              background: 'linear-gradient(135deg, var(--brand-primary-dim) 0%, var(--brand-primary-dark) 100%)',
              display: 'grid',
              placeItems: 'center',
              color: '#FFFFFF',
              boxShadow: '0 8px 16px rgba(14, 165, 233, 0.2)',
              marginBottom: '8px'
            }}>
              <Shield size={28} />
            </div>
            <h2>الغيث للتوصيل</h2>
          </div>

          <div className="login-header">
            <h2>تسجيل الدخول للمنصة</h2>
            <p>اختر طريقة تسجيل الدخول:</p>
            <div style={{ display: 'flex', gap: '12px', marginBottom: '12px' }}>
              <button type="button" onClick={() => onAuthChannelChange('sms')} style={{ padding: '8px 16px', background: authChannel === 'sms' ? 'var(--brand-primary)' : 'var(--surface-input)', color: authChannel === 'sms' ? '#fff' : 'var(--text-primary)', border: 'none', borderRadius: '8px' }}>SMS</button>
              <button type="button" onClick={() => onAuthChannelChange('whatsapp')} style={{ padding: '8px 16px', background: authChannel === 'whatsapp' ? 'var(--brand-primary)' : 'var(--surface-input)', color: authChannel === 'whatsapp' ? '#fff' : 'var(--text-primary)', border: 'none', borderRadius: '8px' }}>WhatsApp</button>
              <button type="button" onClick={() => onAuthChannelChange('email')} style={{ padding: '8px 16px', background: authChannel === 'email' ? 'var(--brand-primary)' : 'var(--surface-input)', color: authChannel === 'email' ? '#fff' : 'var(--text-primary)', border: 'none', borderRadius: '8px' }}>Email</button>
            </div>
          </div>

          <form
            className="login-form-element"
            onSubmit={otpSent ? onVerifyCode : onSendCode}
          >
            <div style={{ display: 'flex', flexDirection: 'column', gap: '18px' }}>
              {authChannel === 'email' ? (
                <>
                  <Input
                    label="البريد الإلكتروني"
                    type="email"
                    placeholder="example@domain.com"
                    value={inputPhone}
                    onChange={(e) => onInputPhoneChange(e.target.value)}
                    style={{
                      fontSize: '1.05rem',
                      letterSpacing: '0.5px',
                      textAlign: 'center',
                      padding: '14px',
                      borderRadius: '12px',
                      border: '1px solid var(--border-strong)',
                      background: 'var(--surface-bg)',
                      color: 'var(--text-primary)',
                      transition: 'all 0.3s cubic-bezier(0.16, 1, 0.3, 1)',
                    }}
                  />
                  <Input
                    label="كلمة المرور"
                    type="password"
                    placeholder="••••••••"
                    value={otpCode}
                    onChange={(e) => onOtpCodeChange(e.target.value)}
                    style={{
                      fontSize: '1.05rem',
                      letterSpacing: '0.5px',
                      textAlign: 'center',
                      padding: '14px',
                      borderRadius: '12px',
                      border: '1px solid var(--border-strong)',
                      background: 'var(--surface-bg)',
                      color: 'var(--text-primary)',
                      transition: 'all 0.3s cubic-bezier(0.16, 1, 0.3, 1)',
                    }}
                  />
                </>
              ) : (
                <Input
                  label="رقم هاتف المسؤول"
                  dir="ltr"
                  placeholder="077XXXXXXXX"
                  value={inputPhone}
                  onChange={(event) => onInputPhoneChange(event.target.value)}
                  style={{
                    fontSize: '1.05rem',
                    letterSpacing: '0.5px',
                    textAlign: 'center',
                    padding: '14px',
                    borderRadius: '12px',
                    border: '1px solid var(--border-strong)',
                    background: 'var(--surface-bg)',
                    color: 'var(--text-primary)',
                    transition: 'all 0.3s cubic-bezier(0.16, 1, 0.3, 1)',
                  }}
                />
              )}

              {!otpSent && authChannel !== 'email' ? (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                  <span style={{ fontWeight: 700, fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
                    طريقة استلام رمز التحقق:
                  </span>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                    <button
                      type="button"
                      onClick={() => onAuthChannelChange('whatsapp')}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        gap: '8px',
                        padding: '12px',
                        borderRadius: '12px',
                        border: '1px solid',
                        borderColor: authChannel === 'whatsapp' ? 'var(--brand-primary)' : 'var(--border-strong)',
                        background: authChannel === 'whatsapp' ? 'var(--brand-primary-glow)' : 'var(--surface-input)',
                        color: authChannel === 'whatsapp' ? 'var(--brand-primary)' : 'var(--text-secondary)',
                        fontWeight: 'bold',
                        fontSize: '0.9rem',
                        transition: 'all 0.2s cubic-bezier(0.16, 1, 0.3, 1)',
                      }}
                    >
                      <MessageCircle size={18} />
                      واتساب
                    </button>
                    <button
                      type="button"
                      onClick={() => onAuthChannelChange('sms')}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        gap: '8px',
                        padding: '12px',
                        borderRadius: '12px',
                        border: '1px solid',
                        borderColor: authChannel === 'sms' ? 'var(--brand-primary)' : 'var(--border-strong)',
                        background: authChannel === 'sms' ? 'var(--brand-primary-glow)' : 'var(--surface-input)',
                        color: authChannel === 'sms' ? 'var(--brand-primary)' : 'var(--text-secondary)',
                        fontWeight: 'bold',
                        fontSize: '0.9rem',
                        transition: 'all 0.2s cubic-bezier(0.16, 1, 0.3, 1)',
                      }}
                    >
                      <Smartphone size={18} />
                      رسالة SMS
                    </button>
                  </div>
                </div>
              ) : null}

              {otpSent ? (
                <div className="fade-in">
                  <Input
                    label="رمز التحقق أو كلمة المرور"
                    dir="ltr"
                    placeholder="******"
                    type={inputPhone.includes('07744009992') ? 'password' : 'text'}
                    value={otpCode}
                    onChange={(event) => onOtpCodeChange(event.target.value)}
                    style={{
                      fontSize: '1.1rem',
                      letterSpacing: '4px',
                      textAlign: 'center',
                      padding: '14px',
                      borderRadius: '12px',
                      border: '1px solid var(--brand-primary)',
                      background: 'var(--brand-primary-glow)',
                      color: 'var(--text-primary)',
                      transition: 'all 0.3s cubic-bezier(0.16, 1, 0.3, 1)',
                    }}
                  />
                </div>
              ) : null}
            </div>

            {bootError ? (
              <div style={{
                color: 'var(--error)',
                fontSize: '0.85rem',
                textAlign: 'center',
                padding: '12px 16px',
                background: 'var(--error-bg)',
                border: '1px solid var(--error-border)',
                borderRadius: '10px',
                animation: 'fadeIn 0.3s ease-out',
              }}>
                {bootError}
              </div>
            ) : null}

            <Button
              type="submit"
              className="primary"
              style={{
                width: '100%',
                padding: '14px',
                borderRadius: '12px',
                fontSize: '1rem',
                fontWeight: 'bold',
                boxShadow: '0 8px 20px var(--brand-primary-glow)',
                transition: 'all 0.3s cubic-bezier(0.16, 1, 0.3, 1)',
              }}
              isLoading={isSendingCode || isVerifyingCode}
              icon={otpSent ? <BadgeCheck size={20} /> : <Lock size={18} />}
            >
              {otpSent ? 'تأكيد الرمز والدخول' : 'إرسال الرمز'}
            </Button>
          </form>
        </div>
      </section>
    </main>
  );
}
