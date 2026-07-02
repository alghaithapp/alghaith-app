import React from 'react';
import { NavLink } from 'react-router-dom';
import {
  BarChart3,
  Bike,
  Grid3x3,
  LogOut,
  Shield,
  Settings2,
  Store,
  Users,
  Car,
} from 'lucide-react';
import './Sidebar.css';
import { Button } from './ui/Button';

interface SidebarProps {
  currentView: string;
  adminName: string;
  sidebarOpen: boolean;
  setSidebarOpen: (v: boolean) => void;
  onLogout: () => void;
  onChangeView: (v: string) => void; // Keep for fallback compatibility
}

export default function Sidebar({
  sidebarOpen,
  setSidebarOpen,
  onLogout,
}: SidebarProps) {
  
  // Hardcoded badge counts for now - can be connected to React Query later
  const badges = {
    merchants: 0,
    couriers: 0,
    drivers: 0,
  };

  const totalPending = badges.merchants + badges.couriers + badges.drivers;

  const closeMenu = () => setSidebarOpen(false);

  return (
    <>
      <aside className={sidebarOpen ? 'sidebar open' : 'sidebar'}>
        <div className="sidebar-header">
          <div className="brand-badge small">
            <Shield size={20} />
          </div>
          <div>
            <p className="eyebrow">الغيث</p>
            <h2>لوحة الإدارة</h2>
          </div>
        </div>

        <div className="nav-group">الرئيسية</div>
        <NavLink to="/admin" end onClick={closeMenu} className={({ isActive }) => isActive ? 'nav-item active' : 'nav-item'}>
          <span className="nav-item-icon"><BarChart3 size={18} /></span>
          <span>الإحصائيات</span>
        </NavLink>

        <div className="nav-group">
          إدارة النظام
          {totalPending > 0 && <span className="nav-badge" style={{ display: 'inline-block', marginRight: '8px' }}>{totalPending}</span>}
        </div>
        
        <NavLink to="/admin/accounts" onClick={closeMenu} className={({ isActive }) => isActive ? 'nav-item active' : 'nav-item'}>
          <span className="nav-item-icon"><Users size={18} /></span>
          <span>المستخدمون</span>
        </NavLink>

        <NavLink to="/admin/admins" onClick={closeMenu} className={({ isActive }) => isActive ? 'nav-item active' : 'nav-item'}>
          <span className="nav-item-icon"><Shield size={18} /></span>
          <span>إدارة المشرفين</span>
        </NavLink>

        <NavLink to="/admin/merchants" onClick={closeMenu} className={({ isActive }) => isActive ? 'nav-item active' : 'nav-item'}>
          <span className="nav-item-icon"><Store size={18} /></span>
          <span>التجار</span>
          {badges.merchants > 0 && <span className="nav-badge">{badges.merchants}</span>}
        </NavLink>

        <NavLink to="/admin/couriers" onClick={closeMenu} className={({ isActive }) => isActive ? 'nav-item active' : 'nav-item'}>
          <span className="nav-item-icon"><Bike size={18} /></span>
          <span>مندوبين التوصيل</span>
          {badges.couriers > 0 && <span className="nav-badge">{badges.couriers}</span>}
        </NavLink>

        <NavLink to="/admin/drivers" onClick={closeMenu} className={({ isActive }) => isActive ? 'nav-item active' : 'nav-item'}>
          <span className="nav-item-icon"><Car size={18} /></span>
          <span>سائقو التكسي</span>
          {badges.drivers > 0 && <span className="nav-badge">{badges.drivers}</span>}
        </NavLink>

        <div className="nav-group">التطبيق والإعدادات</div>
        <NavLink to="/admin/settings" onClick={closeMenu} className={({ isActive }) => isActive ? 'nav-item active' : 'nav-item'}>
          <span className="nav-item-icon"><Settings2 size={18} /></span>
          <span>إعدادات النظام</span>
        </NavLink>

        <div className="sidebar-footer">
          <Button variant="danger" onClick={onLogout} style={{ width: '100%' }}>
            <LogOut size={16} />
            <span>تسجيل الخروج</span>
          </Button>
        </div>
      </aside>
    </>
  );
}
