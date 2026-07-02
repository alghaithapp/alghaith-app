import React, { useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { loadProfessionals } from '../../../admin-api';
import { PROFESSIONAL_CATEGORIES } from '../../../admin-types';
import { useAdminToken } from '../../context/AuthContext';
import { isMerchantAccountPending } from '../../utils/moderation';

export function ProfessionalsOverviewPage() {
  const token = useAdminToken();
  const { data = [], isLoading } = useQuery({
    queryKey: ['professionals'],
    queryFn: () => loadProfessionals(token),
    refetchOnMount: 'always',
  });

  const pending = useMemo(
    () => data.filter((p) => isMerchantAccountPending(p)),
    [data],
  );
  const approved = useMemo(() => data.filter((p) => p.isApproved), [data]);
  const frozen = useMemo(() => data.filter((p) => p.isFrozen), [data]);

  const byCategory = useMemo(() => {
    const map: Record<string, number> = {};
    for (const cat of PROFESSIONAL_CATEGORIES) map[cat.id] = 0;
    for (const row of data) {
      const id = row.professionalCategoryId || '_other';
      map[id] = (map[id] || 0) + 1;
    }
    return map;
  }, [data]);

  return (
    <div>
      <div className="adm-grid adm-grid-3" style={{ marginBottom: 24 }}>
        <div className="adm-card">
          <div className="adm-stat-value">{data.length}</div>
          <div className="adm-stat-label">إجمالي المهنيين</div>
        </div>
        <div className="adm-card">
          <div className="adm-stat-value">{pending.length}</div>
          <div className="adm-stat-label">بانتظار الموافقة</div>
        </div>
        <div className="adm-card">
          <div className="adm-stat-value">{approved.length}</div>
          <div className="adm-stat-label">معتمدون</div>
        </div>
        <div className="adm-card">
          <div className="adm-stat-value">{frozen.length}</div>
          <div className="adm-stat-label">مجمّدون</div>
        </div>
      </div>

      <div className="adm-grid adm-grid-2" style={{ marginBottom: 24 }}>
        <div className="adm-card">
          <h3 style={{ marginTop: 0 }}>إجراءات سريعة</h3>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <Link to="/admin/professionals/pending" className="adm-btn adm-btn-primary">
              طلبات الموافقة ({pending.length})
            </Link>
            <Link to="/admin/professionals/list" className="adm-btn adm-btn-secondary">
              كل المهنيين
            </Link>
            <Link to="/admin/professionals/new" className="adm-btn adm-btn-secondary">
              تسجيل مهني جديد
            </Link>
          </div>
        </div>
        <div className="adm-card">
          <h3 style={{ marginTop: 0 }}>أكثر التخصصات</h3>
          {PROFESSIONAL_CATEGORIES.slice(0, 6).map((cat) => (
            <div key={cat.id} style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
              <span>{cat.label}</span>
              <span className="adm-badge adm-badge-muted">{byCategory[cat.id] ?? 0}</span>
            </div>
          ))}
        </div>
      </div>

      {isLoading && <p style={{ color: 'var(--adm-muted)' }}>جاري التحميل...</p>}
    </div>
  );
}
