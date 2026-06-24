import React, { FormEvent, useEffect, useMemo, useRef, useState } from 'react';
import { Shield, LoaderCircle, BadgeCheck, Lock, Store, Search } from 'lucide-react';

import {
  deleteAdminAccount,
  loadAdminAccounts,
  loadAdminReports,
  loadAppUpdatePolicy,
  loadCouriers,
  loadHomeCategoriesConfig,
  loadMerchantDetails,
  loadMerchants,
  saveAppUpdatePolicy,
  saveHomeCategoriesConfig,
  rejectCourierApplication,
  rejectDriverApplication,
  preRegisterMerchant,
  rejectMerchantApplication,
  sendCode,
  suspendAdminAccount,
  syncMerchantBazaarProducts,
  updateAdminAccountRole,
  toggleCourierApproval,
  toggleDriverApproval,
  toggleMerchantApproval,
  toggleMerchantBazaar,
  toggleMerchantFreeze,
  verifyCode,
} from './admin-api';
import type {
  AdminAccountKind,
  AdminAccountSummary,
  AdminReports,
  AppUpdatePolicy,
  CourierSummary,
  HomeCategoriesConfig,
  MerchantPreRegisterPayload,
  MerchantDetails,
  MerchantSummary,
} from './admin-types';
import {
  MERCHANT_REJECTION_REASONS,
  COURIER_REJECTION_REASONS,
} from './admin-types';

import LoginView from './components/LoginView';
import Sidebar from './components/Sidebar';
import DashboardView from './components/views/DashboardView';
import MerchantsView from './components/views/MerchantsView';
import CouriersView from './components/views/CouriersView';
import DriversView from './components/views/DriversView';
import AccountsView from './components/views/AccountsView';
import HomeCategoriesView from './components/views/HomeCategoriesView';
import AppUpdateView from './components/views/AppUpdateView';
import DeleteModal from './components/DeleteModal';
import RejectModal from './components/RejectModal';

type RejectAccountTarget = Pick<
  AdminAccountSummary,
  'phone' | 'displayName' | 'kind'
>;

const SESSION_STORAGE_KEY = 'alghaith-admin-session-v1';

type AdminView =
  | 'dashboard'
  | 'accounts'
  | 'merchants'
  | 'couriers'
  | 'drivers'
  | 'homeCategories'
  | 'appUpdate';
type AccountFilter = 'all' | AdminAccountKind;
type MerchantFilter = 'all' | 'pending' | 'rejected' | 'professionals' | 'bazaar';

const VIEW_META: Record<
  AdminView,
  { eyebrow: string; title: string; subtitle: string; showSearch: boolean }
> = {
  dashboard: {
    eyebrow: 'لوحة التحكم',
    title: 'ملخص المنصة',
    subtitle: 'نظرة عامة على الطلبات والتجار والمهام المعلقة.',
    showSearch: false,
  },
  merchants: {
    eyebrow: 'إدارة التجار',
    title: 'التجار والمهنيون',
    subtitle: 'استعراض الحالة، الأرباح، الطلبات، وإجراءات التجميد والبازار.',
    showSearch: true,
  },
  couriers: {
    eyebrow: 'مندوبو التوصيل',
    title: 'إدارة مندوبي التوصيل',
    subtitle: 'راجع بيانات المندوب ووافق على تفعيل حسابه قبل استقبال الطلبات.',
    showSearch: true,
  },
  drivers: {
    eyebrow: 'سائقو التكسي',
    title: 'إدارة سائقي التكسي',
    subtitle: 'راجع طلبات تفعيل سائقي التكسي وأدر حساباتهم.',
    showSearch: true,
  },
  accounts: {
    eyebrow: 'إدارة الحسابات',
    title: 'جميع حسابات المنصة',
    subtitle: 'جميع الحسابات مصنّفة حسب النوع — زبائن، تجار، مندوبين، سائقون، مشرفون.',
    showSearch: true,
  },
  appUpdate: {
    eyebrow: 'تحديث التطبيق',
    title: 'التحديث الإجباري',
    subtitle:
      'حدّد أقل رقم بناء مسموح به. من دونه يُجبر المستخدم على التحديث من المتجر.',
    showSearch: false,
  },
  homeCategories: {
    eyebrow: 'أقسام الرئيسية',
    title: 'التحكم بأقسام التطبيق',
    subtitle:
      'فعّل أو أطفئ كل قسم على أندرويد وآيفون بشكل منفصل. التغيير يظهر فوراً للمستخدمين.',
    showSearch: false,
  },
};

interface StoredSession {
  token: string;
  phoneNumber: string;
}

function formatMoney(value: number) {
  return new Intl.NumberFormat('ar-IQ').format(Math.round(value || 0));
}

function formatDate(value: string | null | undefined) {
  if (!value) return 'غير متوفر';
  try {
    return new Intl.DateTimeFormat('ar-IQ', {
      dateStyle: 'medium',
      timeStyle: 'short',
    }).format(new Date(value));
  } catch (_) {
    return value;
  }
}

