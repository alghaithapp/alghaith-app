import React, { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { loadMerchants } from '../../../admin-api';
import { DOCTOR_SPECIALTIES } from '../../../admin-types';
import type { MerchantSummary } from '../../../admin-types';
import { useAdminToken } from '../../context/AuthContext';
import { MerchantQuickActions } from '../../components/MerchantQuickActions';
import { AdminAvatar, pickMerchantAvatarUrl } from '../../components/AdminAvatar';
import {
  type HealthBeautySubCategoryId,
  isPharmacyMerchant,
  matchesHealthBeautySubCategory,
} from './constants';

type Props = {
  title: string;
  subCategoryId: HealthBeautySubCategoryId;
  registerPath: string;
  registerLabel: string;
  emptyHint: string;
};

export function HealthBeautyMerchantsPage({
  title,
  subCategoryId,
  registerPath,
  registerLabel,
  emptyHint,
}: Props) {
  const token = useAdminToken();
  const [q, setQ] = useState('');
  const [specialtyFilter, setSpecialtyFilter] = useState('');
  const isDoctorsPage = subCategoryId === 'أطباء وعيادات';
  const { data = [], isLoading } = useQuery({
    queryKey: ['merchants'],
    queryFn: () => loadMerchants(token),
    refetchOnMount: 'always',
  });

  const filtered = useMemo(() => {
    const base = data.filter((m) => {
      if (subCategoryId === 'صيدلية') {
        return isPharmacyMerchant(m);
      }
      if (m.primaryServiceId !== 'beauty') return false;
      return matchesHealthBeautySubCategory(m, subCategoryId);
    });
    const withSpecialty = specialtyFilter
      ? base.filter((m) => (m.specialty || '').trim() === specialtyFilter)
      : base;
    const hay = q.trim().toLowerCase();
    if (!hay) return withSpecialty;
    return withSpecialty.filter((m) =>
      `${m.phone} ${m.storeName} ${m.fullName} ${m.serviceSubCategory ?? ''} ${m.specialty ?? ''}`
        .toLowerCase()
        .includes(hay),
    );
  }, [data, q, subCategoryId, specialtyFilter]);

  return (
    <div>
      <div className="adm-page-header">
        <h2 style={{ margin: 0 }}>{title}</h2>
        <Link to={registerPath} className="adm-btn adm-btn-primary">
          + {registerLabel}
        </Link>
      </div>
      <div className={`adm-card${isDoctorsPage ? ' adm-grid adm-grid-2' : ''}`} style={{ marginBottom: 16 }}>
        <input
          className="adm-input"
          placeholder="بحث بالاسم أو الهاتف..."
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
        {isDoctorsPage && (
          <select
            className="adm-select"
            value={specialtyFilter}
            onChange={(e) => setSpecialtyFilter(e.target.value)}
          >
            <option value="">كل التخصصات</option>
            {DOCTOR_SPECIALTIES.map((item) => (
              <option key={item.id} value={item.id}>
                {item.labelAr}
              </option>
            ))}
          </select>
        )}
      </div>
      {isLoading ? (
        <p style={{ color: 'var(--adm-muted)' }}>جاري التحميل...</p>
      ) : filtered.length === 0 ? (
        <div className="adm-card">
          <p style={{ margin: 0, color: 'var(--adm-muted)' }}>{emptyHint}</p>
          <Link to={registerPath} className="adm-btn adm-btn-primary" style={{ marginTop: 12 }}>
            {registerLabel}
          </Link>
        </div>
      ) : (
        <MerchantsTable rows={filtered} showSpecialty={isDoctorsPage} />
      )}
    </div>
  );
}

function MerchantsTable({
  rows,
  showSpecialty,
}: {
  rows: MerchantSummary[];
  showSpecialty: boolean;
}) {
  return (
    <div className="adm-table-wrap">
      <table className="adm-table">
        <thead>
          <tr>
            <th>الصورة</th>
            <th>الاسم</th>
            <th>الهاتف</th>
            {showSpecialty ? <th>التخصص</th> : null}
            <th>التصنيف</th>
            <th>الموافقة</th>
            <th>الطلبات</th>
            <th>إجراءات</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {rows.map((m) => (
            <tr key={m.phone}>
              <td>
                <AdminAvatar src={pickMerchantAvatarUrl(m)} alt={m.storeName || m.fullName || ''} />
              </td>
              <td>{m.storeName || m.fullName || '—'}</td>
              <td dir="ltr">{m.phone}</td>
              {showSpecialty ? <td>{m.specialty || '—'}</td> : null}
              <td>{m.serviceSubCategory || '—'}</td>
              <td>
                {m.isApproved ? (
                  <span className="adm-badge adm-badge-success">معتمد</span>
                ) : m.approvalStatus === 'rejected' ? (
                  <span className="adm-badge adm-badge-danger">مرفوض</span>
                ) : (
                  <Link
                    to={`/admin/merchants/${encodeURIComponent(m.phone)}`}
                    className="adm-badge adm-badge-warning"
                    style={{ textDecoration: 'none' }}
                  >
                    معلق — مراجعة
                  </Link>
                )}
              </td>
              <td>{m.totalOrders ?? 0}</td>
              <td>
                <MerchantQuickActions
                  phone={m.phone}
                  label={m.storeName || m.fullName || m.phone}
                  isFrozen={m.isFrozen}
                  invalidateKeys={['merchants']}
                />
              </td>
              <td>
                <Link
                  to={`/admin/merchants/${encodeURIComponent(m.phone)}`}
                  className="adm-btn adm-btn-secondary"
                >
                  إدارة
                </Link>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
