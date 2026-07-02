import React from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import './styles/theme.css';
import { AuthProvider, useAuth } from './context/AuthContext';
import { AdminShell } from './layouts/AdminShell';
import { LoginPage } from './features/auth/LoginPage';
import { DashboardPage } from './features/dashboard/DashboardPage';
import { AccountsPage } from './features/accounts/AccountsPage';
import { RegisterCustomerPage } from './features/customers/RegisterCustomerPage';
import { MerchantsPage } from './features/merchants/MerchantsPage';
import { MerchantDetailPage } from './features/merchants/MerchantDetailPage';
import { RegisterMerchantPage } from './features/merchants/RegisterMerchantPage';
import { RegisterDoctorPage } from './features/doctors/RegisterDoctorPage';
import { RegisterPharmacyPage } from './features/pharmacies/RegisterPharmacyPage';
import { RegisterProfessionalPage } from './features/professionals/RegisterProfessionalPage';
import { ProfessionalsLayout } from './features/professionals/ProfessionalsLayout';
import { ProfessionalsOverviewPage } from './features/professionals/ProfessionalsOverviewPage';
import { AllProfessionalsPage, PendingProfessionalsPage } from './features/professionals/pages';
import { ProfessionalDetailPage } from './features/professionals/ProfessionalDetailPage';
import { PushNotificationsPage } from './features/notifications/PushNotificationsPage';
import { SupportChatPage } from './features/support-chat/SupportChatPage';
import {
  OperatorsListPage,
  OperatorDetailPage,
  RegisterDriverPage,
  RegisterCourierPage,
} from './features/operators/pages';
import { AdminsPage } from './features/admins/AdminsPage';
import { HealthBeautyLayout } from './features/health-beauty/HealthBeautyLayout';
import { HealthBeautyOverviewPage } from './features/health-beauty/HealthBeautyOverviewPage';
import { DoctorsListPage, PharmaciesListPage } from './features/health-beauty/pages';
import { ModerationLayout } from './features/moderation/ModerationLayout';
import { ModerationOverviewPage } from './features/moderation/ModerationOverviewPage';
import { PendingAccountsPage } from './features/moderation/PendingAccountsPage';
import {
  PendingCatalogProductsPage,
  PendingCarsPage,
  PendingCouriersPage,
  PendingDriversPage,
  PendingRealEstatePage,
  PendingTourismAccountsPage,
  PendingUsedPage,
  ModerationProfessionalsPage,
} from './features/moderation/pages';

function ProtectedRoutes() {
  const { token, isLoading } = useAuth();

  if (isLoading) {
    return (
      <div className="admin-v2 adm-auth">
        <p style={{ color: 'var(--adm-muted)' }}>جاري التحميل...</p>
      </div>
    );
  }

  if (!token) {
    return <Navigate to="/admin/login" replace />;
  }

  return (
    <Routes>
      <Route element={<AdminShell />}>
        <Route index element={<DashboardPage />} />
        <Route path="accounts" element={<AccountsPage />} />
        <Route path="customers/new" element={<RegisterCustomerPage />} />
        <Route path="merchants" element={<MerchantsPage />} />
        <Route path="merchants/new" element={<RegisterMerchantPage />} />
        <Route path="merchants/:phone" element={<MerchantDetailPage />} />
        <Route path="admins" element={<AdminsPage />} />
        <Route path="notifications" element={<PushNotificationsPage />} />
        <Route path="support-chat" element={<SupportChatPage />} />
        <Route path="drivers" element={<OperatorsListPage kind="driver" />} />
        <Route path="drivers/new" element={<RegisterDriverPage />} />
        <Route path="drivers/:phone" element={<OperatorDetailPage kind="driver" />} />
        <Route path="couriers" element={<OperatorsListPage kind="courier" />} />
        <Route path="couriers/new" element={<RegisterCourierPage />} />
        <Route path="couriers/:phone" element={<OperatorDetailPage kind="courier" />} />

        <Route path="professionals" element={<ProfessionalsLayout />}>
          <Route index element={<ProfessionalsOverviewPage />} />
          <Route path="list" element={<AllProfessionalsPage />} />
          <Route path="pending" element={<PendingProfessionalsPage />} />
          <Route path="new" element={<RegisterProfessionalPage />} />
          <Route path=":phone" element={<ProfessionalDetailPage />} />
        </Route>

        <Route path="health-beauty" element={<HealthBeautyLayout />}>
          <Route index element={<HealthBeautyOverviewPage />} />
          <Route path="pharmacies" element={<PharmaciesListPage />} />
          <Route path="pharmacies/new" element={<RegisterPharmacyPage />} />
          <Route path="doctors" element={<DoctorsListPage />} />
          <Route path="doctors/new" element={<RegisterDoctorPage />} />
        </Route>

        <Route path="moderation" element={<ModerationLayout />}>
          <Route index element={<ModerationOverviewPage />} />
          <Route path="accounts" element={<PendingAccountsPage />} />
          <Route path="products" element={<PendingCatalogProductsPage />} />
          <Route path="real-estate" element={<PendingRealEstatePage />} />
          <Route path="cars" element={<PendingCarsPage />} />
          <Route path="used" element={<PendingUsedPage />} />
          <Route path="tourism" element={<PendingTourismAccountsPage />} />
          <Route path="professionals" element={<ModerationProfessionalsPage />} />
          <Route path="drivers" element={<PendingDriversPage />} />
          <Route path="couriers" element={<PendingCouriersPage />} />
        </Route>

        <Route path="doctors/new" element={<Navigate to="/admin/health-beauty/doctors/new" replace />} />
        <Route path="pharmacies/new" element={<Navigate to="/admin/health-beauty/pharmacies/new" replace />} />

        <Route path="*" element={<Navigate to="/admin" replace />} />
      </Route>
    </Routes>
  );
}

export default function AdminApp() {
  return (
    <AuthProvider>
      <Routes>
        <Route path="/admin/login" element={<LoginGate />} />
        <Route path="/admin/*" element={<ProtectedRoutes />} />
        <Route path="/" element={<Navigate to="/admin" replace />} />
        <Route path="*" element={<Navigate to="/admin" replace />} />
      </Routes>
    </AuthProvider>
  );
}

function LoginGate() {
  const { token } = useAuth();
  if (token) return <Navigate to="/admin" replace />;
  return <LoginPage />;
}
