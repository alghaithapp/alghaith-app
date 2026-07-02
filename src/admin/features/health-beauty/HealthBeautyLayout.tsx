import React from 'react';
import { NavLink, Outlet } from 'react-router-dom';
import { HEALTH_BEAUTY_NAV } from './constants';

export function HealthBeautyLayout() {
  return (
    <div>
      <div className="adm-page-header" style={{ marginBottom: 12 }}>
        <div>
          <h1 style={{ marginBottom: 4 }}>الصحة والجمال</h1>
          <p style={{ margin: 0, color: 'var(--adm-muted)', fontSize: '0.9rem' }}>
            إدارة الصيدليات والأطباء والدكاترة ضمن قسم واحد
          </p>
        </div>
      </div>
      <nav className="adm-section-nav">
        {HEALTH_BEAUTY_NAV.map(({ to, end, label }) => (
          <NavLink key={to} to={to} end={end} className={({ isActive }) => (isActive ? 'active' : '')}>
            {label}
          </NavLink>
        ))}
      </nav>
      <Outlet />
    </div>
  );
}
