import React, { useEffect, useState } from 'react';
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard,
  Users,
  Store,
  UserPlus,
  Wrench,
  Shield,
  LogOut,
  HeartPulse,
  ChevronDown,
  Pill,
  Stethoscope,
  UserRound,
  HardHat,
  ClipboardCheck,
  Bell,
  Headphones,
  Car,
  Truck,
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';

const mainNav = [
  { to: '/admin', end: true, label: 'الإحصائيات', icon: LayoutDashboard },
  { to: '/admin/moderation', end: true, label: 'الموافقات', icon: ClipboardCheck },
  { to: '/admin/support-chat', label: 'محادثات الدعم', icon: Headphones },
  { to: '/admin/notifications', label: 'رسائل المستخدمين', icon: Bell },
  { to: '/admin/accounts', label: 'الحسابات', icon: Users },
  { to: '/admin/merchants', label: 'التجار', icon: Store },
  { to: '/admin/drivers', label: 'السائقون', icon: Car },
  { to: '/admin/couriers', label: 'المندوبون', icon: Truck },
  { to: '/admin/customers/new', label: 'تسجيل زبون', icon: UserPlus },
  { to: '/admin/merchants/new', label: 'تسجيل تاجر', icon: UserPlus },
  { to: '/admin/admins', label: 'المشرفين', icon: Shield },
];

const professionalsNav = [
  { to: '/admin/professionals', end: true, label: 'نظرة عامة', icon: HardHat },
  { to: '/admin/professionals/list', end: true, label: 'كل المهنيين', icon: Wrench },
  { to: '/admin/professionals/pending', end: true, label: 'طلبات الموافقة', icon: UserRound },
  { to: '/admin/professionals/new', label: 'تسجيل مهني', icon: UserPlus },
];

const healthBeautyNav = [
  { to: '/admin/health-beauty', end: true, label: 'نظرة عامة', icon: HeartPulse },
  { to: '/admin/health-beauty/pharmacies', end: true, label: 'الصيدليات', icon: Pill },
  { to: '/admin/health-beauty/doctors', end: true, label: 'الأطباء', icon: Stethoscope },
  { to: '/admin/health-beauty/doctors/new', label: 'الدكتور', icon: UserRound },
];

export function AdminShell() {
  const { role, setToken } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [professionalsOpen, setProfessionalsOpen] = useState(
    location.pathname.startsWith('/admin/professionals'),
  );
  const [healthOpen, setHealthOpen] = useState(
    location.pathname.startsWith('/admin/health-beauty'),
  );

  useEffect(() => {
    if (location.pathname.startsWith('/admin/professionals')) {
      setProfessionalsOpen(true);
    }
    if (location.pathname.startsWith('/admin/health-beauty')) {
      setHealthOpen(true);
    }
  }, [location.pathname]);

  const logout = () => {
    setToken(null);
    navigate('/admin/login');
  };

  return (
    <div className="admin-v2 adm-shell">
      <aside className="adm-sidebar">
        <div className="adm-sidebar-brand">الغيث — الإدارة</div>
        <nav className="adm-nav">
          {mainNav.map(({ to, end, label, icon: Icon }) => (
            <NavLink key={to} to={to} end={end} className={({ isActive }) => (isActive ? 'active' : '')}>
              <Icon size={18} />
              {label}
            </NavLink>
          ))}

          <div className="adm-nav-group">
            <button
              type="button"
              className={`adm-nav-group-toggle${professionalsOpen ? ' open' : ''}${
                location.pathname.startsWith('/admin/professionals') ? ' active' : ''
              }`}
              onClick={() => setProfessionalsOpen((v) => !v)}
            >
              <span className="adm-nav-group-label">
                <HardHat size={18} />
                المهنيين
              </span>
              <ChevronDown size={16} className="adm-nav-chevron" />
            </button>
            {professionalsOpen && (
              <div className="adm-nav-sub">
                {professionalsNav.map(({ to, end, label, icon: Icon }) => (
                  <NavLink
                    key={to}
                    to={to}
                    end={end}
                    className={({ isActive }) => (isActive ? 'active' : '')}
                  >
                    <Icon size={16} />
                    {label}
                  </NavLink>
                ))}
              </div>
            )}
          </div>

          <div className="adm-nav-group">
            <button
              type="button"
              className={`adm-nav-group-toggle${healthOpen ? ' open' : ''}${
                location.pathname.startsWith('/admin/health-beauty') ? ' active' : ''
              }`}
              onClick={() => setHealthOpen((v) => !v)}
            >
              <span className="adm-nav-group-label">
                <HeartPulse size={18} />
                الصحة والجمال
              </span>
              <ChevronDown size={16} className="adm-nav-chevron" />
            </button>
            {healthOpen && (
              <div className="adm-nav-sub">
                {healthBeautyNav.map(({ to, end, label, icon: Icon }) => (
                  <NavLink
                    key={to}
                    to={to}
                    end={end}
                    className={({ isActive }) => (isActive ? 'active' : '')}
                  >
                    <Icon size={16} />
                    {label}
                  </NavLink>
                ))}
              </div>
            )}
          </div>
        </nav>
        <div style={{ padding: 12, borderTop: '1px solid var(--adm-border)' }}>
          <button type="button" className="adm-btn adm-btn-secondary" style={{ width: '100%' }} onClick={logout}>
            <LogOut size={16} />
            تسجيل الخروج
          </button>
        </div>
      </aside>
      <div className="adm-main">
        <header className="adm-topbar">
          <span style={{ color: 'var(--adm-muted)', fontSize: '0.9rem' }}>لوحة التحكم</span>
          {role && <span className="adm-badge adm-badge-muted">{role}</span>}
        </header>
        <main className="adm-content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
