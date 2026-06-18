import React from 'react';
import { BadgeCheck, LoaderCircle, Lock, Shield } from 'lucide-react';

interface LoginViewProps {
  inputPhone: string;
  otpCode: string;
  otpSent: boolean;
  isSendingCode: boolean;
  isVerifyingCode: boolean;
  bootError: string;
  onInputPhoneChange: (value: string) => void;
  onOtpCodeChange: (value: string) => void;
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
  onInputPhoneChange,
  onOtpCodeChange,
  onSendCode,
  onVerifyCode,
}: LoginViewProps) {
  return (
    <main className="auth-shell">
      <section className="auth-card">
        <div className="brand-badge">
          <Shield size={30} />
        </div>
        <div className="auth-copy">
          <p className="eyebrow">الغيث · إدارة</p>
          <h1>لوحة إدارة المنصة</h1>
          <p>
            دخول آمن برقم الهاتف لإدارة التجار، مندوبي التوصيل، موافقات بازار
            الغيث، ومتابعة إحصائيات المنصة.
          </p>
        </div>

        <form
          className="auth-form"
          onSubmit={otpSent ? onVerifyCode : onSendCode}
        >
          <label>
            <span>رقم الهاتف</span>
            <input
              dir="ltr"
              placeholder="07744009992 أو +9647744009992"
              value={inputPhone}
              onChange={(event) => onInputPhoneChange(event.target.value)}
            />
          </label>

          {otpSent ? (
            <label>
              <span>رمز التحقق</span>
              <input
                dir="ltr"
                placeholder="000000"
                value={otpCode}
                onChange={(event) => onOtpCodeChange(event.target.value)}
              />
            </label>
          ) : null}

          {bootError ? <div className="message error">{bootError}</div> : null}

          <button
            className="primary-button"
            type="submit"
            disabled={isSendingCode || isVerifyingCode}
          >
            {isSendingCode || isVerifyingCode ? (
              <LoaderCircle className="spin" size={18} />
            ) : otpSent ? (
              <BadgeCheck size={18} />
            ) : (
              <Lock size={18} />
            )}
            <span>{otpSent ? 'تأكيد الدخول' : 'إرسال رمز التحقق'}</span>
          </button>
        </form>
      </section>
    </main>
  );
}
