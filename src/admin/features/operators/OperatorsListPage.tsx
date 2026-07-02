import React, { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { loadCouriers, loadDrivers } from '../../../admin-api';
import type { CourierSummary, DriverSummary } from '../../../admin-types';
import { useAdminToken } from '../../context/AuthContext';
import {
  ApprovalStatusBadge,
  OperatorAvatar,
  type OperatorFilter,
  type OperatorKind,
  matchesOperatorFilter,
} from './operatorUtils';

const FILTERS: Array<{ key: OperatorFilter; label: string }> = [
  { key: 'all', label: 'الكل' },
  { key: 'pending', label: 'معلق' },
  { key: 'approved', label: 'معتمد' },
  { key: 'rejected', label: 'مرفوض' },
  { key: 'suspended', label: 'موقوف' },
];

type Props = {
  kind: OperatorKind;
};

export function OperatorsListPage({ kind }: Props) {
  const token = useAdminToken();
  const [q, setQ] = useState('');
  const [filter, setFilter] = useState<OperatorFilter>('all');
  const isDriver = kind === 'driver';

  const { data = [], isLoading } = useQuery({
    queryKey: [isDriver ? 'drivers' : 'couriers'],
    queryFn: () => (isDriver ? loadDrivers(token) : loadCouriers(token)),
    refetchOnMount: 'always',
  });

  const filtered = useMemo(() => {
    let base = data.filter((row) => matchesOperatorFilter(row, filter));
    const hay = q.trim().toLowerCase();
    if (!hay) return base;
    return base.filter((row) => {
      const driver = row as DriverSummary;
      const courier = row as CourierSummary;
      const extra = isDriver
        ? `${driver.vehicle} ${driver.plate} ${driver.area}`
        : `${courier.homeAddress}`;
      return `${row.phone} ${row.name} ${extra}`.toLowerCase().includes(hay);
    });
  }, [data, filter, q, isDriver]);

  const basePath = isDriver ? '/admin/drivers' : '/admin/couriers';
  const title = isDriver ? 'السائقون' : 'المندوبون';
  const registerLabel = isDriver ? 'تسجيل سائق' : 'تسجيل مندوب';

  return (
    <div>
      <div className="adm-page-header">
        <h1>{title}</h1>
        <Link to={`${basePath}/new`} className="adm-btn adm-btn-primary">
          + {registerLabel}
        </Link>
      </div>

      <div className="adm-card" style={{ marginBottom: 16 }}>
        <p style={{ margin: '0 0 12px', color: 'var(--adm-muted)', lineHeight: 1.7 }}>
          إدارة كاملة لكل {isDriver ? 'السائقين' : 'المندوبين'} — معلقين ومعتمدين ومرفوضين.
          للمعلقين فقط يمكنك أيضاً استخدام{' '}
          <Link to={`/admin/moderation/${kind === 'driver' ? 'drivers' : 'couriers'}`}>
            قسم الموافقات
          </Link>
          .
        </p>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 12 }}>
          {FILTERS.map((item) => (
            <button
              key={item.key}
              type="button"
              className={`adm-btn ${filter === item.key ? 'adm-btn-primary' : 'adm-btn-secondary'}`}
              onClick={() => setFilter(item.key)}
            >
              {item.label}
            </button>
          ))}
        </div>
        <input
          className="adm-input"
          placeholder="بحث بالاسم أو الهاتف..."
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
      </div>

      {isLoading ? (
        <p style={{ color: 'var(--adm-muted)' }}>جاري التحميل...</p>
      ) : filtered.length === 0 ? (
        <div className="adm-card">
          <p style={{ margin: 0, color: 'var(--adm-muted)' }}>لا توجد نتائج.</p>
        </div>
      ) : (
        <div className="adm-table-wrap">
          <table className="adm-table">
            <thead>
              <tr>
                <th>الصورة</th>
                <th>الاسم</th>
                <th>الهاتف</th>
                <th>{isDriver ? 'المركبة / اللوحة' : 'العنوان'}</th>
                <th>الحالة</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((row) => (
                <tr key={row.phone}>
                  <td>
                    <OperatorAvatar row={row} />
                  </td>
                  <td>{row.name || '—'}</td>
                  <td dir="ltr">{row.phone}</td>
                  <td style={{ fontSize: '0.88rem', color: 'var(--adm-muted)' }}>
                    {isDriver ? (
                      <>
                        {(row as DriverSummary).vehicle || '—'} · {(row as DriverSummary).plate || '—'}
                      </>
                    ) : (
                      (row as CourierSummary).homeAddress || '—'
                    )}
                  </td>
                  <td>
                    <ApprovalStatusBadge row={row} />
                  </td>
                  <td>
                    <Link
                      to={`${basePath}/${encodeURIComponent(row.phone)}`}
                      className="adm-btn adm-btn-secondary"
                    >
                      التفاصيل
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
