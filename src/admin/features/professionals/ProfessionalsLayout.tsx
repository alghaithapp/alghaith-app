import React from 'react';
import { NavLink, Outlet } from 'react-router-dom';
import { PROFESSIONALS_NAV } from './constants';

export function ProfessionalsLayout() {
  return (
    <div>
      <div className="adm-page-header" style={{ marginBottom: 12 }}>
        <div>
          <h1 style={{ marginBottom: 4 }}>المهنيين</h1>
          <p style={{ margin: 0, color: 'var(--adm-muted)', fontSize: '0.9rem' }}>
            إدارة بروفايلات المهنيين، الصور، نماذج الأعمال، والموافقات
          </p>
        </div>
      </div>
      <nav className="adm-section-nav">
        {PROFESSIONALS_NAV.map(({ to, end, label }) => (
          <NavLink key={to} to={to} end={end} className={({ isActive }) => (isActive ? 'active' : '')}>
            {label}
          </NavLink>
        ))}
      </nav>
      <Outlet />
    </div>
  );
}
