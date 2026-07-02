import React, { useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { loadMerchants } from '../../../admin-api';
import { useAdminToken } from '../../context/AuthContext';
import {
  HEALTH_BEAUTY_CATEGORIES,
  isHealthBeautyMerchant,
  matchesHealthBeautySubCategory,
} from './constants';

export function HealthBeautyOverviewPage() {
  const token = useAdminToken();
  const { data = [], isLoading } = useQuery({
    queryKey: ['merchants'],
    queryFn: () => loadMerchants(token),
  });

  const healthMerchants = useMemo(
    () => data.filter(isHealthBeautyMerchant),
    [data],
  );

  const counts = useMemo(() => {
    const map: Record<string, number> = {};
    for (const cat of HEALTH_BEAUTY_CATEGORIES) {
      map[cat.id] = healthMerchants.filter((m) =>
        matchesHealthBeautySubCategory(m, cat.id),
      ).length;
    }
    return map;
  }, [healthMerchants]);

  return (
    <div>
      <div className="adm-grid adm-grid-3" style={{ marginBottom: 24 }}>
        <div className="adm-card">
          <div className="adm-stat-value">{healthMerchants.length}</div>
          <div className="adm-stat-label">إجمالي الصحة والجمال</div>
        </div>
        {HEALTH_BEAUTY_CATEGORIES.map((cat) => (
          <div key={cat.id} className="adm-card">
            <div className="adm-stat-value">{counts[cat.id] ?? 0}</div>
            <div className="adm-stat-label">{cat.label}</div>
          </div>
        ))}
      </div>

      <div className="adm-grid adm-grid-2">
        {HEALTH_BEAUTY_CATEGORIES.map((cat) => (
          <div key={cat.id} className="adm-card">
            <h3 style={{ marginTop: 0 }}>{cat.label}</h3>
            <p style={{ color: 'var(--adm-muted)', fontSize: '0.9rem' }}>
              {counts[cat.id] ?? 0} مسجّل
            </p>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <Link
                to={cat.id === 'صيدلية' ? '/admin/health-beauty/pharmacies' : '/admin/health-beauty/doctors'}
                className="adm-btn adm-btn-secondary"
              >
                عرض القائمة
              </Link>
              <Link to={cat.registerPath} className="adm-btn adm-btn-primary">
                {cat.registerLabel}
              </Link>
            </div>
          </div>
        ))}
      </div>

      {isLoading && <p style={{ color: 'var(--adm-muted)', marginTop: 16 }}>جاري التحميل...</p>}
    </div>
  );
}
