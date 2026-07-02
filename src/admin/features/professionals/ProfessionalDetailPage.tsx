import React, { useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  deleteAdminAccount,
  loadProfessionalDetails,
  rejectMerchantApplication,
  toggleMerchantApproval,
  toggleMerchantFreeze,
} from '../../../admin-api';
import { useAdminToken, useAuth } from '../../context/AuthContext';

export function ProfessionalDetailPage() {
  const { phone = '' } = useParams();
  const professionalPhone = decodeURIComponent(phone);
  const token = useAdminToken();
  const { hasPermission } = useAuth();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [tab, setTab] = useState<'info' | 'gallery' | 'approval'>('info');
  const [rejectReason, setRejectReason] = useState('');

  const { data, isLoading, error } = useQuery({
    queryKey: ['professional-details', professionalPhone],
    queryFn: () => loadProfessionalDetails(token, professionalPhone),
    enabled: Boolean(professionalPhone),
  });

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ['professional-details', professionalPhone] });
    qc.invalidateQueries({ queryKey: ['professionals'] });
  };

  const approveMut = useMutation({
    mutationFn: (approved: boolean) => toggleMerchantApproval(token, professionalPhone, approved),
    onSuccess: invalidate,
  });

  const freezeMut = useMutation({
    mutationFn: (frozen: boolean) => toggleMerchantFreeze(token, professionalPhone, frozen),
    onSuccess: invalidate,
  });

  const rejectMut = useMutation({
    mutationFn: () =>
      rejectMerchantApplication(
        token,
        professionalPhone,
        rejectReason.trim() || 'تم رفض طلب البروفايل من الإدارة.',
      ),
    onSuccess: () => {
      setRejectReason('');
      invalidate();
      setTab('approval');
    },
  });

  const deleteMut = useMutation({
    mutationFn: () => deleteAdminAccount(token, professionalPhone),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['professionals'] });
      navigate('/admin/professionals/list');
    },
  });

  if (isLoading) return <p style={{ color: 'var(--adm-muted)' }}>جاري التحميل...</p>;
  if (error || !data) {
    return <p className="adm-error">{error instanceof Error ? error.message : 'غير موجود'}</p>;
  }

  const m = data.merchant;
  const p = data.professional;
  const isApproved = m.isApproved ?? m.approvalStatus === 'approved';

  const handleDelete = () => {
    if (!window.confirm(`حذف حساب المهني ${m.storeName || professionalPhone} نهائياً؟`)) return;
    deleteMut.mutate();
  };

  return (
    <div>
      <div className="adm-page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          {p.profileImageUrl ? (
            <img src={p.profileImageUrl} alt="" className="adm-avatar adm-avatar-lg" />
          ) : (
            <div className="adm-avatar adm-avatar-lg adm-avatar-empty">—</div>
          )}
          <div>
            <h1 style={{ margin: 0 }}>{m.storeName || m.fullName || professionalPhone}</h1>
            <p style={{ margin: '4px 0 0', color: 'var(--adm-muted)' }}>{p.categoryLabel}</p>
          </div>
        </div>
        <button type="button" className="adm-btn adm-btn-secondary" onClick={() => navigate(-1)}>
          رجوع
        </button>
      </div>

      <div className="adm-tabs">
        <button type="button" className={`adm-tab ${tab === 'info' ? 'active' : ''}`} onClick={() => setTab('info')}>
          المعلومات
        </button>
        <button type="button" className={`adm-tab ${tab === 'gallery' ? 'active' : ''}`} onClick={() => setTab('gallery')}>
          الصور والأعمال ({p.workSampleUrls.length})
        </button>
        <button type="button" className={`adm-tab ${tab === 'approval' ? 'active' : ''}`} onClick={() => setTab('approval')}>
          الموافقة
        </button>
      </div>

      {tab === 'info' && (
        <div className="adm-card">
          <div className="adm-grid adm-grid-2" style={{ marginBottom: 20 }}>
            <div><span className="adm-stat-label">الهاتف</span><div dir="ltr">{m.phone}</div></div>
            <div><span className="adm-stat-label">هاتف التواصل</span><div dir="ltr">{p.contactPhone || '—'}</div></div>
            <div><span className="adm-stat-label">واتساب</span><div dir="ltr">{p.whatsapp || '—'}</div></div>
            <div><span className="adm-stat-label">التخصص</span><div>{p.categoryLabel}</div></div>
            <div><span className="adm-stat-label">العنوان</span><div>{m.address || '—'}</div></div>
            <div><span className="adm-stat-label">الدوام</span><div>{p.openTime && p.closeTime ? `${p.openTime} — ${p.closeTime}` : '—'}</div></div>
            <div>
              <span className="adm-stat-label">إظهار الهاتف للزبائن</span>
              <div>{p.showPhoneToCustomers ? 'نعم' : 'لا'}</div>
            </div>
            <div>
              <span className="adm-stat-label">إظهار واتساب للزبائن</span>
              <div>{p.showWhatsAppToCustomers ? 'نعم' : 'لا'}</div>
            </div>
            <div>
              <span className="adm-stat-label">الموافقة</span>
              <div>
                {isApproved ? (
                  <span className="adm-badge adm-badge-success">معتمد</span>
                ) : m.approvalStatus === 'rejected' ? (
                  <span className="adm-badge adm-badge-danger">مرفوض</span>
                ) : (
                  <span className="adm-badge adm-badge-warning">معلق</span>
                )}
              </div>
            </div>
            <div>
              <span className="adm-stat-label">التجميد</span>
              <div>{m.isFrozen ? <span className="adm-badge adm-badge-danger">مجمّد</span> : <span className="adm-badge adm-badge-success">نشط</span>}</div>
            </div>
          </div>
          {p.description && (
            <div style={{ marginBottom: 20 }}>
              <span className="adm-stat-label">الوصف</span>
              <p style={{ margin: '8px 0 0', lineHeight: 1.6 }}>{p.description}</p>
            </div>
          )}
          {hasPermission('canApprove') && (
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <button type="button" className="adm-btn adm-btn-primary" onClick={() => approveMut.mutate(!isApproved)}>
                {isApproved ? 'إلغاء الموافقة' : 'موافقة على البروفايل'}
              </button>
              <button type="button" className="adm-btn adm-btn-secondary" onClick={() => freezeMut.mutate(!m.isFrozen)}>
                {m.isFrozen ? 'إلغاء التجميد' : 'تعليق / تجميد'}
              </button>
              {hasPermission('canDelete') && (
                <button type="button" className="adm-btn adm-btn-danger" onClick={handleDelete} disabled={deleteMut.isPending}>
                  حذف الحساب
                </button>
              )}
            </div>
          )}
        </div>
      )}

      {tab === 'gallery' && (
        <div className="adm-card">
          <h3 style={{ marginTop: 0 }}>صورة البروفايل</h3>
          {p.profileImageUrl ? (
            <img src={p.profileImageUrl} alt="بروفايل" className="adm-media-preview" />
          ) : (
            <p style={{ color: 'var(--adm-muted)' }}>لا توجد صورة بروفايل.</p>
          )}
          <h3>نماذج الأعمال</h3>
          {p.workSampleUrls.length === 0 ? (
            <p style={{ color: 'var(--adm-muted)' }}>لم يُرفع نماذج أعمال بعد.</p>
          ) : (
            <div className="adm-media-grid">
              {p.workSampleUrls.map((url) => (
                <a key={url} href={url} target="_blank" rel="noreferrer" className="adm-media-thumb-wrap">
                  <img src={url} alt="نموذج عمل" className="adm-media-thumb" />
                </a>
              ))}
            </div>
          )}
        </div>
      )}

      {tab === 'approval' && (
        <div className="adm-card">
          <div className="adm-grid adm-grid-2" style={{ marginBottom: 20 }}>
            <div>
              <span className="adm-stat-label">حالة الطلب</span>
              <div style={{ marginTop: 8 }}>
                {isApproved ? (
                  <span className="adm-badge adm-badge-success">معتمد ويظهر للزبائن</span>
                ) : m.approvalStatus === 'rejected' ? (
                  <span className="adm-badge adm-badge-danger">مرفوض</span>
                ) : (
                  <span className="adm-badge adm-badge-warning">بانتظار مراجعة الإدارة</span>
                )}
              </div>
            </div>
            <div>
              <span className="adm-stat-label">رسالة الرفض</span>
              <div>{p.rejectionMessageAr || '—'}</div>
            </div>
          </div>

          {hasPermission('canApprove') && (
            <>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 20 }}>
                <button type="button" className="adm-btn adm-btn-primary" onClick={() => approveMut.mutate(true)} disabled={isApproved}>
                  قبول البروفايل
                </button>
                <button type="button" className="adm-btn adm-btn-secondary" onClick={() => approveMut.mutate(false)} disabled={!isApproved}>
                  إلغاء الموافقة
                </button>
              </div>
              <div className="adm-field">
                <label className="adm-label">سبب الرفض (يُرسل للمهني)</label>
                <textarea
                  className="adm-textarea"
                  rows={3}
                  value={rejectReason}
                  onChange={(e) => setRejectReason(e.target.value)}
                  placeholder="مثال: الصور غير واضحة أو البيانات ناقصة..."
                />
              </div>
              <button
                type="button"
                className="adm-btn adm-btn-danger"
                onClick={() => rejectMut.mutate()}
                disabled={rejectMut.isPending}
              >
                رفض الطلب
              </button>
            </>
          )}
        </div>
      )}
    </div>
  );
}
