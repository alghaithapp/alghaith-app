import React, { useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  deleteAdminAccount,
  deleteDriverAccount,
  loadCouriers,
  loadDrivers,
  rejectCourierApplication,
  rejectDriverApplication,
  suspendAdminAccount,
  toggleCourierApproval,
  toggleDriverApproval,
} from '../../../admin-api';
import type { CourierSummary, DriverSummary } from '../../../admin-types';
import { AdminMediaGallery } from '../../components/AdminAvatar';
import { useAdminToken, useAuth } from '../../context/AuthContext';
import {
  ApprovalStatusBadge,
  OperatorAvatar,
  operatorDocumentItems,
  taxiTypeLabel,
  type OperatorKind,
} from './operatorUtils';

type Props = {
  kind: OperatorKind;
};

export function OperatorDetailPage({ kind }: Props) {
  const { phone = '' } = useParams();
  const operatorPhone = decodeURIComponent(phone);
  const token = useAdminToken();
  const { hasPermission } = useAuth();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [rejectMessage, setRejectMessage] = useState('');
  const isDriver = kind === 'driver';
  const basePath = isDriver ? '/admin/drivers' : '/admin/couriers';
  const queryKey = isDriver ? 'drivers' : 'couriers';

  const { data = [], isLoading, error } = useQuery({
    queryKey: [queryKey],
    queryFn: () => (isDriver ? loadDrivers(token) : loadCouriers(token)),
    refetchOnMount: 'always',
  });

  const row = useMemo(
    () => data.find((item) => item.phone === operatorPhone),
    [data, operatorPhone],
  );

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: [queryKey] });
  };

  const approveMut = useMutation({
    mutationFn: (isApproved: boolean) =>
      isDriver
        ? toggleDriverApproval(token, operatorPhone, isApproved)
        : toggleCourierApproval(token, operatorPhone, isApproved),
    onSuccess: invalidate,
  });

  const rejectMut = useMutation({
    mutationFn: (message: string) =>
      isDriver
        ? rejectDriverApplication(token, operatorPhone, message)
        : rejectCourierApplication(token, operatorPhone, message),
    onSuccess: () => {
      setRejectMessage('');
      invalidate();
    },
  });

  const suspendMut = useMutation({
    mutationFn: (isSuspended: boolean) => suspendAdminAccount(token, operatorPhone, isSuspended),
    onSuccess: invalidate,
  });

  const deleteMut = useMutation({
    mutationFn: () =>
      isDriver
        ? deleteDriverAccount(token, operatorPhone)
        : deleteAdminAccount(token, operatorPhone),
    onSuccess: () => navigate(basePath),
  });

  if (isLoading) return <p style={{ color: 'var(--adm-muted)' }}>جاري التحميل...</p>;
  if (error || !row) {
    return <p className="adm-error">{error instanceof Error ? error.message : 'غير موجود'}</p>;
  }

  const driver = row as DriverSummary;
  const courier = row as CourierSummary;
  const isApproved = row.isApproved || row.approvalStatus === 'approved';

  return (
    <div>
      <div className="adm-page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <OperatorAvatar row={row} />
          <div>
            <h1 style={{ margin: 0 }}>{row.name || operatorPhone}</h1>
            <div style={{ marginTop: 6 }}>
              <ApprovalStatusBadge row={row} />
            </div>
          </div>
        </div>
        <Link to={basePath} className="adm-btn adm-btn-secondary">
          رجوع
        </Link>
      </div>

      <div className="adm-card" style={{ marginBottom: 16 }}>
        <h3 style={{ marginTop: 0 }}>المعلومات</h3>
        <div className="adm-grid adm-grid-2">
          <div>
            <span className="adm-stat-label">الهاتف</span>
            <div dir="ltr">{row.phone}</div>
          </div>
          <div>
            <span className="adm-stat-label">هاتف التواصل</span>
            <div dir="ltr">{row.contactPhone || '—'}</div>
          </div>
          {isDriver ? (
            <>
              <div>
                <span className="adm-stat-label">نوع التكسي</span>
                <div>{taxiTypeLabel(driver.taxiType)}</div>
              </div>
              <div>
                <span className="adm-stat-label">المركبة</span>
                <div>{driver.vehicle || '—'}</div>
              </div>
              <div>
                <span className="adm-stat-label">رقم اللوحة</span>
                <div>{driver.plate || '—'}</div>
              </div>
              <div>
                <span className="adm-stat-label">المنطقة</span>
                <div>{driver.area || '—'}</div>
              </div>
              <div>
                <span className="adm-stat-label">المختار</span>
                <div>{driver.mukhtarName || '—'}</div>
              </div>
            </>
          ) : (
            <>
              <div>
                <span className="adm-stat-label">عنوان السكن</span>
                <div>{courier.homeAddress || '—'}</div>
              </div>
              <div>
                <span className="adm-stat-label">المختار</span>
                <div>{courier.mukhtarName || '—'}</div>
              </div>
            </>
          )}
          <div>
            <span className="adm-stat-label">متاح للعمل</span>
            <div>{row.available ? 'نعم' : 'لا'}</div>
          </div>
        </div>
        {row.rejectionMessageAr ? (
          <div className="adm-alert adm-alert-error" style={{ marginTop: 16 }}>
            <strong>سبب الرفض:</strong> {row.rejectionMessageAr}
          </div>
        ) : null}
      </div>

      <div className="adm-card" style={{ marginBottom: 16 }}>
        <h3 style={{ marginTop: 0 }}>الصور والمستندات</h3>
        <AdminMediaGallery items={operatorDocumentItems(kind, row)} />
      </div>

      {hasPermission('canApprove') && (
        <div className="adm-card">
          <h3 style={{ marginTop: 0 }}>الإجراءات</h3>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 12 }}>
            {!isApproved ? (
              <button
                type="button"
                className="adm-btn adm-btn-primary"
                disabled={approveMut.isPending}
                onClick={() => approveMut.mutate(true)}
              >
                موافقة
              </button>
            ) : (
              <button
                type="button"
                className="adm-btn adm-btn-secondary"
                disabled={approveMut.isPending}
                onClick={() => approveMut.mutate(false)}
              >
                إلغاء الموافقة
              </button>
            )}
            <button
              type="button"
              className="adm-btn adm-btn-secondary"
              disabled={suspendMut.isPending}
              onClick={() => suspendMut.mutate(!row.isSuspended)}
            >
              {row.isSuspended ? 'إلغاء الإيقاف' : 'إيقاف الحساب'}
            </button>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8, maxWidth: 420 }}>
            <input
              className="adm-input"
              placeholder="رسالة الرفض (اختياري)"
              value={rejectMessage}
              onChange={(e) => setRejectMessage(e.target.value)}
            />
            <button
              type="button"
              className="adm-btn adm-btn-danger"
              disabled={rejectMut.isPending}
              onClick={() =>
                rejectMut.mutate(
                  rejectMessage.trim() ||
                    (isDriver
                      ? 'يرجى مراجعة بيانات السائق وإعادة التقديم.'
                      : 'يرجى مراجعة بيانات المندوب وإعادة التقديم.'),
                )
              }
            >
              رفض الطلب
            </button>
          </div>
        </div>
      )}

      {hasPermission('canDelete') && (
        <div className="adm-card" style={{ marginTop: 16, borderColor: 'var(--adm-danger)' }}>
          <h3 style={{ marginTop: 0, color: 'var(--adm-danger)' }}>منطقة خطرة</h3>
          <p style={{ color: 'var(--adm-muted)', marginTop: 0 }}>
            حذف الحساب نهائياً مع ملف {isDriver ? 'السائق' : 'المندوب'}.
          </p>
          <button
            type="button"
            className="adm-btn adm-btn-danger"
            disabled={deleteMut.isPending}
            onClick={() => {
              if (
                window.confirm(
                  `هل أنت متأكد من حذف ${row.name || operatorPhone} نهائياً؟`,
                )
              ) {
                deleteMut.mutate();
              }
            }}
          >
            حذف الحساب
          </button>
        </div>
      )}
    </div>
  );
}
