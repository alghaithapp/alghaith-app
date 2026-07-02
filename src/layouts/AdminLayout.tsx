import React, { useState } from 'react';
import { Outlet, useNavigate, useLocation } from 'react-router-dom';
import Sidebar from '../components/Sidebar';
import { Search, Bell } from 'lucide-react';
import type { AdminAccountSummary } from '../admin-types';

interface AdminLayoutProps {
  onLogout: () => void;
  adminAccount: AdminAccountSummary;
}

export function AdminLayout({ onLogout, adminAccount }: AdminLayoutProps) {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const location = useLocation();
  
  // Minimal view logic based on path
  const getPageMeta = () => {
    if (location.pathname.includes('merchants')) return { title: 'إدارة التجار', showSearch: true };
    if (location.pathname.includes('couriers')) return { title: 'إدارة المندوبين', showSearch: true };
    if (location.pathname.includes('drivers')) return { title: 'سائقو التكسي', showSearch: true };
    if (location.pathname.includes('accounts')) return { title: 'المستخدمون', showSearch: true };
    if (location.pathname.includes('settings')) return { title: 'الإعدادات', showSearch: false };
    return { title: 'نظرة عامة', showSearch: false };
  };

  const meta = getPageMeta();

  return (
    <div className="admin-shell">
      <div className="admin-layout">
        <Sidebar 
          currentView={location.pathname.split('/').pop() || 'dashboard'}
          onChangeView={() => {}} // React Router handles this now
          onLogout={onLogout}
          adminName={adminAccount?.displayName || 'المدير'}
          sidebarOpen={sidebarOpen}
          setSidebarOpen={setSidebarOpen}
        />

        {sidebarOpen && (
          <div className="sidebar-overlay open" onClick={() => setSidebarOpen(false)} />
        )}

        <main className="main-content">
          <header className="topbar" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-strong)', paddingBottom: '20px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
              <button 
                className="mobile-menu-button" 
                type="button" 
                onClick={() => setSidebarOpen(true)}
              >
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><path d="M3 12h18M3 6h18M3 18h18"/></svg>
              </button>
              <div>
                <h1 style={{ fontSize: '1.65rem', fontWeight: 800, background: 'linear-gradient(135deg, #fff 0%, #cbd5e1 100%)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>
                  {meta.title}
                </h1>
              </div>
            </div>

            <div style={{ display: 'flex', gap: '16px', alignItems: 'center' }}>
              <button
                type="button"
                style={{
                  background: 'var(--surface-elevated)',
                  border: '1px solid var(--border-strong)',
                  width: '40px',
                  height: '40px',
                  borderRadius: '12px',
                  display: 'grid',
                  placeItems: 'center',
                  cursor: 'pointer',
                  color: 'var(--text-secondary)'
                }}
              >
                <Bell size={18} />
              </button>
            </div>
          </header>

          {/* Child pages injected here */}
          <Outlet />

        </main>
      </div>
    </div>
  );
}
