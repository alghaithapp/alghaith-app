import React, { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  loadCouriers,
  loadDrivers,
  rejectCourierApplication,
  rejectDriverApplication,
  toggleCourierApproval,
  toggleDriverApproval,
} from '../../../admin-api';
import type { CourierSummary, DriverSummary } from '../../../admin-types';
import { useAdminToken, useAuth } from '../../context/AuthContext';
import { OperatorAvatar } from '../operators/operatorUtils';

type OperatorKind = 'driver' | 'courier';

type Props = {
  kind: OperatorKind;
  title: string;
  emptyHint: string;
};

export function PendingOperatorsPage({ kind, title, emptyHint }: Props) {
  const token = useAdminToken();
  const { hasPermission } = useAuth();
  const qc = useQueryClient();
  const [q, setQ] = useState('');
  const [rejectReason, setRejectReason] = useState<Record<string, string>>({});

  const { data = [], isLoading } = useQuery({
    queryKey: [kind === 'driver' ? 'drivers' : 'couriers'],
    queryFn: () => (kind === 'driver' ? loadDrivers(token) : loadCouriers(token)),
    refetchOnMount: 'always',
  });

  const approveMut = useMutation({
    mutationFn: ({ phone, isApproved }: { phone: string; isApproved: boolean }) =>
      kind === 'driver'
        ? toggleDriverApproval(token, phone, isApproved)
        : toggleCourierApproval(token, phone, isApproved),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: [kind === 'driver' ? 'drivers' : 'couriers'] });
    },
  });

  const rejectMut = useMutation({
    mutationFn: ({ phone, message }: { phone: string; message: string }) =>
      kind === 'driver'
        ? rejectDriverApplication(token, phone, message)
        : rejectCourierApplication(token, phone, message),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: [kind === 'driver' ? 'drivers' : 'couriers'] });
    },
  });

  const pending = useMemo(() => {
    let base = data.filter(
      (row) => row.approvalStatus === 'pending' || (!row.isApproved && row.approvalStatus !== 'rejected'),
    );
    const hay = q.trim().toLowerCase();
    if (!hay) return base;
    return base.filter((row) => `${row.phone} ${row.name}`.toLowerCase().includes(hay));
  }, [data, q]);

  const basePath = kind === 'driver' ? '/admin/drivers' : '/admin/couriers';

  return (
    <div>
      <div className="adm-page-header">
        <h2 style={{ margin: 0 }}>{title}</h2>
        <span className="adm-badge adm-badge-warning">{pending.length} معلق</span>
      </div>

      <div className="adm-card" style={{ marginBottom: 16 }}>
        <input
          className="adm-input"
          placeholder="بحث بالاسم أو الهاتف..."
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
      </div>

      {isLoading ? (
        <p style={{ color: 'var(--adm-muted)' }}>جاري التحميل...</p>
      ) : pending.length === 0 ? (
        <div className="adm-card">
          <p style={{ margin: 0, color: 'var(--adm-muted)' }}>{emptyHint}</p>
        </div>
      ) : (
        <div className="adm-table-wrap">
          <table className="adm-table">
            <thead>
              <tr>
                <th>الصورة</th>
                <th>الاسم</th>
                <th>الهاتف</th>
                <th>التفاصيل</th>
                <th>إجراء</th>
              </tr>
            </thead>
            <tbody>
              {pending.map((row) => (
                <OperatorRow
                  key={row.phone}
                  kind={kind}
                  row={row}
                  detailPath={`${basePath}/${encodeURIComponent(row.phone)}`}
                  canApprove={hasPermission('canApprove')}
                  rejectReason={rejectReason[row.phone] ?? ''}
                  onRejectReasonChange={(value) =>
                    setRejectReason((prev) => ({ ...prev, [row.phone]: value }))
                  }
                  onApprove={() => approveMut.mutate({ phone: row.phone, isApproved: true })}
                  onReject={() =>
                    rejectMut.mutate({
                      phone: row.phone,
                      message:
                        rejectReason[row.phone]?.trim() ||
                        (kind === 'driver'
                          ? 'يرجى مراجعة بيانات السائق وإعادة التقديم.'
                          : 'يرجى مراجعة بيانات المندوب وإعادة التقديم.'),
                    })
                  }
                  busy={approveMut.isPending || rejectMut.isPending}
                />
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

function OperatorRow({
  kind,
  row,
  detailPath,
  canApprove,
  rejectReason,
  onRejectReasonChange,
  onApprove,
  onReject,
  busy,
}: {
  kind: OperatorKind;
  row: DriverSummary | CourierSummary;
  detailPath: string;
  canApprove: boolean;
  rejectReason: string;
  onRejectReasonChange: (value: string) => void;
  onApprove: () => void;
  onReject: () => void;
  busy: boolean;
}) {
  const details =
    kind === 'driver'
      ? `${(row as DriverSummary).vehicle || '—'} · ${(row as DriverSummary).plate || '—'} · ${(row as DriverSummary).area || '—'}`
      : `${(row as CourierSummary).homeAddress || '—'}`;

  return (
    <tr>
      <td>
        <OperatorAvatar row={row} />
      </td>
      <td>{row.name || '—'}</td>
      <td dir="ltr">{row.phone}</td>
      <td style={{ fontSize: '0.85rem', color: 'var(--adm-muted)' }}>{details}</td>
      <td>
        <Link to={detailPath} className="adm-btn adm-btn-secondary" style={{ marginBottom: 8, display: 'inline-flex' }}>
          فتح الملف
        </Link>
        {canApprove ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8, minWidth: 180 }}>
            <button type="button" className="adm-btn adm-btn-primary" onClick={onApprove} disabled={busy}>
              موافقة
            </button>
            <input
              className="adm-input"
              placeholder="سبب الرفض (اختياري)"
              value={rejectReason}
              onChange={(e) => onRejectReasonChange(e.target.value)}
            />
            <button type="button" className="adm-btn adm-btn-danger" onClick={onReject} disabled={busy}>
              رفض
            </button>
          </div>
        ) : (
          <span className="adm-badge adm-badge-muted">لا صلاحية</span>
        )}
      </td>
    </tr>
  );
}
