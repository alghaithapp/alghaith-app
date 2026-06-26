import React from 'react';
import {
  BarChart3,
  Bike,
  Grid3x3,
  LogOut,
  Shield,
  Smartphone,
  Store,
  Users,
  Car,
  UserCheck,
  ChevronRight,
  Wrench,
} from 'lucide-react';
import type {
  AdminView,
  CourierSummary,
  MerchantSummary,
} from '../admin-types';

interface SidebarProps {
  view: AdminView;
  phoneNumber: string;
  pendingMerchantQueue: MerchantSummary[];
  pendingCourierQueue: CourierSummary[];
  approvalQueue: MerchantSummary[];
  pendingDriverCount: number;
  sidebarOpen: boolean;
  onSwitchView: (view: AdminView) => void;
  onLogout: () => void;
  onCloseSidebar: () => void;
}

interface NavButtonProps {
  isActive: boolean;
  onClick: () => void;
  iconClass: string;
  icon: React.ReactNode;
  label: string;
  badge?: number;
}

function NavButton({ isActive, onClick, iconClass, icon, label, badge }: NavButtonProps) {
  return (
    <button
      className={isActive ? 'nav-item active' : 'nav-item'}
      onClick={onClick}
      type="button"
    >
      <span className={`nav-item-icon ${iconClass}`}>{icon}</span>
      <span>{label}</span>
      {badge != null && badge > 0 ? (
        <span className="nav-badge">{badge}</span>
      ) : null}
    </button>
  );
}

export default function Sidebar({
  view,
  phoneNumber,
  pendingMerchantQueue,
  pendingCourierQueue,
  approvalQueue,
  pendingDriverCount,
  sidebarOpen,
  onSwitchView,
  onLogout,
  onCloseSidebar,
}: SidebarProps) {
  const totalPending =
    pendingMerchantQueue.length + pendingCourierQueue.length + pendingDriverCount;

  return (
    <>
      <div
        className={sidebarOpen ? 'sidebar-overlay open' : 'sidebar-overlay'}
        onClick={onCloseSidebar}
        role="presentation"
      />
      <aside className={sidebarOpen ? 'sidebar open' : 'sidebar'}>

        {/* Brand */}
        <div className="sidebar-header">
          <div className="brand-badge small">
            <Shield size={20} />
          </div>
          <div>
            <p className="eyebrow">الغيث</p>
            <h2>لوحة الإدارة</h2>
          </div>
        </div>

        {/* Admin identity */}
        <div className="admin-identity">
          <span>مسجّل الدخول كمشرف</span>
          <strong dir="ltr">{phoneNumber}</strong>
        </div>

        {/* MAIN NAV */}
        <div className="sidebar-nav-section">
          <span className="sidebar-nav-label">الرئيسية</span>
          <nav className="sidebar-nav">
            <NavButton
              isActive={view === 'dashboard'}
              onClick={() => onSwitchView('dashboard')}
              iconClass="nav-icon-dashboard"
              icon={<BarChart3 size={16} />}
              label="الملخص العام"
              badge={totalPending > 0 ? totalPending : undefined}
            />
          </nav>
        </div>

        <div className="sidebar-divider" />

        {/* USERS */}
        <div className="sidebar-nav-section">
          <span className="sidebar-nav-label">إدارة المستخدمين</span>
          <nav className="sidebar-nav">
            <NavButton
              isActive={view === 'accounts'}
              onClick={() => onSwitchView('accounts')}
              iconClass="nav-icon-customer"
              icon={<Users size={16} />}
              label="جميع الحسابات"
            />
            <NavButton
              isActive={view === 'merchants'}
              onClick={() => onSwitchView('merchants')}
              iconClass="nav-icon-merchant"
              icon={<Store size={16} />}
              label="التجار والمهنيون"
              badge={pendingMerchantQueue.length || undefined}
            />
            <NavButton
              isActive={view === 'couriers'}
              onClick={() => onSwitchView('couriers')}
              iconClass="nav-icon-courier"
              icon={<Bike size={16} />}
              label="مندوبو التوصيل"
              badge={pendingCourierQueue.length || undefined}
            />
            <NavButton
              isActive={view === 'drivers'}
              onClick={() => onSwitchView('drivers')}
              iconClass="nav-icon-driver"
              icon={<Car size={16} />}
              label="سائقو التكسي"
              badge={pendingDriverCount || undefined}
            />
            <NavButton
              isActive={view === 'taxi'}
              onClick={() => onSwitchView('taxi')}
              iconClass="nav-icon-driver"
              icon={<Car size={16} />}
              label="عمليات التكسي"
            />
          </nav>
        </div>

        <div className="sidebar-divider" />

        {/* SETTINGS */}
        <div className="sidebar-nav-section">
          <span className="sidebar-nav-label">الإعدادات</span>
          <nav className="sidebar-nav">
            <NavButton
              isActive={view === 'homeCategories'}
              onClick={() => onSwitchView('homeCategories')}
              iconClass="nav-icon-settings"
              icon={<Grid3x3 size={16} />}
              label="أقسام الرئيسية"
            />
            <NavButton
              isActive={view === 'appUpdate'}
              onClick={() => onSwitchView('appUpdate')}
              iconClass="nav-icon-settings"
              icon={<Smartphone size={16} />}
              label="تحديث التطبيق"
            />
            <NavButton
              isActive={view === 'maintenance'}
              onClick={() => onSwitchView('maintenance')}
              iconClass="nav-icon-settings"
              icon={<Wrench size={16} />}
              label="وضع الصيانة"
            />
          </nav>
        </div>

        {/* Spacer */}
        <div style={{ flex: 1 }} />

        <div className="sidebar-divider" />

        {/* Logout */}
        <button className="ghost-button logout" onClick={onLogout} type="button">
          <LogOut size={16} />
          <span>تسجيل الخروج</span>
        </button>
      </aside>
    </>
  );
}