function serviceLabel(serviceId: string) {
  switch (serviceId) {
    case 'restaurant':
      return 'مطعم';
    case 'product':
      return 'متجر';
    case 'real_estate':
      return 'عقار';
    case 'professionals':
      return 'مهني';
    default:
      return serviceId || 'غير محدد';
  }
}

function canRequestBazaarApproval(merchant: MerchantSummary) {
  return merchant.primaryServiceId === 'restaurant' || merchant.primaryServiceId === 'product';
}

function accountNeedsApproval(account: AdminAccountSummary) {
  return account.needsApproval === true;
}

function accountKindLabel(kind: AdminAccountKind) {
  switch (kind) {
    case 'customer':
      return 'زبون';
    case 'merchant':
      return 'تاجر / مهني';
    case 'courier':
      return 'مندوب توصيل';
    case 'driver':
      return 'سائق تكسي';
    case 'admin':
      return 'مشرف';
    default:
      return kind;
  }
}

function readStoredSession(): StoredSession | null {
  try {
    const raw = window.localStorage.getItem(SESSION_STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Partial<StoredSession>;
    if (!parsed.token || !parsed.phoneNumber) return null;
    return { token: String(parsed.token), phoneNumber: String(parsed.phoneNumber) };
  } catch (_) {
    return null;
  }
}

export default function App() {
  const [token, setToken] = useState<string | null>(null);
  const [phoneNumber, setPhoneNumber] = useState<string>('');
  const [inputPhone, setInputPhone] = useState('');
  const [authChannel, setAuthChannel] = useState<'sms' | 'whatsapp'>('whatsapp');
  const [otpCode, setOtpCode] = useState('');
  const [otpSent, setOtpSent] = useState(false);
  const [isSendingCode, setIsSendingCode] = useState(false);
  const [isVerifyingCode, setIsVerifyingCode] = useState(false);
  const [bootError, setBootError] = useState('');
  const [actionError, setActionError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');
  const [view, setView] = useState<AdminView>('dashboard');
  const [search, setSearch] = useState('');
  const [reports, setReports] = useState<AdminReports | null>(null);
  const [merchants, setMerchants] = useState<MerchantSummary[]>([]);
  const [couriers, setCouriers] = useState<CourierSummary[]>([]);
  const [accounts, setAccounts] = useState<AdminAccountSummary[]>([]);
  const [accountFilter, setAccountFilter] = useState<AccountFilter>('all');
  const [selectedMerchantPhone, setSelectedMerchantPhone] = useState('');
  const [merchantDetails, setMerchantDetails] = useState<MerchantDetails | null>(null);
  const [isLoadingData, setIsLoadingData] = useState(false);
  const [isLoadingDetails, setIsLoadingDetails] = useState(false);
  const [activeActionKey, setActiveActionKey] = useState('');
  const [rejectAccountTarget, setRejectAccountTarget] = useState<RejectAccountTarget | null>(null);
  const [rejectMessage, setRejectMessage] = useState('');
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<AdminAccountSummary | null>(null);
  const [appUpdatePolicy, setAppUpdatePolicy] = useState<AppUpdatePolicy | null>(null);
  const [merchantFilter, setMerchantFilter] = useState<MerchantFilter>('all');
  const [appUpdateDraft, setAppUpdateDraft] = useState({
    minBuildNumber: '1',
    minVersionName: '1.0.0',
    latestBuildNumber: '0',
    latestVersionName: '',
    messageAr: 'يجب تحديث التطبيق للمتابعة. الرجاء التحديث من المتجر للاستمرار في استخدام الغيث.',
    androidStoreUrl: 'https://play.google.com/store/apps/details?id=com.alghaith.app',
    iosStoreUrl: 'https://apps.apple.com/app/id6776741811',
  });
  const [isSavingAppUpdate, setIsSavingAppUpdate] = useState(false);
  const [homeCategoriesConfig, setHomeCategoriesConfig] = useState<HomeCategoriesConfig | null>(null);
  const [homeCategorySavingKey, setHomeCategorySavingKey] = useState('');
  const [isLoadingHomeCategories, setIsLoadingHomeCategories] = useState(false);
  const homeCategoriesLoadSeq = useRef(0);
  const homeCategoriesSaveSeq = useRef(0);

  useEffect(() => {
    const stored = readStoredSession();
    if (!stored) return;
    setToken(stored.token);
    setPhoneNumber(stored.phoneNumber);
  }, []);

  async function refreshCoreData(authToken: string, preferredMerchantPhone?: string) {
    setIsLoadingData(true);
    setBootError('');
    try {
      const [nextReports, nextMerchants, nextCouriers] = await Promise.all([
        loadAdminReports(authToken),
        loadMerchants(authToken),
        loadCouriers(authToken),
      ]);
      setReports(nextReports);
      setMerchants(nextMerchants);
      setCouriers(nextCouriers);
      try {
        const nextAccounts = await loadAdminAccounts(authToken);
        setAccounts(nextAccounts);
      } catch {
        setAccounts([]);
      }
      const merchantPhone = preferredMerchantPhone || selectedMerchantPhone || nextMerchants[0]?.phone || '';
      if (merchantPhone) setSelectedMerchantPhone(merchantPhone);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'تعذر تحميل بيانات لوحة الإدارة.';
      setBootError(message);
    } finally {
      setIsLoadingData(false);
    }
  }

  useEffect(() => {
    if (!token) return;
    refreshCoreData(token).catch(() => undefined);
  }, [token]);

  useEffect(() => {
    if (!token || view !== 'appUpdate') return;
    setActionError('');
    loadAppUpdatePolicy(token)
      .then((policy) => {
        setAppUpdatePolicy(policy);
        setAppUpdateDraft({
          minBuildNumber: String(policy.minBuildNumber),
          minVersionName: policy.minVersionName,
          latestBuildNumber: String(policy.latestBuildNumber ?? 0),
          latestVersionName: policy.latestVersionName ?? '',
          messageAr: policy.messageAr,
          androidStoreUrl: policy.androidStoreUrl,
          iosStoreUrl: policy.iosStoreUrl,
        });
      })
      .catch((error) => {
        setActionError(error instanceof Error ? error.message : 'تعذر تحميل إعدادات التحديث الإجباري.');
      });
  }, [token, view]);

  useEffect(() => {
    if (!token || view !== 'homeCategories') return;
    const seq = ++homeCategoriesLoadSeq.current;
    setIsLoadingHomeCategories(true);
    setActionError('');
    loadHomeCategoriesConfig(token)
      .then((config) => {
        if (seq !== homeCategoriesLoadSeq.current || seq <= homeCategoriesSaveSeq.current) return;
        setHomeCategoriesConfig(config);
      })
      .catch((error) => {
        if (seq !== homeCategoriesLoadSeq.current) return;
        setActionError(error instanceof Error ? error.message : 'تعذر تحميل إعدادات أقسام الصفحة الرئيسية.');
      })
      .finally(() => {
        if (seq === homeCategoriesLoadSeq.current) setIsLoadingHomeCategories(false);
      });
  }, [token, view]);

  useEffect(() => {
    if (!token || !selectedMerchantPhone) {
      setMerchantDetails(null);
      return;
    }
    let cancelled = false;
    setIsLoadingDetails(true);
    setActionError('');
    loadMerchantDetails(token, selectedMerchantPhone)
      .then((data) => { if (!cancelled) setMerchantDetails(data); })
      .catch((error) => {
        if (!cancelled) setActionError(error instanceof Error ? error.message : 'تعذر تحميل تفاصيل التاجر.');
      })
      .finally(() => { if (!cancelled) setIsLoadingDetails(false); });
    return () => { cancelled = true; };
  }, [selectedMerchantPhone, token]);

  // Memoized filtered data
  const filteredMerchants = useMemo(() => {
    const query = search.trim().toLowerCase();
    return merchants.filter((merchant) => {
      if (merchantFilter === 'pending') {
        if (merchant.isApproved) return false;
        const status = merchant.approvalStatus?.toString() ?? 'pending';
        if (status !== 'pending') return false;
      } else if (merchantFilter === 'rejected') {
        if (merchant.approvalStatus !== 'rejected') return false;
      } else if (merchantFilter === 'bazaar') {
        if (!canRequestBazaarApproval(merchant) || merchant.isBazaarMember !== true) return false;
      } else if (merchantFilter === 'professionals') {
        if (merchant.primaryServiceId !== 'professionals' && !merchant.isProfessional) return false;
      }
      if (!query) return true;
      return [merchant.storeName, merchant.fullName, merchant.phone, merchant.primaryServiceId, merchant.isProfessional ? 'مهني' : '']
        .join(' ').toLowerCase().includes(query);
    });
  }, [merchants, search, merchantFilter]);

  const approvalQueue = useMemo(
    () => merchants.filter((m) => canRequestBazaarApproval(m) && m.isBazaarMember !== true),
    [merchants],
  );

  const pendingCourierQueue = useMemo(
    () => couriers.filter((c) => !c.isApproved && (c.approvalStatus === 'pending' || !c.approvalStatus)),
    [couriers],
  );

  const pendingMerchantQueue = useMemo(
    () => merchants.filter(
      (m) => !m.isApproved &&
        (m.approvalStatus === 'pending' || !m.approvalStatus),
    ),
    [merchants],
  );

  const filteredAccounts = useMemo(() => {
    const query = search.trim().toLowerCase();
    return accounts.filter((a) => {
      if (accountFilter !== 'all' && a.kind !== accountFilter) return false;
      if (!query) return true;
      return [a.displayName, a.fullName, a.phone, a.kind, a.merchantStoreName, a.primaryServiceId]
        .join(' ').toLowerCase().includes(query);
    });
  }, [accounts, accountFilter, search]);

  const filteredCouriers = useMemo(() => {
    const query = search.trim().toLowerCase();
    if (!query) return couriers;
    return couriers.filter((c) =>
      [c.name, c.contactPhone, c.phone, c.homeAddress].join(' ').toLowerCase().includes(query),
    );
  }, [couriers, search]);

  const frozenMerchants = useMemo(() => merchants.filter((m) => m.isFrozen).length, [merchants]);

  // Driver accounts derived from main accounts list
  const driverAccounts = useMemo(() => accounts.filter((a) => a.kind === 'driver'), [accounts]);

  const filteredDrivers = useMemo(() => {
    const query = search.trim().toLowerCase();
    if (!query) return driverAccounts;
    return driverAccounts.filter((d) =>
      [d.displayName, d.fullName, d.phone].join(' ').toLowerCase().includes(query),
    );
  }, [driverAccounts, search]);

  const pendingDriverQueue = useMemo(
    () => driverAccounts.filter((d) => !d.isApproved && d.approvalStatus === 'pending'),
    [driverAccounts],
  );

  // User type counts for dashboard distribution
  const totalCustomers = useMemo(() => accounts.filter((a) => a.kind === 'customer').length, [accounts]);
  const totalMerchantsCount = useMemo(() => accounts.filter((a) => a.kind === 'merchant').length, [accounts]);
  const totalCouriersCount = useMemo(() => accounts.filter((a) => a.kind === 'courier').length, [accounts]);
  const totalDriversCount = useMemo(() => accounts.filter((a) => a.kind === 'driver').length, [accounts]);

  // Handlers
  async function handleSendCode(event: FormEvent) {
    event.preventDefault();
    setIsSendingCode(true);
    setBootError('');
    try {
      await sendCode(inputPhone, authChannel);
      setOtpSent(true);
      setSuccessMessage(`تم إرسال رمز التحقق عبر ${authChannel === 'whatsapp' ? 'واتساب' : 'SMS'} إلى الرقم المدخل.`);
    } catch (error) {
      setBootError(error instanceof Error ? error.message : 'تعذر إرسال الرمز.');
    } finally { setIsSendingCode(false); }
  }

  async function handleVerifyCode(event: FormEvent) {
    event.preventDefault();
    setIsVerifyingCode(true);
    setBootError('');
    try {
      const session = await verifyCode(inputPhone, otpCode);
      window.localStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify({ token: session.token, phoneNumber: session.phoneNumber }));
      setToken(session.token);
      setPhoneNumber(session.phoneNumber);
      setInputPhone(session.phoneNumber);
      setSuccessMessage('تم تسجيل الدخول بنجاح إلى لوحة الإدارة.');
    } catch (error) {
      setBootError(error instanceof Error ? error.message : 'تعذر تأكيد الرمز.');
    } finally { setIsVerifyingCode(false); }
  }

  function switchView(nextView: AdminView) {
    setView(nextView);
    setSearch('');
    setSidebarOpen(false);
  }

  function handleLogout() {
    window.localStorage.removeItem(SESSION_STORAGE_KEY);
    setToken(null);
    setPhoneNumber('');
    setInputPhone('');
    setOtpCode('');
    setOtpSent(false);
    setReports(null);
    setMerchants([]);
    setCouriers([]);
    setAccounts([]);
    setMerchantDetails(null);
    setDeleteTarget(null);
    setHomeCategoriesConfig(null);
    setSelectedMerchantPhone('');
    setSuccessMessage('');
    setActionError('');
    setBootError('');
  }

  async function handleMerchantApproval(merchant: MerchantSummary) {
    if (!token) return;
    setActiveActionKey(`merchant-approval:${merchant.phone}`);
    setActionError('');
    setSuccessMessage('');
    try {
      await toggleMerchantApproval(token, merchant.phone, !merchant.isApproved);
      setSuccessMessage(merchant.isApproved ? `تم إلغاء تفعيل حساب التاجر ${merchant.storeName || merchant.phone}.` : `تم تفعيل حساب التاجر ${merchant.storeName || merchant.phone}.`);
      await refreshCoreData(token, merchant.phone);
    } catch (error) {
      setActionError(error instanceof Error ? error.message : 'تعذر تحديث حالة التاجر.');
    } finally { setActiveActionKey(''); }
  }

  async function handlePreRegisterMerchant(payload: MerchantPreRegisterPayload) {
    if (!token) return;
    setActionError('');
    setSuccessMessage('');
    try {
      const result = await preRegisterMerchant(token, payload);
      setSuccessMessage(
        `تم تسجيل حساب التاجر ${result.phone}. عند تسجيل الدخول سيكمل بيانات متجره فقط.`,
      );
      await refreshCoreData(token, result.phone);
      setMerchantFilter('pending');
      setSelectedMerchantPhone(result.phone);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'تعذر تسجيل التاجر.';
      setActionError(message);
      throw error;
    }
  }

  async function handleMerchantAction(merchant: MerchantSummary, kind: 'freeze' | 'bazaar') {
    if (!token) return;
    setActiveActionKey(`${kind}:${merchant.phone}`);
    setActionError('');
    setSuccessMessage('');
    try {
      if (kind === 'freeze') {
        await toggleMerchantFreeze(token, merchant.phone, !merchant.isFrozen);
        setSuccessMessage(merchant.isFrozen ? `تم فك تجميد ${merchant.storeName || merchant.phone}.` : `تم تجميد ${merchant.storeName || merchant.phone}.`);
      } else {
        const enabling = !merchant.isBazaarMember;
        const result = await toggleMerchantBazaar(token, merchant.phone, enabling);
        if (enabling) setSuccessMessage(`تمت الموافقة على ${merchant.storeName || merchant.phone} داخل بازار ومطاعم الغيث. ${result.bazaarProductSync?.totalEligible ?? 0} منتج يظهر الآن.`);
        else setSuccessMessage(`تم سحب موافقة بازار من ${merchant.storeName || merchant.phone}.`);
      }
      await refreshCoreData(token, merchant.phone);
      const details = await loadMerchantDetails(token, merchant.phone);
      setMerchantDetails(details);
    } catch (error) {
      setActionError(error instanceof Error ? error.message : 'تعذر تنفيذ العملية الإدارية.');
    } finally { setActiveActionKey(''); }
  }

  async function handleBazaarSync(merchant: MerchantSummary) {
    if (!token) return;
    setActiveActionKey(`sync:${merchant.phone}`);
    setActionError('');
    setSuccessMessage('');
    try {
      const result = await syncMerchantBazaarProducts(token, merchant.phone);
      setSuccessMessage(`تمت مزامنة ${merchant.storeName || merchant.phone}. ${result.totalEligible} منتج جاهز للظهور في البازار.`);
      await refreshCoreData(token, merchant.phone);
      const details = await loadMerchantDetails(token, merchant.phone);
      setMerchantDetails(details);
    } catch (error) {
      setActionError(error instanceof Error ? error.message : 'تعذر مزامنة ظهور البازار.');
    } finally { setActiveActionKey(''); }
  }

  function openRejectConfirm(target: RejectAccountTarget) {
    setRejectAccountTarget(target);
    setRejectMessage('');
  }

  async function handleRejectAccount() {
    if (!token || !rejectAccountTarget) return;
    const message = rejectMessage.trim();
    if (!message) { setActionError('يرجى كتابة سبب الرفض ليظهر للمستخدم.'); return; }
    setActiveActionKey(`reject-account:${rejectAccountTarget.phone}`);
    setActionError('');
    setSuccessMessage('');
    try {
      if (rejectAccountTarget.kind === 'merchant') await rejectMerchantApplication(token, rejectAccountTarget.phone, message);
      else if (rejectAccountTarget.kind === 'courier') await rejectCourierApplication(token, rejectAccountTarget.phone, message);
      else if (rejectAccountTarget.kind === 'driver') await rejectDriverApplication(token, rejectAccountTarget.phone, message);
      else throw new Error('لا يمكن رفض هذا النوع من الحسابات.');
      setSuccessMessage(`تم رفض طلب ${rejectAccountTarget.displayName || rejectAccountTarget.phone} وإرسال السبب للمستخدم.`);
      setRejectAccountTarget(null);
      setRejectMessage('');
      await refreshCoreData(token);
    } catch (error) {
      setActionError(error instanceof Error ? error.message : 'تعذر رفض الطلب.');
    } finally { setActiveActionKey(''); }
  }

  async function handleCourierApproval(courier: CourierSummary) {
    if (!token) return;
    setActiveActionKey(`courier:${courier.phone}`);
    setActionError('');
    setSuccessMessage('');
    try {
      await toggleCourierApproval(token, courier.phone, !courier.isApproved);
      setSuccessMessage(courier.isApproved ? `تم إلغاء تفعيل حساب المندوب ${courier.name || courier.phone}.` : `تم تفعيل حساب المندوب ${courier.name || courier.phone}.`);
      await refreshCoreData(token);
    } catch (error) {
      setActionError(error instanceof Error ? error.message : 'تعذر تحديث حالة المندوب.');
    } finally { setActiveActionKey(''); }
  }

  function openDeleteConfirm(target: AdminAccountSummary) {
    if (target.kind === 'admin') { setActionError('لا يمكن حذف حساب مشرف محمي.'); return; }
    setDeleteTarget(target);
  }

  async function handleDeleteAccount() {
    if (!token || !deleteTarget) return;
    setActiveActionKey(`delete-account:${deleteTarget.phone}`);
    setActionError('');
    setSuccessMessage('');
    try {
      await deleteAdminAccount(token, deleteTarget.phone);
      setSuccessMessage(`تم حذف حساب ${deleteTarget.displayName || deleteTarget.phone} نهائياً.`);
      setDeleteTarget(null);
      if (selectedMerchantPhone === deleteTarget.phone) { setSelectedMerchantPhone(''); setMerchantDetails(null); }
      await refreshCoreData(token);
    } catch (error) {
      setActionError(error instanceof Error ? error.message : 'تعذر حذف الحساب.');
    } finally { setActiveActionKey(''); }
  }

  async function handleSuspendAccount(account: AdminAccountSummary) {
    if (!token) return;
    if (account.kind === 'admin') { setActionError('لا يمكن تعليق حساب مشرف محمي.'); return; }
    const enabling = account.isSuspended !== true;
    setActiveActionKey(`suspend-account:${account.phone}`);
    setActionError('');
    setSuccessMessage('');
    try {
      await suspendAdminAccount(token, account.phone, enabling);
      setSuccessMessage(enabling ? `تم تعليق حساب ${account.displayName || account.phone}.` : `تم فك تعليق حساب ${account.displayName || account.phone}.`);
      await refreshCoreData(token, account.phone);
    } catch (error) {
      setActionError(error instanceof Error ? error.message : 'تعذر تحديث حالة التعليق.');
    } finally { setActiveActionKey(''); }
  }

  async function handleApproveAccount(account: AdminAccountSummary) {
    if (!token || !accountNeedsApproval(account)) return;
    setActiveActionKey(`approve-account:${account.phone}`);
    setActionError('');
    setSuccessMessage('');
    try {
      if (account.kind === 'merchant') await toggleMerchantApproval(token, account.phone, true);
      else if (account.kind === 'courier') await toggleCourierApproval(token, account.phone, true);
      else if (account.kind === 'driver') await toggleDriverApproval(token, account.phone, true);
      setSuccessMessage(`تمت موافقة وتفعيل حساب ${account.displayName || account.phone}.`);
      await refreshCoreData(token, account.kind === 'merchant' ? account.phone : undefined);
    } catch (error) {
      setActionError(error instanceof Error ? error.message : 'تعذر تفعيل الحساب.');
    } finally { setActiveActionKey(''); }
  }

  // Toggle driver approval on/off (for DriversView activate/deactivate button)
  async function handleToggleDriverApproval(account: AdminAccountSummary) {
    if (!token) return;
    const nextApproved = !account.isApproved;
    setActiveActionKey(`approve-account:${account.phone}`);
    setActionError('');
    setSuccessMessage('');
    try {
      await toggleDriverApproval(token, account.phone, nextApproved);
      setSuccessMessage(
        nextApproved
          ? `تمت موافقة وتفعيل حساب السائق ${account.displayName || account.phone}.`
          : `تم إلغاء تفعيل حساب السائق ${account.displayName || account.phone}.`,
      );
      await refreshCoreData(token);
    } catch (error) {
      setActionError(error instanceof Error ? error.message : 'تعذر تحديث حالة السائق.');
    } finally { setActiveActionKey(''); }
  }

  async function handleChangeRole(account: AdminAccountSummary, newRole: string) {
    if (!token) return;
    if (account.kind === 'admin') { setActionError('لا يمكن تغيير دور مشرف محمي.'); return; }
    setActiveActionKey(`role:${account.phone}`);
    setActionError('');
    setSuccessMessage('');
    try {
      await updateAdminAccountRole(token, account.phone, newRole);
      setSuccessMessage(`تم تغيير دور ${account.displayName || account.phone} إلى ${newRole}.`);
      await refreshCoreData(token, account.phone);
    } catch (error) {
      setActionError(error instanceof Error ? error.message : 'تعذر تغيير دور الحساب.');
    } finally { setActiveActionKey(''); }
  }

  async function handleSaveAppUpdatePolicy() {
    if (!token) return;
    const minBuildNumber = Number.parseInt(appUpdateDraft.minBuildNumber, 10);
    const latestBuildNumber = Number.parseInt(appUpdateDraft.latestBuildNumber, 10);
    if (!Number.isFinite(minBuildNumber) || minBuildNumber < 1) { setActionError('أدخل رقم بناء صحيحاً (1 أو أكثر).'); return; }
    if (!Number.isFinite(latestBuildNumber) || latestBuildNumber < 0) { setActionError('أدخل أحدث رقم بناء صحيحاً (0 أو أكثر).'); return; }
    if (!appUpdateDraft.messageAr.trim()) { setActionError('اكتب رسالة تظهر للمستخدم عند طلب التحديث.'); return; }
    setIsSavingAppUpdate(true);
    setActionError('');
    setSuccessMessage('');
    try {
      const result = await saveAppUpdatePolicy(token, {
        minBuildNumber,
        minVersionName: appUpdateDraft.minVersionName.trim() || '1.0.0',
        latestBuildNumber,
        latestVersionName: appUpdateDraft.latestVersionName.trim(),
        messageAr: appUpdateDraft.messageAr.trim(),
        androidStoreUrl: appUpdateDraft.androidStoreUrl.trim(),
        iosStoreUrl: appUpdateDraft.iosStoreUrl.trim(),
      });
      setAppUpdatePolicy(result.policy);
      setSuccessMessage('تم حفظ إعدادات التحديث الإجباري.');
    } catch (error) {
      setActionError(error instanceof Error ? error.message : 'تعذر حفظ إعدادات التحديث.');
    } finally { setIsSavingAppUpdate(false); }
  }

  async function handleHomeCategoryPlatformToggle(categoryId: string, platform: 'android' | 'ios', enabled: boolean) {
    if (!token) return;
    const savingKey = `${categoryId}:${platform}`;
    setHomeCategorySavingKey(savingKey);
    setActionError('');
    setSuccessMessage('');
    const previous = homeCategoriesConfig;
    const overrides = { ...(homeCategoriesConfig?.overrides || {}) };
    overrides[categoryId] = { ...(overrides[categoryId] || {}), [platform]: enabled };
    const saveSeq = ++homeCategoriesSaveSeq.current;
    setHomeCategoriesConfig({ overrides, updatedAt: homeCategoriesConfig?.updatedAt || null });
    try {
      const saved = await saveHomeCategoriesConfig(token, overrides);
      if (saveSeq !== homeCategoriesSaveSeq.current) return;
      setHomeCategoriesConfig(saved);
      setSuccessMessage('تم حفظ إعدادات الأقسام.');
    } catch (error) {
      if (saveSeq !== homeCategoriesSaveSeq.current) return;
      if (previous) setHomeCategoriesConfig(previous);
      setActionError(error instanceof Error ? error.message : 'تعذر حفظ إعدادات الأقسام.');
    } finally { setHomeCategorySavingKey(''); }
  }

  const viewMeta = VIEW_META[view];

  // Login page
  if (!token) {
    return (
      <LoginView
        inputPhone={inputPhone}
        otpCode={otpCode}
        otpSent={otpSent}
        isSendingCode={isSendingCode}
        isVerifyingCode={isVerifyingCode}
        bootError={bootError}
        authChannel={authChannel}
        onInputPhoneChange={setInputPhone}
        onOtpCodeChange={setOtpCode}
        onAuthChannelChange={setAuthChannel}
        onSendCode={handleSendCode}
        onVerifyCode={handleVerifyCode}
      />
    );
  }

  // Main app
  return (
    <main className="admin-shell">
      <div className="dashboard-layout">
        <Sidebar
          view={view}
          phoneNumber={phoneNumber}
          pendingMerchantQueue={pendingMerchantQueue}
          pendingCourierQueue={pendingCourierQueue}
          approvalQueue={approvalQueue}
          pendingDriverCount={pendingDriverQueue.length}
          sidebarOpen={sidebarOpen}
          onSwitchView={switchView}
          onLogout={handleLogout}
          onCloseSidebar={() => setSidebarOpen(false)}
        />

        {sidebarOpen ? (
          <div className="sidebar-overlay open" onClick={() => setSidebarOpen(false)} />
        ) : null}

        <section className="content">
          <div className="content-top">
            <button className="mobile-menu-button" type="button" aria-label="فتح القائمة" onClick={() => setSidebarOpen(true)}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M3 12h18M3 6h18M3 18h18"/></svg>
            </button>
            <header className="topbar">
              <div>
                <p className="eyebrow">{viewMeta.eyebrow}</p>
                <h1>{viewMeta.title}</h1>
                <p>{viewMeta.subtitle}</p>
              </div>
              {viewMeta.showSearch ? (
                <div className="topbar-search">
                  <Search size={18} />
                  <input
                    placeholder={view === 'couriers' ? 'ابحث عن مندوب أو رقم هاتف' : view === 'accounts' ? 'ابحث عن حساب أو رقم هاتف' : 'ابحث عن تاجر أو رقم هاتف'}
                    value={search}
                    onChange={(event) => setSearch(event.target.value)}
                  />
                </div>
              ) : null}
            </header>
          </div>

          {(bootError || actionError || successMessage) ? (
            <div className="alert-stack sticky-alerts">
              {bootError ? <div className="message error">{bootError}</div> : null}
              {actionError ? <div className="message error">{actionError}</div> : null}
              {successMessage ? <div className="message success">{successMessage}</div> : null}
            </div>
          ) : null}

          {isLoadingData ? (
            <div className="loading-state">
              <LoaderCircle className="spin" size={28} />
              <span>جار تحميل بيانات لوحة الإدارة...</span>
            </div>
          ) : (
            <>
              {view === 'dashboard' ? (
                <DashboardView
                  reports={reports}
                  pendingMerchantQueue={pendingMerchantQueue}
                  pendingCourierQueue={pendingCourierQueue}
                  approvalQueue={approvalQueue}
                  frozenMerchants={frozenMerchants}
                  pendingDriverCount={pendingDriverQueue.length}
                  totalCustomers={totalCustomers}
                  totalMerchants={totalMerchantsCount}
                  totalCouriers={totalCouriersCount}
                  totalDrivers={totalDriversCount}
                  formatMoney={formatMoney}
                  formatDate={formatDate}
                  onSwitchView={switchView}
                  onSetMerchantFilter={setMerchantFilter}
                />
              ) : null}

              {view === 'merchants' ? (
                <section className={view === 'couriers' || view === 'accounts' ? 'main-grid couriers-only' : 'main-grid'}>
                  <div className="panel wide">
                    <div className="panel-header">
                      <div>
                        <h3>جميع التجار والمهنيين</h3>
                        <p>طلبات المهنيين والتجار بانتظار الموافقة تظهر في الأعلى. استخدم الفلاتر أدناه.</p>
                      </div>
                      <span className="panel-chip">{filteredMerchants.length}</span>
                    </div>
                    <MerchantsView
                      merchants={filteredMerchants}
                      search={search}
                      merchantFilter={merchantFilter}
                      selectedMerchantPhone={selectedMerchantPhone}
                      merchantDetails={merchantDetails}
                      isLoadingDetails={isLoadingDetails}
                      activeActionKey={activeActionKey}
                      accounts={accounts}
                      formatMoney={formatMoney}
                      formatDate={formatDate}
                      onSearchChange={setSearch}
                      onFilterChange={setMerchantFilter}
                      onSelectMerchant={setSelectedMerchantPhone}
                      onMerchantApproval={handleMerchantApproval}
                      onMerchantAction={handleMerchantAction}
                      onBazaarSync={handleBazaarSync}
                      onOpenReject={(target) => openRejectConfirm({ phone: target.phone, displayName: target.displayName, kind: 'merchant' })}
                      onOpenDelete={openDeleteConfirm}
                      onPreRegisterMerchant={handlePreRegisterMerchant}
                      pendingMerchantQueue={pendingMerchantQueue}
                      approvalQueue={approvalQueue}
                    />
                  </div>
                </section>
              ) : null}

              {view === 'couriers' ? (
                <section className="main-grid couriers-only">
                  <div className="panel wide">
                    <div className="panel-header">
                      <div>
                        <h3>مندوبو التوصيل</h3>
                        <p>اضغط على الإجراء المناسب لكل مندوب.</p>
                      </div>
                      <span className="panel-chip">{filteredCouriers.length}</span>
                    </div>
                    <CouriersView
                      couriers={couriers}
                      filteredCouriers={filteredCouriers}
                      search={search}
                      activeActionKey={activeActionKey}
                      accounts={accounts}
                      onSearchChange={setSearch}
                      onCourierApproval={handleCourierApproval}
                      onOpenReject={(target) => openRejectConfirm(target)}
                      onSuspend={handleSuspendAccount}
                      onOpenDelete={openDeleteConfirm}
                    />
                  </div>
                </section>
              ) : null}

              {view === 'drivers' ? (
                <section className="main-grid couriers-only">
                  <div className="panel wide">
                    <div className="panel-header">
                      <div>
                        <h3>سائقو التكسي</h3>
                        <p>راجع طلبات التفعيل ووافق على حسابات السائقين.</p>
                      </div>
                      <span className="panel-chip">{filteredDrivers.length}</span>
                    </div>
                    <DriversView
                      drivers={driverAccounts}
                      filteredDrivers={filteredDrivers}
                      search={search}
                      activeActionKey={activeActionKey}
                      accounts={accounts}
                      onSearchChange={setSearch}
                      onApproveAccount={handleToggleDriverApproval}
                      onOpenReject={(target) => openRejectConfirm(target)}
                      onSuspend={handleSuspendAccount}
                      onOpenDelete={openDeleteConfirm}
                    />
                  </div>
                </section>
              ) : null}

              {view === 'accounts' ? (
                <section className="main-grid couriers-only">
                  <div className="panel wide">
                    <div className="panel-header">
                      <div>
                        <h3>جميع حسابات المنصة</h3>
                        <p>مصنّفة حسب نوع الحساب — اختر التبويب المناسب للبحث والفرز.</p>
                      </div>
                      <span className="panel-chip">{filteredAccounts.length}</span>
                    </div>
                    <AccountsView
                      accounts={accounts}
                      filteredAccounts={filteredAccounts}
                      search={search}
                      accountFilter={accountFilter}
                      activeActionKey={activeActionKey}
                      accountKindLabel={accountKindLabel}
                      onSearchChange={setSearch}
                      onFilterChange={setAccountFilter}
                      onOpenDelete={openDeleteConfirm}
                      onSuspend={handleSuspendAccount}
                      onRoleChange={handleChangeRole}
                      onApproveAccount={handleApproveAccount}
                      onOpenReject={(target) => openRejectConfirm(target)}
                    />
                  </div>
                </section>
              ) : null}

              {view === 'homeCategories' ? (
                <HomeCategoriesView
                  config={homeCategoriesConfig}
                  isLoading={isLoadingHomeCategories}
                  savingKey={homeCategorySavingKey}
                  onToggle={handleHomeCategoryPlatformToggle}
                />
              ) : null}

              {view === 'appUpdate' ? (
                <AppUpdateView
                  policy={appUpdatePolicy}
                  draft={appUpdateDraft}
                  isSaving={isSavingAppUpdate}
                  formatDate={formatDate}
                  onDraftChange={(partial) => setAppUpdateDraft((prev) => ({ ...prev, ...partial }))}
                  onSave={handleSaveAppUpdatePolicy}
                />
              ) : null}
            </>
          )}
        </section>
      </div>

      <DeleteModal
        target={deleteTarget}
        isBusy={activeActionKey.startsWith('delete-account:')}
        onConfirm={handleDeleteAccount}
        onClose={() => setDeleteTarget(null)}
      />

      <RejectModal
        target={rejectAccountTarget}
        rejectMessage={rejectMessage}
        isBusy={activeActionKey.startsWith('reject-account:')}
        onMessageChange={setRejectMessage}
        onConfirm={handleRejectAccount}
        onClose={() => { setRejectAccountTarget(null); setRejectMessage(''); }}
      />
    </main>
  );
}
