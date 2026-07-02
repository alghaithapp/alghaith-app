import React from 'react';
import { NavLink, Outlet } from 'react-router-dom';
import { MODERATION_NAV } from './constants';

export function ModerationLayout() {
  return (
    <div>
      <div className="adm-page-header" style={{ marginBottom: 12 }}>
        <div>
          <h1 style={{ marginBottom: 4 }}>الموافقات</h1>
          <p style={{ margin: 0, color: 'var(--adm-muted)', fontSize: '0.9rem' }}>
            مراجعة الحسابات والمحتوى قبل ظهوره للزبائن — مع إشعار تلقائي عند القرار
          </p>
        </div>
      </div>
      <nav className="adm-section-nav" style={{ flexWrap: 'wrap' }}>
        {MODERATION_NAV.map(({ to, end, label }) => (
          <NavLink key={to} to={to} end={end} className={({ isActive }) => (isActive ? 'active' : '')}>
            {label}
          </NavLink>
        ))}
      </nav>
      <Outlet />
    </div>
  );
}
