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
  sidebarOpen: boolean;
  onSwitchView: (view: AdminView) => void;
  onLogout: () => void;
  onCloseSidebar: () => void;
}

export default function Sidebar({
  view,
  phoneNumber,
  pendingMerchantQueue,
  pendingCourierQueue,
  approvalQueue,
  sidebarOpen,
  onSwitchView,
  onLogout,
  onCloseSidebar,
}: SidebarProps) {
  return (
    <>
      <div
        className={sidebarOpen ? 'sidebar-overlay open' : 'sidebar-overlay'}
        onClick={onCloseSidebar}
        role="presentation"
      />
      <aside className={sidebarOpen ? 'sidebar open' : 'sidebar'}>
        <div className="sidebar-header">
          <div className="brand-badge small">
            <Shield size={22} />
          </div>
          <div>
            <p className="eyebrow">الغيث</p>
            <h2>لوحة الإدارة</h2>
          </div>
        </div>

        <div className="admin-identity">
          <span>مسجّل الدخول</span>
          <strong dir="ltr">{phoneNumber}</strong>
        </div>

        <nav className="sidebar-nav">
          <button
            className={view === 'dashboard' ? 'nav-item active' : 'nav-item'}
            onClick={() => onSwitchView('dashboard')}
          >
            <BarChart3 size={18} />
            <span>الملخص العام</span>
          </button>
          <button
            className={view === 'accounts' ? 'nav-item active' : 'nav-item'}
            onClick={() => onSwitchView('accounts')}
          >
            <Users size={18} />
            <span>إدارة الحسابات</span>
          </button>
          <button
            className={view === 'merchants' ? 'nav-item active' : 'nav-item'}
            onClick={() => onSwitchView('merchants')}
          >
            <Store size={18} />
            <span>إدارة التجار</span>
            {pendingMerchantQueue.length > 0 ? (
              <span className="nav-badge">{pendingMerchantQueue.length}</span>
            ) : null}
          </button>
          <button
            className={view === 'couriers' ? 'nav-item active' : 'nav-item'}
            onClick={() => onSwitchView('couriers')}
          >
            <Bike size={18} />
            <span>مندوبو التوصيل</span>
            {pendingCourierQueue.length > 0 ? (
              <span className="nav-badge">{pendingCourierQueue.length}</span>
            ) : null}
          </button>
          <button
            className={view === 'homeCategories' ? 'nav-item active' : 'nav-item'}
            onClick={() => onSwitchView('homeCategories')}
          >
            <Grid3x3 size={18} />
            <span>أقسام الرئيسية</span>
          </button>
          <button
            className={view === 'appUpdate' ? 'nav-item active' : 'nav-item'}
            onClick={() => onSwitchView('appUpdate')}
          >
            <Smartphone size={18} />
            <span>تحديث التطبيق</span>
          </button>
        </nav>

        <button className="ghost-button logout" onClick={onLogout}>
          <LogOut size={18} />
          <span>تسجيل الخروج</span>
        </button>
      </aside>
    </>
  );
}
