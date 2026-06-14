import { FormEvent, ReactNode, useEffect, useMemo, useRef, useState } from 'react';
import {
  AlertTriangle,
  BadgeCheck,
  BarChart3,
  Bike,
  Building2,
  ExternalLink,
  Grid3x3,
  LoaderCircle,
  Lock,
  LogOut,
  Menu,
  Package2,
  Search,
  Shield,
  ShoppingBag,
  Smartphone,
  Store,
  Trash2,
  UserX,
  Users,
  X,
  XCircle,
} from 'lucide-react';

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
  rejectMerchantApplication,
  sendCode,
  suspendAdminAccount,
  syncMerchantBazaarProducts,
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
  MerchantDetails,
  MerchantSummary,
} from './admin-types';
import {
  COURIER_REJECTION_REASONS,
  DEFAULT_HOME_CATEGORY_IDS,
  MERCHANT_REJECTION_REASONS,
  TOGGLEABLE_HOME_CATEGORIES,
} from './admin-types';

type RejectAccountTarget = Pick<
  AdminAccountSummary,
  'phone' | 'displayName' | 'kind'
>;

const SESSION_STORAGE_KEY = 'alghaith-admin-session-v1';

type AdminView =
  | 'dashboard'
  | 'accounts'
  | 'merchants'
  | 'approvals'
  | 'couriers'
  | 'homeCategories'
  | 'appUpdate';
type AccountFilter = 'all' | AdminAccountKind;
type MerchantFilter = 'all' | 'pending' | 'professionals';

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
    title: 'قائمة التجار',
    subtitle: 'استعراض الحالة، الأرباح، الطلبات، وإجراءات التجميد والبازار.',
    showSearch: true,
  },
  approvals: {
    eyebrow: 'موافقات البازار',
    title: 'طلبات النشر في بازار الغيث',
    subtitle: 'الموافقة تفتح للتاجر قسم بازار ومطاعم الغيث لأول مرة فقط.',
    showSearch: true,
  },
  couriers: {
    eyebrow: 'مندوبو التوصيل',
    title: 'إدارة مندوبي التوصيل',
    subtitle: 'راجع بيانات المندوب ووافق على تفعيل حسابه قبل استقبال الطلبات.',
    showSearch: true,
  },
  accounts: {
    eyebrow: 'إدارة الحسابات',
    title: 'جميع حسابات المنصة',
    subtitle: 'حذف أو تعليق حسابات الزبائن، التجار، المهنيين، مندوبي التوصيل، وسائقي التكسي.',
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
    return {
      token: String(parsed.token),
      phoneNumber: String(parsed.phoneNumber),
    };
  } catch (_) {
    return null;
  }
}

function readPlatformBool(value: unknown): boolean | null {
  if (value === true || value === false) return value;
  if (value === 1 || value === '1' || value === 'true') return true;
  if (value === 0 || value === '0' || value === 'false') return false;
  return null;
}

function isCategoryEnabledOnPlatform(
  categoryId: string,
  platform: 'android' | 'ios',
  overrides: HomeCategoriesConfig['overrides'],
) {
  const override = overrides[categoryId];
  if (override) {
    const platformValue = readPlatformBool(override[platform]);
    if (platformValue !== null) return platformValue;
    const defaultValue = readPlatformBool(override.default);
    if (defaultValue !== null) return defaultValue;
  }
  return DEFAULT_HOME_CATEGORY_IDS.has(categoryId);
}

function App() {
  const [token, setToken] = useState<string | null>(null);
  const [phoneNumber, setPhoneNumber] = useState<string>('');
  const [inputPhone, setInputPhone] = useState('');
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
  const [merchantFilter, setMerchantFilter] = useState<MerchantFilter>('pending');
  const [selectedMerchantPhone, setSelectedMerchantPhone] = useState('');
  const [merchantDetails, setMerchantDetails] = useState<MerchantDetails | null>(
    null,
  );
  const [isLoadingData, setIsLoadingData] = useState(false);
  const [isLoadingDetails, setIsLoadingDetails] = useState(false);
  const [activeActionKey, setActiveActionKey] = useState('');
  const [rejectAccountTarget, setRejectAccountTarget] =
    useState<RejectAccountTarget | null>(null);
  const [rejectMessage, setRejectMessage] = useState('');
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<AdminAccountSummary | null>(null);
  const [appUpdatePolicy, setAppUpdatePolicy] = useState<AppUpdatePolicy | null>(null);
  const [appUpdateDraft, setAppUpdateDraft] = useState({
    minBuildNumber: '62',
    minVersionName: '1.2.30',
    latestBuildNumber: '0',
    latestVersionName: '',
    messageAr:
      'يجب تحديث التطبيق للمتابعة. الرجاء التحديث من المتجر للاستمرار في استخدام الغيث.',
    androidStoreUrl:
      'https://play.google.com/store/apps/details?id=com.alghaith.app',
    iosStoreUrl: 'https://apps.apple.com/app/id6776741811',
  });
  const [isSavingAppUpdate, setIsSavingAppUpdate] = useState(false);
  const [homeCategoriesConfig, setHomeCategoriesConfig] =
    useState<HomeCategoriesConfig | null>(null);
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
      } catch (accountsError) {
        setAccounts([]);
        const accountsMessage =
          accountsError instanceof Error
            ? accountsError.message
            : 'تعذر تحميل قائمة الحسابات.';
        setActionError(
          `تعذر تحميل تبويب إدارة الحسابات: ${accountsMessage}`,
        );
      }

      const merchantPhone =
        preferredMerchantPhone ||
        selectedMerchantPhone ||
        nextMerchants[0]?.phone ||
        '';
      if (merchantPhone) {
        setSelectedMerchantPhone(merchantPhone);
      }
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
        const message =
          error instanceof Error
            ? error.message
            : 'تعذر تحميل إعدادات التحديث الإجباري.';
        setActionError(message);
      });
  }, [token, view]);

  useEffect(() => {
    if (!token || view !== 'homeCategories') return;
    const seq = ++homeCategoriesLoadSeq.current;
    setIsLoadingHomeCategories(true);
    setActionError('');
    loadHomeCategoriesConfig(token)
      .then((config) => {
        if (seq !== homeCategoriesLoadSeq.current) return;
        if (seq <= homeCategoriesSaveSeq.current) return;
        setHomeCategoriesConfig(config);
      })
      .catch((error) => {
        if (seq !== homeCategoriesLoadSeq.current) return;
        const message =
          error instanceof Error
            ? error.message
            : 'تعذر تحميل إعدادات أقسام الصفحة الرئيسية.';
        setActionError(message);
      })
      .finally(() => {
        if (seq === homeCategoriesLoadSeq.current) {
          setIsLoadingHomeCategories(false);
        }
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
      .then((data) => {
        if (!cancelled) {
          setMerchantDetails(data);
        }
      })
      .catch((error) => {
        if (!cancelled) {
          const message =
            error instanceof Error ? error.message : 'تعذر تحميل تفاصيل التاجر.';
          setActionError(message);
        }
      })
      .finally(() => {
        if (!cancelled) {
          setIsLoadingDetails(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [selectedMerchantPhone, token]);

  const filteredMerchants = useMemo(() => {
    const query = search.trim().toLowerCase();
    return merchants.filter((merchant) => {
      if (merchantFilter === 'pending') {
        if (merchant.isApproved || merchant.approvalStatus !== 'pending') {
          return false;
        }
      } else if (merchantFilter === 'professionals') {
        if (
          merchant.primaryServiceId !== 'professionals' &&
          !merchant.isProfessional
        ) {
          return false;
        }
      }
      if (!query) return true;
      const haystack = [
        merchant.storeName,
        merchant.fullName,
        merchant.phone,
        merchant.primaryServiceId,
        merchant.isProfessional ? 'مهني' : '',
      ]
        .join(' ')
        .toLowerCase();
      return haystack.includes(query);
    });
  }, [merchants, search, merchantFilter]);

  const approvalQueue = useMemo(
    () =>
      merchants.filter(
        (merchant) =>
          canRequestBazaarApproval(merchant) && merchant.isBazaarMember !== true,
      ),
    [merchants],
  );

  const pendingCourierQueue = useMemo(
    () =>
      couriers.filter(
        (courier) =>
          !courier.isApproved &&
          (courier.approvalStatus === 'pending' || !courier.approvalStatus),
      ),
    [couriers],
  );

  const pendingMerchantQueue = useMemo(
    () =>
      merchants.filter(
        (merchant) =>
          !merchant.isApproved && merchant.approvalStatus === 'pending',
      ),
    [merchants],
  );

  const filteredAccounts = useMemo(() => {
    const query = search.trim().toLowerCase();
    return accounts.filter((account) => {
      if (accountFilter !== 'all' && account.kind !== accountFilter) {
        return false;
      }
      if (!query) return true;
      const haystack = [
        account.displayName,
        account.fullName,
        account.phone,
        account.kind,
        account.merchantStoreName,
        account.primaryServiceId,
      ]
        .join(' ')
        .toLowerCase();
      return haystack.includes(query);
    });
  }, [accounts, accountFilter, search]);

  const filteredCouriers = useMemo(() => {
    const query = search.trim().toLowerCase();
    if (!query) return couriers;
    return couriers.filter((courier) => {
      const haystack = [
        courier.name,
        courier.contactPhone,
        courier.phone,
        courier.homeAddress,
      ]
        .join(' ')
        .toLowerCase();
      return haystack.includes(query);
    });
  }, [couriers, search]);

  async function handleSendCode(event: FormEvent) {
    event.preventDefault();
    setIsSendingCode(true);
    setBootError('');
    try {
      await sendCode(inputPhone, 'sms');
      setOtpSent(true);
      setSuccessMessage('تم إرسال رمز التحقق إلى الرقم المدخل.');
    } catch (error) {
      const message = error instanceof Error ? error.message : 'تعذر إرسال الرمز.';
      setBootError(message);
    } finally {
      setIsSendingCode(false);
    }
  }

  async function handleVerifyCode(event: FormEvent) {
    event.preventDefault();
    setIsVerifyingCode(true);
    setBootError('');
    try {
      const session = await verifyCode(inputPhone, otpCode);
      const nextSession: StoredSession = {
        token: session.token,
        phoneNumber: session.phoneNumber,
      };
      window.localStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(nextSession));
      setToken(session.token);
      setPhoneNumber(session.phoneNumber);
      setInputPhone(session.phoneNumber);
      setSuccessMessage('تم تسجيل الدخول بنجاح إلى لوحة الإدارة.');
    } catch (error) {
      const message = error instanceof Error ? error.message : 'تعذر تأكيد الرمز.';
      setBootError(message);
    } finally {
      setIsVerifyingCode(false);
    }
  }

  function switchView(nextView: AdminView) {
    setView(nextView);
    setSearch('');
    setSidebarOpen(false);
  }

  async function handleSaveAppUpdatePolicy() {
    if (!token) return;
    const minBuildNumber = Number.parseInt(appUpdateDraft.minBuildNumber, 10);
    const latestBuildNumber = Number.parseInt(appUpdateDraft.latestBuildNumber, 10);
    if (!Number.isFinite(minBuildNumber) || minBuildNumber < 1) {
      setActionError('أدخل رقم بناء صحيحاً (1 أو أكثر).');
      return;
    }
    if (!Number.isFinite(latestBuildNumber) || latestBuildNumber < 0) {
      setActionError('أدخل أحدث رقم بناء صحيحاً (0 أو أكثر).');
      return;
    }
    if (!appUpdateDraft.messageAr.trim()) {
      setActionError('اكتب رسالة تظهر للمستخدم عند طلب التحديث.');
      return;
    }
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
      const message =
        error instanceof Error ? error.message : 'تعذر حفظ إعدادات التحديث.';
      setActionError(message);
    } finally {
      setIsSavingAppUpdate(false);
    }
  }

  async function handleHomeCategoryPlatformToggle(
    categoryId: string,
    platform: 'android' | 'ios',
    enabled: boolean,
  ) {
    if (!token) return;
    const savingKey = `${categoryId}:${platform}`;
    setHomeCategorySavingKey(savingKey);
    setActionError('');
    setSuccessMessage('');
    const previous = homeCategoriesConfig;
    const overrides = { ...(homeCategoriesConfig?.overrides || {}) };
    overrides[categoryId] = {
      ...(overrides[categoryId] || {}),
      [platform]: enabled,
    };
    const saveSeq = ++homeCategoriesSaveSeq.current;
    setHomeCategoriesConfig({
      overrides,
      updatedAt: homeCategoriesConfig?.updatedAt || null,
    });
    try {
      const saved = await saveHomeCategoriesConfig(token, overrides);
      if (saveSeq !== homeCategoriesSaveSeq.current) return;
      setHomeCategoriesConfig(saved);
      setSuccessMessage('تم حفظ إعدادات الأقسام.');
    } catch (error) {
      if (saveSeq !== homeCategoriesSaveSeq.current) return;
      if (previous) setHomeCategoriesConfig(previous);
      const message =
        error instanceof Error ? error.message : 'تعذر حفظ إعدادات الأقسام.';
      setActionError(message);
    } finally {
      setHomeCategorySavingKey('');
    }
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

  async function handleBazaarSync(merchant: MerchantSummary) {
    if (!token) return;
    const actionKey = `sync:${merchant.phone}`;
    setActiveActionKey(actionKey);
    setActionError('');
    setSuccessMessage('');
    try {
      const result = await syncMerchantBazaarProducts(token, merchant.phone);
      setSuccessMessage(
        `تمت مزامنة ${merchant.storeName || merchant.phone}. ${result.totalEligible} منتج جاهز للظهور في البازار.`,
      );
      await refreshCoreData(token, merchant.phone);
      const details = await loadMerchantDetails(token, merchant.phone);
      setMerchantDetails(details);
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'تعذر مزامنة ظهور البازار.';
      setActionError(message);
    } finally {
      setActiveActionKey('');
    }
  }

  async function handleMerchantApproval(merchant: MerchantSummary) {
    if (!token) return;
    const enabling = merchant.isApproved !== true;
    const actionKey = `merchant-approval:${merchant.phone}`;
    setActiveActionKey(actionKey);
    setActionError('');
    setSuccessMessage('');
    try {
      await toggleMerchantApproval(token, merchant.phone, enabling);
      setSuccessMessage(
        enabling
          ? `تم تفعيل حساب التاجر ${merchant.storeName || merchant.phone}.`
          : `تم إلغاء تفعيل حساب التاجر ${merchant.storeName || merchant.phone}.`,
      );
      await refreshCoreData(token, merchant.phone);
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'تعذر تحديث حالة التاجر.';
      setActionError(message);
    } finally {
      setActiveActionKey('');
    }
  }

  function openRejectConfirm(target: RejectAccountTarget) {
    setRejectAccountTarget(target);
    setRejectMessage('');
  }

  async function handleRejectAccount() {
    if (!token || !rejectAccountTarget) return;
    const message = rejectMessage.trim();
    if (!message) {
      setActionError('يرجى كتابة سبب الرفض ليظهر للمستخدم.');
      return;
    }
    const actionKey = `reject-account:${rejectAccountTarget.phone}`;
    setActiveActionKey(actionKey);
    setActionError('');
    setSuccessMessage('');
    try {
      if (rejectAccountTarget.kind === 'merchant') {
        await rejectMerchantApplication(token, rejectAccountTarget.phone, message);
      } else if (rejectAccountTarget.kind === 'courier') {
        await rejectCourierApplication(token, rejectAccountTarget.phone, message);
      } else if (rejectAccountTarget.kind === 'driver') {
        await rejectDriverApplication(token, rejectAccountTarget.phone, message);
      } else {
        throw new Error('لا يمكن رفض هذا النوع من الحسابات.');
      }
      setSuccessMessage(
        `تم رفض طلب ${rejectAccountTarget.displayName || rejectAccountTarget.phone} وإرسال السبب للمستخدم.`,
      );
      setRejectAccountTarget(null);
      setRejectMessage('');
      await refreshCoreData(token);
    } catch (error) {
      const messageText =
        error instanceof Error ? error.message : 'تعذر رفض الطلب.';
      setActionError(messageText);
    } finally {
      setActiveActionKey('');
    }
  }

  async function handleApproveAccount(account: AdminAccountSummary) {
    if (!token || !accountNeedsApproval(account)) return;
    const actionKey = `approve-account:${account.phone}`;
    setActiveActionKey(actionKey);
    setActionError('');
    setSuccessMessage('');
    try {
      if (account.kind === 'merchant') {
        await toggleMerchantApproval(token, account.phone, true);
      } else if (account.kind === 'courier') {
        await toggleCourierApproval(token, account.phone, true);
      } else if (account.kind === 'driver') {
        await toggleDriverApproval(token, account.phone, true);
      }
      setSuccessMessage(
        `تمت موافقة وتفعيل حساب ${account.displayName || account.phone}.`,
      );
      await refreshCoreData(token, account.kind === 'merchant' ? account.phone : undefined);
    } catch (error) {
      const messageText =
        error instanceof Error ? error.message : 'تعذر تفعيل الحساب.';
      setActionError(messageText);
    } finally {
      setActiveActionKey('');
    }
  }

  async function handleCourierApproval(courier: CourierSummary) {
    if (!token) return;
    const enabling = courier.isApproved !== true;
    const actionKey = `courier:${courier.phone}`;
    setActiveActionKey(actionKey);
    setActionError('');
    setSuccessMessage('');
    try {
      await toggleCourierApproval(token, courier.phone, enabling);
      setSuccessMessage(
        enabling
          ? `تم تفعيل حساب المندوب ${courier.name || courier.phone}.`
          : `تم إلغاء تفعيل حساب المندوب ${courier.name || courier.phone}.`,
      );
      await refreshCoreData(token);
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'تعذر تحديث حالة المندوب.';
      setActionError(message);
    } finally {
      setActiveActionKey('');
    }
  }

  function openDeleteConfirm(target: AdminAccountSummary) {
    if (target.kind === 'admin') {
      setActionError('لا يمكن حذف حساب مشرف محمي.');
      return;
    }
    setDeleteTarget(target);
  }

  async function handleDeleteAccount() {
    if (!token || !deleteTarget) return;
    const actionKey = `delete-account:${deleteTarget.phone}`;
    setActiveActionKey(actionKey);
    setActionError('');
    setSuccessMessage('');
    try {
      await deleteAdminAccount(token, deleteTarget.phone);
      setSuccessMessage(
        `تم حذف حساب ${deleteTarget.displayName || deleteTarget.phone} نهائياً.`,
      );
      setDeleteTarget(null);
      if (selectedMerchantPhone === deleteTarget.phone) {
        setSelectedMerchantPhone('');
        setMerchantDetails(null);
      }
      await refreshCoreData(token);
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'تعذر حذف الحساب.';
      setActionError(message);
    } finally {
      setActiveActionKey('');
    }
  }

  async function handleSuspendAccount(account: AdminAccountSummary) {
    if (!token) return;
    if (account.kind === 'admin') {
      setActionError('لا يمكن تعليق حساب مشرف محمي.');
      return;
    }
    const enabling = account.isSuspended === true;
    const actionKey = `suspend-account:${account.phone}`;
    setActiveActionKey(actionKey);
    setActionError('');
    setSuccessMessage('');
    try {
      await suspendAdminAccount(token, account.phone, !enabling);
      setSuccessMessage(
        enabling
          ? `تم فك تعليق حساب ${account.displayName || account.phone}.`
          : `تم تعليق حساب ${account.displayName || account.phone}.`,
      );
      await refreshCoreData(token, account.phone);
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'تعذر تحديث حالة التعليق.';
      setActionError(message);
    } finally {
      setActiveActionKey('');
    }
  }

  async function handleMerchantAction(
    merchant: MerchantSummary,
    kind: 'freeze' | 'bazaar',
  ) {
    if (!token) return;
    const actionKey = `${kind}:${merchant.phone}`;
    setActiveActionKey(actionKey);
    setActionError('');
    setSuccessMessage('');
    try {
      if (kind === 'freeze') {
        await toggleMerchantFreeze(token, merchant.phone, !merchant.isFrozen);
        setSuccessMessage(
          merchant.isFrozen
            ? `تم فك تجميد ${merchant.storeName || merchant.phone}.`
            : `تم تجميد ${merchant.storeName || merchant.phone}.`,
        );
      } else {
        const enabling = merchant.isBazaarMember !== true;
        const result = await toggleMerchantBazaar(
          token,
          merchant.phone,
          enabling,
        );
        if (enabling) {
          const total = result.bazaarProductSync?.totalEligible ?? 0;
          setSuccessMessage(
            `تمت الموافقة على ${merchant.storeName || merchant.phone} داخل بازار ومطاعم الغيث. ${total} منتج يظهر الآن في قسمه وفي البازار معاً.`,
          );
        } else {
          setSuccessMessage(
            `تم سحب موافقة بازار من ${merchant.storeName || merchant.phone}.`,
          );
        }
      }

      await refreshCoreData(token, merchant.phone);
      const details = await loadMerchantDetails(token, merchant.phone);
      setMerchantDetails(details);
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'تعذر تنفيذ العملية الإدارية.';
      setActionError(message);
    } finally {
      setActiveActionKey('');
    }
  }

  const viewMeta = VIEW_META[view];
  const frozenMerchants = merchants.filter((merchant) => merchant.isFrozen).length;

  if (!token) {
    return (
      <main className="auth-shell">
        <section className="auth-card">
          <div className="brand-badge">
            <Shield size={30} />
          </div>
          <div className="auth-copy">
            <p className="eyebrow">الغيث · إدارة</p>
            <h1>لوحة إدارة المنصة</h1>
            <p>
              دخول آمن برقم الهاتف لإدارة التجار، مندوبي التوصيل، موافقات بازار
              الغيث، ومتابعة إحصائيات المنصة.
            </p>
          </div>

          <form className="auth-form" onSubmit={otpSent ? handleVerifyCode : handleSendCode}>
            <label>
              <span>رقم الهاتف</span>
              <input
                dir="ltr"
                placeholder="07744009992 أو +9647744009992"
                value={inputPhone}
                onChange={(event) => setInputPhone(event.target.value)}
              />
            </label>

            {otpSent ? (
              <label>
                <span>رمز التحقق</span>
                <input
                  dir="ltr"
                  placeholder="000000"
                  value={otpCode}
                  onChange={(event) => setOtpCode(event.target.value)}
                />
              </label>
            ) : null}

            {bootError ? <div className="message error">{bootError}</div> : null}
            {successMessage ? <div className="message success">{successMessage}</div> : null}

            <button
              className="primary-button"
              type="submit"
              disabled={isSendingCode || isVerifyingCode}
            >
              {isSendingCode || isVerifyingCode ? (
                <LoaderCircle className="spin" size={18} />
              ) : otpSent ? (
                <BadgeCheck size={18} />
              ) : (
                <Lock size={18} />
              )}
              <span>{otpSent ? 'تأكيد الدخول' : 'إرسال رمز التحقق'}</span>
            </button>
          </form>
        </section>
      </main>
    );
  }

  return (
    <main className="admin-shell">
      <div
        className={sidebarOpen ? 'sidebar-overlay open' : 'sidebar-overlay'}
        onClick={() => setSidebarOpen(false)}
        role="presentation"
      />
      <section className="dashboard-layout">
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
              onClick={() => switchView('dashboard')}
            >
              <BarChart3 size={18} />
              <span>الملخص العام</span>
            </button>
            <button
              className={view === 'accounts' ? 'nav-item active' : 'nav-item'}
              onClick={() => switchView('accounts')}
            >
              <Users size={18} />
              <span>إدارة الحسابات</span>
            </button>
            <button
              className={view === 'merchants' ? 'nav-item active' : 'nav-item'}
              onClick={() => switchView('merchants')}
            >
              <Store size={18} />
              <span>إدارة التجار</span>
              {pendingMerchantQueue.length > 0 ? (
                <span className="nav-badge">{pendingMerchantQueue.length}</span>
              ) : null}
            </button>
            <button
              className={view === 'approvals' ? 'nav-item active' : 'nav-item'}
              onClick={() => switchView('approvals')}
            >
              <BadgeCheck size={18} />
              <span>موافقات البازار</span>
              {approvalQueue.length > 0 ? (
                <span className="nav-badge">{approvalQueue.length}</span>
              ) : null}
            </button>
            <button
              className={view === 'couriers' ? 'nav-item active' : 'nav-item'}
              onClick={() => switchView('couriers')}
            >
              <Bike size={18} />
              <span>مندوبو التوصيل</span>
              {pendingCourierQueue.length > 0 ? (
                <span className="nav-badge">{pendingCourierQueue.length}</span>
              ) : null}
            </button>
            <button
              className={view === 'homeCategories' ? 'nav-item active' : 'nav-item'}
              onClick={() => switchView('homeCategories')}
            >
              <Grid3x3 size={18} />
              <span>أقسام الرئيسية</span>
            </button>
            <button
              className={view === 'appUpdate' ? 'nav-item active' : 'nav-item'}
              onClick={() => switchView('appUpdate')}
            >
              <Smartphone size={18} />
              <span>تحديث التطبيق</span>
            </button>
          </nav>

          <button className="ghost-button logout" onClick={handleLogout}>
            <LogOut size={18} />
            <span>تسجيل الخروج</span>
          </button>
        </aside>

        <section className="content">
          <div className="content-top">
            <button
              className="mobile-menu-button"
              type="button"
              aria-label="فتح القائمة"
              onClick={() => setSidebarOpen(true)}
            >
              <Menu size={20} />
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
                    placeholder={
                      view === 'couriers'
                        ? 'ابحث عن مندوب أو رقم هاتف'
                        : view === 'accounts'
                          ? 'ابحث عن حساب أو رقم هاتف'
                          : 'ابحث عن تاجر أو رقم هاتف'
                    }
                    value={search}
                    onChange={(event) => setSearch(event.target.value)}
                  />
                </div>
              ) : null}
            </header>
          </div>

          {bootError || actionError || successMessage ? (
            <div className="alert-stack sticky-alerts">
              {bootError ? <div className="message error">{bootError}</div> : null}
              {actionError ? <div className="message error">{actionError}</div> : null}
              {successMessage ? (
                <div className="message success">{successMessage}</div>
              ) : null}
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
                <>
                  <section className="metrics-grid">
                    <MetricCard
                      icon={<ShoppingBag size={18} />}
                      title="إجمالي الطلبات"
                      value={String(reports?.totalOrders || 0)}
                      hint={`${reports?.completedOrders || 0} مكتمل`}
                    />
                    <MetricCard
                      icon={<Store size={18} />}
                      title="التجار النشطون"
                      value={String(reports?.openMerchants || 0)}
                      hint={`${reports?.totalMerchants || 0} إجمالي`}
                    />
                    <MetricCard
                      icon={<Users size={18} />}
                      title="إجمالي المستخدمين"
                      value={String(reports?.totalUsers || 0)}
                      hint={`${reports?.totalProducts || 0} منتج`}
                    />
                    <MetricCard
                      icon={<BarChart3 size={18} />}
                      title="إجمالي المبيعات"
                      value={`${formatMoney(reports?.totalSales || 0)} د.ع`}
                      hint={`${formatMoney(reports?.codCollected || 0)} COD`}
                    />
                  </section>

                  <section className="quick-actions-grid">
                    <article className="quick-action-card">
                      <p>موافقات بازار معلقة</p>
                      <strong>{approvalQueue.length}</strong>
                      <button
                        className="soft-button"
                        type="button"
                        onClick={() => switchView('approvals')}
                      >
                        <BadgeCheck size={16} />
                        <span>مراجعة الطلبات</span>
                      </button>
                    </article>
                    <article className="quick-action-card">
                      <p>مندوبون بانتظار الموافقة</p>
                      <strong>{pendingCourierQueue.length}</strong>
                      <button
                        className="soft-button"
                        type="button"
                        onClick={() => switchView('couriers')}
                      >
                        <Bike size={16} />
                        <span>مراجعة المندوبين</span>
                      </button>
                    </article>
                    <article className="quick-action-card">
                      <p>تجار بانتظار الموافقة</p>
                      <strong>{pendingMerchantQueue.length}</strong>
                      <button
                        className="soft-button"
                        type="button"
                        onClick={() => {
                          setMerchantFilter('pending');
                          switchView('merchants');
                        }}
                      >
                        <Store size={16} />
                        <span>مراجعة التجار والمهنيين</span>
                      </button>
                    </article>
                    <article className="quick-action-card">
                      <p>تجار مجمّدون</p>
                      <strong>{frozenMerchants}</strong>
                      <button
                        className="soft-button"
                        type="button"
                        onClick={() => switchView('merchants')}
                      >
                        <Store size={16} />
                        <span>إدارة التجار</span>
                      </button>
                    </article>
                  </section>
                </>
              ) : null}

              {view === 'homeCategories' ? (
                <section className="panel home-categories-panel">
                  <div className="panel-header">
                    <div>
                      <h3>أقسام الصفحة الرئيسية</h3>
                      <p>
                        مثال: فعّل «السيارات» على أندرويد وأطفئها على آيفون. الأقسام
                        غير المحددة تستخدم الإعداد الافتراضي (المطاعم، التسوق، السيارات).
                      </p>
                    </div>
                  </div>

                  {isLoadingHomeCategories ? (
                    <div className="loading-state compact">
                      <LoaderCircle className="spin" size={22} />
                      <span>جار تحميل إعدادات الأقسام...</span>
                    </div>
                  ) : (
                  <div className="home-category-list">
                    {TOGGLEABLE_HOME_CATEGORIES.map((category) => {
                      const overrides = homeCategoriesConfig?.overrides || {};
                      const androidEnabled = isCategoryEnabledOnPlatform(
                        category.id,
                        'android',
                        overrides,
                      );
                      const iosEnabled = isCategoryEnabledOnPlatform(
                        category.id,
                        'ios',
                        overrides,
                      );
                      const androidSaving =
                        homeCategorySavingKey === `${category.id}:android`;
                      const iosSaving =
                        homeCategorySavingKey === `${category.id}:ios`;
                      const togglesDisabled =
                        isLoadingHomeCategories || androidSaving || iosSaving;
                      return (
                        <article key={category.id} className="home-category-card">
                          <h4>{category.titleAr}</h4>
                          <div className="home-category-toggles">
                            <label className="platform-toggle">
                              <span>أندرويد</span>
                              <input
                                type="checkbox"
                                checked={androidEnabled}
                                disabled={togglesDisabled}
                                onChange={(event) => {
                                  handleHomeCategoryPlatformToggle(
                                    category.id,
                                    'android',
                                    event.target.checked,
                                  ).catch(() => undefined);
                                }}
                              />
                              <em>{androidEnabled ? 'ظاهر' : 'مخفي'}</em>
                            </label>
                            <label className="platform-toggle">
                              <span>آيفون</span>
                              <input
                                type="checkbox"
                                checked={iosEnabled}
                                disabled={togglesDisabled}
                                onChange={(event) => {
                                  handleHomeCategoryPlatformToggle(
                                    category.id,
                                    'ios',
                                    event.target.checked,
                                  ).catch(() => undefined);
                                }}
                              />
                              <em>{iosEnabled ? 'ظاهر' : 'مخفي'}</em>
                            </label>
                          </div>
                        </article>
                      );
                    })}
                  </div>
                  )}

                  {homeCategoriesConfig?.updatedAt ? (
                    <p className="app-update-meta">
                      آخر تحديث للإعدادات: {formatDate(homeCategoriesConfig.updatedAt)}
                    </p>
                  ) : null}
                </section>
              ) : null}

              {view === 'appUpdate' ? (
                <section className="panel app-update-panel">
                  <div className="panel-header">
                    <div>
                      <h3>إعدادات التحديث الإجباري</h3>
                      <p>
                        «أقل رقم بناء» يُجبر المستخدمين القدامى على التحديث.
                        «أحدث رقم بناء» يُستخدم عند الضغط على «التحقق من تحديث التطبيق».
                      </p>
                    </div>
                  </div>

                  <div className="app-update-form">
                    <label className="app-update-field">
                      <span>أقل رقم بناء مسموح (تحديث إجباري)</span>
                      <input
                        dir="ltr"
                        type="number"
                        min={1}
                        value={appUpdateDraft.minBuildNumber}
                        onChange={(event) =>
                          setAppUpdateDraft((current) => ({
                            ...current,
                            minBuildNumber: event.target.value,
                          }))
                        }
                      />
                      <small>من دون هذا الرقم تظهر شاشة تحديث بدون تخطي.</small>
                    </label>

                    <label className="app-update-field">
                      <span>أحدث رقم بناء في المتجر (للتحقق اليدوي)</span>
                      <input
                        dir="ltr"
                        type="number"
                        min={0}
                        value={appUpdateDraft.latestBuildNumber}
                        onChange={(event) =>
                          setAppUpdateDraft((current) => ({
                            ...current,
                            latestBuildNumber: event.target.value,
                          }))
                        }
                      />
                      <small>مثال: 53 من pubspec.yaml → version: 1.2.22+53</small>
                    </label>

                    <label className="app-update-field">
                      <span>أحدث اسم إصدار في المتجر</span>
                      <input
                        dir="ltr"
                        value={appUpdateDraft.latestVersionName}
                        onChange={(event) =>
                          setAppUpdateDraft((current) => ({
                            ...current,
                            latestVersionName: event.target.value,
                          }))
                        }
                      />
                      <small>مثال: 1.2.22 — يُستخدم مع رقم البناء أو كبديل.</small>
                    </label>

                    <label className="app-update-field">
                      <span>اسم الإصدار للحد الأدنى (اختياري للعرض)</span>
                      <input
                        dir="ltr"
                        value={appUpdateDraft.minVersionName}
                        onChange={(event) =>
                          setAppUpdateDraft((current) => ({
                            ...current,
                            minVersionName: event.target.value,
                          }))
                        }
                      />
                    </label>

                    <label className="app-update-field">
                      <span>الرسالة للمستخدم</span>
                      <textarea
                        rows={4}
                        value={appUpdateDraft.messageAr}
                        onChange={(event) =>
                          setAppUpdateDraft((current) => ({
                            ...current,
                            messageAr: event.target.value,
                          }))
                        }
                      />
                    </label>

                    <label className="app-update-field">
                      <span>رابط Google Play</span>
                      <input
                        dir="ltr"
                        value={appUpdateDraft.androidStoreUrl}
                        onChange={(event) =>
                          setAppUpdateDraft((current) => ({
                            ...current,
                            androidStoreUrl: event.target.value,
                          }))
                        }
                      />
                    </label>

                    <label className="app-update-field">
                      <span>رابط App Store</span>
                      <input
                        dir="ltr"
                        value={appUpdateDraft.iosStoreUrl}
                        onChange={(event) =>
                          setAppUpdateDraft((current) => ({
                            ...current,
                            iosStoreUrl: event.target.value,
                          }))
                        }
                      />
                    </label>

                    {appUpdatePolicy?.updatedAt ? (
                      <p className="app-update-meta">
                        آخر تحديث للإعدادات: {formatDate(appUpdatePolicy.updatedAt)}
                      </p>
                    ) : null}

                    <button
                      className="soft-button success"
                      type="button"
                      disabled={isSavingAppUpdate}
                      onClick={() => {
                        handleSaveAppUpdatePolicy().catch(() => undefined);
                      }}
                    >
                      {isSavingAppUpdate ? (
                        <LoaderCircle className="spin" size={16} />
                      ) : (
                        <BadgeCheck size={16} />
                      )}
                      <span>حفظ الإعدادات</span>
                    </button>
                  </div>
                </section>
              ) : null}

              {view === 'dashboard' ||
              view === 'appUpdate' ||
              view === 'homeCategories' ? null : (
              <section
                className={
                  view === 'couriers' || view === 'approvals' || view === 'accounts'
                    ? 'main-grid couriers-only'
                    : 'main-grid'
                }
              >
                <div className="panel wide">
                  <div className="panel-header">
                    <div>
                      <h3>
                        {view === 'accounts'
                          ? 'جميع الحسابات'
                          : view === 'couriers'
                            ? 'جميع المندوبين'
                            : view === 'approvals'
                              ? 'قائمة الانتظار'
                              : 'جميع التجار والمهنيين'}
                      </h3>
                      <p>
                        {view === 'accounts'
                          ? 'يمكنك تعليق أي حساب أو حذفه نهائياً بعد التأكيد.'
                          : view === 'couriers'
                            ? 'اضغط على الإجراء المناسب لكل مندوب.'
                            : view === 'approvals'
                              ? 'تجار مطاعم ومتاجر بانتظار الموافقة على البازار.'
                              : 'طلبات المهنيين والتجار بانتظار الموافقة تظهر في الأعلى. استخدم الفلاتر أدناه.'}
                      </p>
                    </div>
                    <span className="panel-chip">
                      {view === 'accounts'
                        ? filteredAccounts.length
                        : view === 'couriers'
                          ? filteredCouriers.length
                          : view === 'approvals'
                            ? approvalQueue.length
                            : filteredMerchants.length}
                    </span>
                  </div>

                  {view === 'accounts' ? (
                    <>
                      <div className="account-filter-row">
                        {(
                          [
                            ['all', 'الكل'],
                            ['customer', 'زبائن'],
                            ['merchant', 'تجار'],
                            ['courier', 'مندوبين'],
                            ['driver', 'تكسي'],
                          ] as Array<[AccountFilter, string]>
                        ).map(([filter, label]) => (
                          <button
                            key={filter}
                            type="button"
                            className={
                              accountFilter === filter
                                ? 'account-filter-chip active'
                                : 'account-filter-chip'
                            }
                            onClick={() => setAccountFilter(filter)}
                          >
                            {label}
                          </button>
                        ))}
                      </div>
                      <div className="merchant-list">
                        {filteredAccounts.map((account) => {
                          const suspendLoading =
                            activeActionKey === `suspend-account:${account.phone}`;
                          const deleteLoading =
                            activeActionKey === `delete-account:${account.phone}`;
                          const approvalLoading =
                            activeActionKey === `approve-account:${account.phone}`;
                          const rejectLoading =
                            activeActionKey === `reject-account:${account.phone}`;
                          const isAdmin = account.kind === 'admin';
                          const needsApproval = accountNeedsApproval(account);
                          const isRejected = account.approvalStatus === 'rejected';
                          const isPending =
                            needsApproval && !account.isApproved && !isRejected;
                          return (
                            <article key={account.phone} className="merchant-card account-card">
                              <div className="merchant-main">
                                <div>
                                  <div className="merchant-title-row">
                                    <h4>{account.displayName || 'حساب بدون اسم'}</h4>
                                    <span className="status-badge muted">
                                      {accountKindLabel(account.kind)}
                                    </span>
                                    {needsApproval ? (
                                      account.isApproved ? (
                                        <span className="status-badge success">مفعّل</span>
                                      ) : isRejected ? (
                                        <span className="status-badge danger">مرفوض</span>
                                      ) : (
                                        <span className="status-badge warning">
                                          بانتظار الموافقة
                                        </span>
                                      )
                                    ) : null}
                                    {account.isSuspended ? (
                                      <span className="status-badge danger">معلّق</span>
                                    ) : (
                                      <span className="status-badge success">نشط</span>
                                    )}
                                  </div>
                                  <p className="merchant-meta">
                                    {account.fullName || 'بدون اسم مسجّل'} ·{' '}
                                    <span dir="ltr">{account.phone}</span>
                                  </p>
                                  {account.kind === 'merchant' && account.merchantStoreName ? (
                                    <p className="merchant-description">
                                      {serviceLabel(account.primaryServiceId)} ·{' '}
                                      {account.merchantStoreName}
                                    </p>
                                  ) : (
                                    <p className="merchant-description">
                                      آخر تحديث: {formatDate(account.updatedAt)}
                                    </p>
                                  )}
                                  {isRejected && account.rejectionMessageAr ? (
                                    <p className="courier-rejection-note">
                                      سبب الرفض الحالي: {account.rejectionMessageAr}
                                    </p>
                                  ) : null}
                                </div>
                              </div>
                              <div className="merchant-actions">
                                {needsApproval && isPending ? (
                                  <button
                                    className="soft-button success"
                                    disabled={
                                      approvalLoading || rejectLoading || suspendLoading
                                    }
                                    onClick={() => {
                                      handleApproveAccount(account).catch(() => undefined);
                                    }}
                                  >
                                    {approvalLoading ? (
                                      <LoaderCircle className="spin" size={16} />
                                    ) : (
                                      <BadgeCheck size={16} />
                                    )}
                                    <span>موافقة وتفعيل</span>
                                  </button>
                                ) : null}
                                {needsApproval && (isPending || isRejected) ? (
                                  <button
                                    className="soft-button danger"
                                    disabled={
                                      approvalLoading || rejectLoading || suspendLoading
                                    }
                                    onClick={() => openRejectConfirm(account)}
                                  >
                                    <XCircle size={16} />
                                    <span>رفض مع سبب</span>
                                  </button>
                                ) : null}
                                {!isAdmin ? (
                                  <button
                                    className={
                                      account.isSuspended
                                        ? 'soft-button success'
                                        : 'soft-button danger'
                                    }
                                    disabled={
                                      suspendLoading ||
                                      deleteLoading ||
                                      approvalLoading ||
                                      rejectLoading
                                    }
                                    onClick={() => {
                                      handleSuspendAccount(account).catch(() => undefined);
                                    }}
                                  >
                                    {suspendLoading ? (
                                      <LoaderCircle className="spin" size={16} />
                                    ) : (
                                      <UserX size={16} />
                                    )}
                                    <span>
                                      {account.isSuspended ? 'فك التعليق' : 'تعليق الحساب'}
                                    </span>
                                  </button>
                                ) : null}
                                {!isAdmin ? (
                                  <button
                                    className="soft-button danger"
                                    disabled={
                                      suspendLoading ||
                                      deleteLoading ||
                                      approvalLoading ||
                                      rejectLoading
                                    }
                                    onClick={() => openDeleteConfirm(account)}
                                  >
                                    <Trash2 size={16} />
                                    <span>حذف الحساب</span>
                                  </button>
                                ) : null}
                              </div>
                            </article>
                          );
                        })}
                        {filteredAccounts.length === 0 ? (
                          <div className="empty-state">
                            <Users size={22} />
                            <p>لا توجد حسابات مطابقة للبحث الحالي.</p>
                          </div>
                        ) : null}
                      </div>
                    </>
                  ) : view === 'couriers' ? (
                    <div className="merchant-list">
                      {filteredCouriers.map((courier) => {
                        const approvalLoading =
                          activeActionKey === `courier:${courier.phone}`;
                        const rejectLoading =
                          activeActionKey === `reject-account:${courier.phone}`;
                        const isRejected = courier.approvalStatus === 'rejected';
                        const isPending = !courier.isApproved && !isRejected;
                        return (
                          <article key={courier.phone} className="merchant-card courier-card">
                            <div className="merchant-main">
                              <div className="courier-card-leading">
                                <div>
                                  <div className="merchant-title-row">
                                    <h4>{courier.name || 'مندوب بدون اسم'}</h4>
                                    {courier.isApproved ? (
                                      <span className="status-badge success">مفعّل</span>
                                    ) : isRejected ? (
                                      <span className="status-badge danger">مرفوض</span>
                                    ) : (
                                      <span className="status-badge danger">
                                        بانتظار الموافقة
                                      </span>
                                    )}
                                    {courier.isSuspended ? (
                                      <span className="status-badge danger">معلّق</span>
                                    ) : null}
                                    {courier.isApproved ? (
                                      courier.available ? (
                                        <span className="status-badge success">
                                          متاح للتوصيل
                                        </span>
                                      ) : (
                                        <span className="status-badge muted">غير متاح</span>
                                      )
                                    ) : null}
                                  </div>
                                  <p className="merchant-meta">
                                    هاتف التواصل:{' '}
                                    <span dir="ltr">
                                      {courier.contactPhone || courier.phone}
                                    </span>
                                  </p>
                                  <p className="merchant-description">
                                    {courier.homeAddress || 'لا يوجد عنوان محفوظ.'}
                                  </p>
                                  {isRejected && courier.rejectionMessageAr ? (
                                    <p className="courier-rejection-note">
                                      سبب الرفض: {courier.rejectionMessageAr}
                                    </p>
                                  ) : null}
                                </div>
                              </div>

                              <div className="courier-media-panel">
                                <div className="courier-media-head">
                                  <strong>صورة الدراجة</strong>
                                  {courier.vehicleImage ? (
                                    <a
                                      className="courier-media-link"
                                      href={courier.vehicleImage}
                                      target="_blank"
                                      rel="noreferrer"
                                    >
                                      <ExternalLink size={14} />
                                      <span>عرض بالحجم الكامل</span>
                                    </a>
                                  ) : null}
                                </div>
                                {courier.vehicleImage ? (
                                  <a
                                    href={courier.vehicleImage}
                                    target="_blank"
                                    rel="noreferrer"
                                    className="courier-media-frame"
                                  >
                                    <img
                                      className="courier-media-image"
                                      src={courier.vehicleImage}
                                      alt={courier.name || 'صورة الدراجة'}
                                      loading="lazy"
                                      referrerPolicy="no-referrer"
                                    />
                                  </a>
                                ) : (
                                  <div className="courier-media-empty">
                                    <Bike size={28} />
                                    <span>لم يتم رفع صورة للدراجة</span>
                                  </div>
                                )}
                              </div>
                            </div>

                            <div className="merchant-actions">
                              <button
                                className={
                                  courier.isApproved
                                    ? 'soft-button danger'
                                    : 'soft-button success'
                                }
                                disabled={approvalLoading || rejectLoading}
                                onClick={() => {
                                  handleCourierApproval(courier).catch(() => undefined);
                                }}
                              >
                                {approvalLoading ? (
                                  <LoaderCircle className="spin" size={16} />
                                ) : (
                                  <BadgeCheck size={16} />
                                )}
                                <span>
                                  {courier.isApproved
                                    ? 'إلغاء التفعيل'
                                    : 'موافقة وتفعيل'}
                                </span>
                              </button>

                              {isPending || isRejected ? (
                                <button
                                  className="soft-button danger"
                                  disabled={approvalLoading || rejectLoading}
                                  onClick={() => {
                                    openRejectConfirm({
                                      phone: courier.phone,
                                      displayName: courier.name || courier.phone,
                                      kind: 'courier',
                                    });
                                  }}
                                >
                                  {rejectLoading ? (
                                    <LoaderCircle className="spin" size={16} />
                                  ) : (
                                    <XCircle size={16} />
                                  )}
                                  <span>رفض الطلب</span>
                                </button>
                              ) : null}

                              <button
                                className={
                                  courier.isSuspended
                                    ? 'soft-button success'
                                    : 'soft-button danger'
                                }
                                disabled={
                                  approvalLoading ||
                                  rejectLoading ||
                                  activeActionKey === `suspend-account:${courier.phone}`
                                }
                                onClick={() => {
                                  const account =
                                    accounts.find((item) => item.phone === courier.phone) ?? {
                                      phone: courier.phone,
                                      displayName: courier.name || courier.phone,
                                      fullName: courier.name,
                                      role: courier.role,
                                      accountType: courier.accountType,
                                      kind: 'courier' as const,
                                      isSuspended: courier.isSuspended === true,
                                      merchantStoreName: '',
                                      primaryServiceId: '',
                                      courierApproved: courier.isApproved,
                                      updatedAt: courier.updatedAt,
                                      createdAt: null,
                                      hasMerchantProfile: false,
                                      hasCourierProfile: true,
                                      hasDriverProfile: false,
                                    };
                                  handleSuspendAccount(account).catch(() => undefined);
                                }}
                              >
                                {activeActionKey === `suspend-account:${courier.phone}` ? (
                                  <LoaderCircle className="spin" size={16} />
                                ) : (
                                  <UserX size={16} />
                                )}
                                <span>
                                  {courier.isSuspended ? 'فك التعليق' : 'تعليق الحساب'}
                                </span>
                              </button>

                              <button
                                className="soft-button danger"
                                disabled={approvalLoading || rejectLoading}
                                onClick={() => {
                                  openDeleteConfirm(
                                    accounts.find((item) => item.phone === courier.phone) ?? {
                                      phone: courier.phone,
                                      displayName: courier.name || courier.phone,
                                      fullName: courier.name,
                                      role: courier.role,
                                      accountType: courier.accountType,
                                      kind: 'courier',
                                      isSuspended: courier.isSuspended === true,
                                      merchantStoreName: '',
                                      primaryServiceId: '',
                                      courierApproved: courier.isApproved,
                                      updatedAt: courier.updatedAt,
                                      createdAt: null,
                                      hasMerchantProfile: false,
                                      hasCourierProfile: true,
                                      hasDriverProfile: false,
                                    },
                                  );
                                }}
                              >
                                <Trash2 size={16} />
                                <span>حذف الحساب</span>
                              </button>
                            </div>
                          </article>
                        );
                      })}

                      {filteredCouriers.length === 0 ? (
                        <div className="empty-state">
                          <Bike size={22} />
                          <p>لا يوجد مندوبو توصيل مطابقون للبحث الحالي.</p>
                        </div>
                      ) : null}
                    </div>
                  ) : (
                  <>
                  {view === 'merchants' ? (
                      <div className="account-filter-row">
                        {(
                          [
                            ['pending', `طلبات الموافقة (${pendingMerchantQueue.length})`],
                            ['all', 'المسجلين حالياً'],
                            ['professionals', 'المهنيون'],
                          ] as Array<[MerchantFilter, string]>
                        ).map(([filter, label]) => (
                          <button
                            key={filter}
                            type="button"
                            className={
                              merchantFilter === filter
                                ? 'filter-chip active'
                                : 'filter-chip'
                            }
                            onClick={() => setMerchantFilter(filter)}
                          >
                            {label}
                          </button>
                        ))}
                      </div>
                  ) : null}
                  <div className="merchant-list">
                    {(view === 'approvals' ? approvalQueue : filteredMerchants).map((merchant) => {
                      const freezeLoading = activeActionKey === `freeze:${merchant.phone}`;
                      const bazaarLoading = activeActionKey === `bazaar:${merchant.phone}`;
                      const syncLoading = activeActionKey === `sync:${merchant.phone}`;
                      const approvalLoading =
                        activeActionKey === `merchant-approval:${merchant.phone}`;
                      const rejectLoading =
                        activeActionKey === `reject-account:${merchant.phone}`;
                      const isRejected = merchant.approvalStatus === 'rejected';
                      const isPending = !merchant.isApproved && !isRejected;
                      const selected = selectedMerchantPhone === merchant.phone;
                      return (
                        <article
                          key={merchant.phone}
                          className={selected ? 'merchant-card selected' : 'merchant-card'}
                          onClick={() => setSelectedMerchantPhone(merchant.phone)}
                        >
                          <div className="merchant-main">
                            <div>
                              <div className="merchant-title-row">
                                <h4>
                                  {merchant.storeName ||
                                    (merchant.isProfessional ||
                                    merchant.primaryServiceId === 'professionals'
                                      ? 'مهني بدون اسم'
                                      : 'متجر بدون اسم')}
                                </h4>
                                {merchant.isProfessional ||
                                merchant.primaryServiceId === 'professionals' ? (
                                  <span className="status-badge muted">مهني</span>
                                ) : null}
                                {merchant.isApproved ? (
                                  <span className="status-badge success">مفعّل</span>
                                ) : isRejected ? (
                                  <span className="status-badge danger">مرفوض</span>
                                ) : (
                                  <span className="status-badge warning">
                                    بانتظار الموافقة
                                  </span>
                                )}
                                {merchant.isFrozen ? (
                                  <span className="status-badge danger">مجمّد</span>
                                ) : !merchant.isOpen ? (
                                  <span className="status-badge danger">المتجر مغلق</span>
                                ) : merchant.isBazaarMember ? (
                                  <span className="status-badge success">مفعل في البازار</span>
                                ) : (
                                  <span className="status-badge muted">بانتظار/خارج البازار</span>
                                )}
                                {merchant.isBazaarMember ? (
                                  merchant.visibleToCustomers ? (
                                    <span className="status-badge success">
                                      ظاهر للزبائن ({merchant.visibleProductCount})
                                    </span>
                                  ) : (
                                    <span className="status-badge danger">
                                      غير ظاهر للزبائن
                                    </span>
                                  )
                                ) : null}
                              </div>
                              <p className="merchant-meta">
                                {merchant.fullName || 'بدون اسم مالك'} ·{' '}
                                {serviceLabel(merchant.primaryServiceId)} ·{' '}
                                <span dir="ltr">{merchant.phone}</span>
                              </p>
                              <p className="merchant-description">
                                {merchant.description || 'لا يوجد وصف محفوظ.'}
                              </p>
                              {isRejected && merchant.rejectionMessageAr ? (
                                <p className="courier-rejection-note">
                                  سبب الرفض: {merchant.rejectionMessageAr}
                                </p>
                              ) : null}
                              {merchant.isBazaarMember &&
                              !merchant.visibleToCustomers &&
                              merchant.visibilityNotes?.length ? (
                                <p className="merchant-visibility-note">
                                  سبب عدم الظهور:{' '}
                                  {merchant.visibilityNotes.join(' · ')}
                                </p>
                              ) : null}
                            </div>

                            <div className="merchant-stats-inline">
                              <MiniStat
                                label="المنتجات"
                                value={merchant.totalProducts ?? 0}
                                hint={
                                  merchant.availableProducts !== merchant.totalProducts
                                    ? `${merchant.availableProducts ?? 0} متاح`
                                    : undefined
                                }
                              />
                              <MiniStat label="الطلبات" value={merchant.totalOrders} />
                              <MiniStat
                                label="المكتمل"
                                value={merchant.completedOrders}
                              />
                              <MiniStat
                                label="الأرباح"
                                value={`${formatMoney(merchant.totalRevenue)} د.ع`}
                              />
                            </div>
                          </div>

                          <div className="merchant-actions">
                            <button
                              className={
                                merchant.isApproved
                                  ? 'soft-button danger'
                                  : 'soft-button success'
                              }
                              disabled={approvalLoading || rejectLoading}
                              onClick={(event) => {
                                event.stopPropagation();
                                handleMerchantApproval(merchant).catch(() => undefined);
                              }}
                            >
                              {approvalLoading ? (
                                <LoaderCircle className="spin" size={16} />
                              ) : (
                                <BadgeCheck size={16} />
                              )}
                              <span>
                                {merchant.isApproved
                                  ? 'إلغاء تفعيل الحساب'
                                  : 'موافقة وتفعيل'}
                              </span>
                            </button>

                            {isPending || isRejected ? (
                              <button
                                className="soft-button danger"
                                disabled={approvalLoading || rejectLoading}
                                onClick={(event) => {
                                  event.stopPropagation();
                                  openRejectConfirm({
                                    phone: merchant.phone,
                                    displayName:
                                      merchant.storeName || merchant.fullName || merchant.phone,
                                    kind: 'merchant',
                                  });
                                }}
                              >
                                {rejectLoading ? (
                                  <LoaderCircle className="spin" size={16} />
                                ) : (
                                  <XCircle size={16} />
                                )}
                                <span>رفض الطلب</span>
                              </button>
                            ) : null}

                            <button
                              className={merchant.isFrozen ? 'soft-button' : 'soft-button danger'}
                              disabled={freezeLoading}
                              onClick={(event) => {
                                event.stopPropagation();
                                handleMerchantAction(merchant, 'freeze').catch(() => undefined);
                              }}
                            >
                              {freezeLoading ? (
                                <LoaderCircle className="spin" size={16} />
                              ) : (
                                <AlertTriangle size={16} />
                              )}
                              <span>{merchant.isFrozen ? 'فك التجميد' : 'تجميد التاجر'}</span>
                            </button>

                            {canRequestBazaarApproval(merchant) ? (
                              <button
                                className={
                                  merchant.isBazaarMember
                                    ? 'soft-button'
                                    : 'soft-button success'
                                }
                                disabled={bazaarLoading}
                                onClick={(event) => {
                                  event.stopPropagation();
                                  handleMerchantAction(merchant, 'bazaar').catch(
                                    () => undefined,
                                  );
                                }}
                              >
                                {bazaarLoading ? (
                                  <LoaderCircle className="spin" size={16} />
                                ) : (
                                  <BadgeCheck size={16} />
                                )}
                                <span>
                                  {merchant.isBazaarMember
                                    ? 'سحب الموافقة'
                                    : 'موافقة على البازار'}
                                </span>
                              </button>
                            ) : (
                              <span className="status-badge muted">
                                لا ينطبق على هذا القسم
                              </span>
                            )}

                            {merchant.isBazaarMember &&
                            !merchant.visibleToCustomers ? (
                              <button
                                className="soft-button success"
                                disabled={syncLoading}
                                onClick={(event) => {
                                  event.stopPropagation();
                                  handleBazaarSync(merchant).catch(() => undefined);
                                }}
                              >
                                {syncLoading ? (
                                  <LoaderCircle className="spin" size={16} />
                                ) : (
                                  <Package2 size={16} />
                                )}
                                <span>إصلاح الظهور في البازار</span>
                              </button>
                            ) : null}

                            <button
                              className="soft-button danger"
                              disabled={approvalLoading || rejectLoading || freezeLoading}
                              onClick={(event) => {
                                event.stopPropagation();
                                openDeleteConfirm(
                                  accounts.find((item) => item.phone === merchant.phone) ?? {
                                    phone: merchant.phone,
                                    displayName:
                                      merchant.storeName || merchant.fullName || merchant.phone,
                                    fullName: merchant.fullName,
                                    role: merchant.role,
                                    accountType: '',
                                    kind: 'merchant',
                                    isSuspended: merchant.isFrozen,
                                    merchantStoreName: merchant.storeName,
                                    primaryServiceId: merchant.primaryServiceId,
                                    courierApproved: false,
                                    updatedAt: null,
                                    createdAt: merchant.createdAt,
                                    hasMerchantProfile: true,
                                    hasCourierProfile: false,
                                    hasDriverProfile: false,
                                  },
                                );
                              }}
                            >
                              <Trash2 size={16} />
                              <span>حذف الحساب</span>
                            </button>
                          </div>
                        </article>
                      );
                    })}

                    {(view === 'approvals' ? approvalQueue : filteredMerchants).length === 0 ? (
                      <div className="empty-state">
                        <Package2 size={22} />
                        <p>
                          {view === 'approvals'
                            ? 'لا توجد طلبات موافقة معلقة حالياً.'
                            : 'لا يوجد تجار مطابقون للبحث الحالي.'}
                        </p>
                      </div>
                    ) : null}
                  </div>
                  </>
                  )}
                </div>

                {view === 'couriers' || view === 'accounts' ? null : (
                <div className="panel details">
                  <div className="panel-header">
                    <div>
                      <h3>تفاصيل التاجر</h3>
                      <p>الأرباح، الطلبات الأخيرة، والمنتجات الحالية.</p>
                    </div>
                    {merchantDetails?.merchant.isFrozen ? (
                      <span className="panel-chip danger">الحساب مجمّد</span>
                    ) : null}
                  </div>

                  {isLoadingDetails ? (
                    <div className="loading-state compact">
                      <LoaderCircle className="spin" size={22} />
                      <span>جار تحميل تفاصيل التاجر...</span>
                    </div>
                  ) : merchantDetails ? (
                    <>
                      <div className="detail-hero">
                        <div>
                          <p className="eyebrow">ملخص التاجر</p>
                          <h3>{merchantDetails.merchant.storeName || 'متجر بدون اسم'}</h3>
                          <p className="merchant-meta">
                            {merchantDetails.merchant.fullName || 'بدون اسم مالك'} ·{' '}
                            {serviceLabel(merchantDetails.merchant.primaryServiceId)}
                          </p>
                        </div>
                        <div className="hero-badges">
                          <span className="status-badge success">
                            {merchantDetails.merchant.isBazaarMember
                              ? 'مصرح له في البازار'
                              : 'غير مصرح له في البازار'}
                          </span>
                          <span className="status-badge muted" dir="ltr">
                            {merchantDetails.merchant.phone}
                          </span>
                        </div>
                      </div>

                      <div className="detail-stats-grid">
                        <DetailStat
                          label="إجمالي الأرباح"
                          value={`${formatMoney(merchantDetails.stats.totalRevenue)} د.ع`}
                        />
                        <DetailStat
                          label="الطلبات الكلية"
                          value={merchantDetails.stats.totalOrders}
                        />
                        <DetailStat
                          label="متوسط الطلب"
                          value={`${formatMoney(
                            merchantDetails.stats.averageOrderValue,
                          )} د.ع`}
                        />
                        <DetailStat
                          label="عدد المنتجات"
                          value={merchantDetails.stats.totalProducts}
                        />
                      </div>

                      <div className="detail-meta-list">
                        <MetaRow
                          label="العنوان"
                          value={merchantDetails.merchant.address || 'غير محفوظ'}
                        />
                        <MetaRow
                          label="رسوم التوصيل"
                          value={`${formatMoney(merchantDetails.merchant.deliveryFee)} د.ع`}
                        />
                        <MetaRow
                          label="تاريخ الانضمام"
                          value={formatDate(merchantDetails.merchant.createdAt)}
                        />
                        <MetaRow
                          label="آخر تحديث"
                          value={formatDate(merchantDetails.merchant.updatedAt)}
                        />
                      </div>

                      <div className="subpanel">
                        <h4>الطلبات الأخيرة</h4>
                        <div className="order-list">
                          {merchantDetails.recentOrders.map((order) => (
                            <article key={order.id} className="order-row">
                              <div>
                                <strong>{order.orderNumber}</strong>
                                <p>
                                  {order.customerName || 'عميل غير معروف'} ·{' '}
                                  {order.statusAr || order.statusKey}
                                </p>
                              </div>
                              <div className="order-row-meta">
                                <span>{formatMoney(order.price)} د.ع</span>
                                <small>{formatDate(order.updatedAt)}</small>
                              </div>
                            </article>
                          ))}
                        </div>
                      </div>

                      <div className="subpanel">
                        <h4>منتجات مختصرة</h4>
                        <div className="product-list">
                          {merchantDetails.products.map((product) => (
                            <article key={product.id} className="product-row">
                              <div>
                                <strong>{product.name || 'منتج بدون اسم'}</strong>
                                <p>
                                  {serviceLabel(product.category)} ·{' '}
                                  {product.subCategory || 'بدون تصنيف'}
                                </p>
                              </div>
                              <div className="order-row-meta">
                                <span>{formatMoney(product.price)} د.ع</span>
                                <small>
                                  {product.isAvailable ? 'متاح' : 'غير متاح'}
                                </small>
                              </div>
                            </article>
                          ))}
                        </div>
                      </div>
                    </>
                  ) : (
                    <div className="empty-state">
                      <Building2 size={22} />
                      <p>اختر تاجراً من القائمة لعرض أرباحه وطلباته وتفاصيله.</p>
                    </div>
                  )}
                </div>
                )}
              </section>
              )}

              {view === 'dashboard' ? (
              <section className="panel recent-orders-panel">
                <div className="panel-header">
                  <div>
                    <h3>آخر طلبات المنصة</h3>
                    <p>لمتابعة حركة الطلبات العامة داخل التطبيق.</p>
                  </div>
                </div>

                <div className="table-wrap">
                  <table>
                    <thead>
                      <tr>
                        <th>رقم الطلب</th>
                        <th>المتجر</th>
                        <th>العميل</th>
                        <th>الحالة</th>
                        <th>القيمة</th>
                        <th>آخر تحديث</th>
                      </tr>
                    </thead>
                    <tbody>
                      {(reports?.recentOrders || []).map((order) => (
                        <tr key={order.id}>
                          <td>{order.orderNumber || order.id}</td>
                          <td>{order.merchantStoreName || 'غير معروف'}</td>
                          <td>{order.customerNameAr || 'غير معروف'}</td>
                          <td>{order.statusAr || order.statusKey}</td>
                          <td>{formatMoney(order.price)} د.ع</td>
                          <td>{formatDate(order.updatedAt)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </section>
              ) : null}
            </>
          )}
        </section>
      </section>

      {deleteTarget ? (
        <div
          className="modal-backdrop"
          role="presentation"
          onClick={() => setDeleteTarget(null)}
        >
          <div
            className="modal-card danger-modal"
            role="dialog"
            aria-modal="true"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="panel-header">
              <div>
                <h3>تأكيد حذف الحساب</h3>
                <p>
                  هل أنت متأكد من حذف حساب{' '}
                  <strong>{deleteTarget.displayName || deleteTarget.phone}</strong>؟
                  <br />
                  النوع: {accountKindLabel(deleteTarget.kind)} ·{' '}
                  <span dir="ltr">{deleteTarget.phone}</span>
                </p>
              </div>
            </div>

            <div className="delete-warning-box">
              <AlertTriangle size={20} />
              <p>
                هذا الإجراء نهائي. سيتم حذف بيانات الحساب وملفه من النظام ولا يمكن
                التراجع عنه بسهولة.
              </p>
            </div>

            <div className="modal-actions">
              <button
                className="ghost-button"
                type="button"
                onClick={() => setDeleteTarget(null)}
              >
                إلغاء
              </button>
              <button
                className="soft-button danger"
                type="button"
                disabled={activeActionKey === `delete-account:${deleteTarget.phone}`}
                onClick={() => {
                  handleDeleteAccount().catch(() => undefined);
                }}
              >
                {activeActionKey === `delete-account:${deleteTarget.phone}` ? (
                  <LoaderCircle className="spin" size={16} />
                ) : (
                  <Trash2 size={16} />
                )}
                <span>نعم، احذف الحساب نهائياً</span>
              </button>
            </div>
          </div>
        </div>
      ) : null}

      {rejectAccountTarget ? (
        <div
          className="modal-backdrop"
          role="presentation"
          onClick={() => {
            setRejectAccountTarget(null);
            setRejectMessage('');
          }}
        >
          <div
            className="modal-card"
            role="dialog"
            aria-modal="true"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="panel-header">
              <div>
                <h3>رفض الطلب مع سبب واضح</h3>
                <p>
                  اكتب سبب الرفض لحساب{' '}
                  <strong>
                    {rejectAccountTarget.displayName || rejectAccountTarget.phone}
                  </strong>{' '}
                  ({accountKindLabel(rejectAccountTarget.kind)}). سيظهر السبب للمستخدم في
                  التطبيق ليتمكن من تصحيح بياناته.
                </p>
              </div>
            </div>

            <label className="reject-message-field">
              <span>سبب الرفض</span>
              <textarea
                rows={5}
                value={rejectMessage}
                placeholder="مثال: صورة الدراجة غير واضحة، يرجى رفع صورة أوضح مع إظهار اللوحة."
                onChange={(event) => setRejectMessage(event.target.value)}
              />
            </label>

            <div className="reject-quick-fill">
              {(rejectAccountTarget.kind === 'merchant'
                ? MERCHANT_REJECTION_REASONS
                : rejectAccountTarget.kind === 'courier'
                  ? COURIER_REJECTION_REASONS
                  : []
              ).map((reason) => (
                <button
                  key={reason.key}
                  type="button"
                  className="account-filter-chip"
                  onClick={() => setRejectMessage(reason.label)}
                >
                  {reason.label}
                </button>
              ))}
            </div>

            <div className="modal-actions">
              <button
                className="ghost-button"
                type="button"
                onClick={() => {
                  setRejectAccountTarget(null);
                  setRejectMessage('');
                }}
              >
                إلغاء
              </button>
              <button
                className="soft-button danger"
                type="button"
                disabled={
                  !rejectMessage.trim() ||
                  activeActionKey === `reject-account:${rejectAccountTarget.phone}`
                }
                onClick={() => {
                  handleRejectAccount().catch(() => undefined);
                }}
              >
                {activeActionKey === `reject-account:${rejectAccountTarget.phone}` ? (
                  <LoaderCircle className="spin" size={16} />
                ) : (
                  <XCircle size={16} />
                )}
                <span>تأكيد الرفض وإرسال السبب</span>
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </main>
  );
}

function MetricCard({
  icon,
  title,
  value,
  hint,
}: {
  icon: ReactNode;
  title: string;
  value: string;
  hint: string;
}) {
  return (
    <article className="metric-card">
      <div className="metric-icon">{icon}</div>
      <div>
        <p>{title}</p>
        <strong>{value}</strong>
        <span>{hint}</span>
      </div>
    </article>
  );
}

function MiniStat({
  label,
  value,
  hint,
}: {
  label: string;
  value: string | number;
  hint?: string;
}) {
  return (
    <div className="mini-stat">
      <span>{label}</span>
      <strong>{value}</strong>
      {hint ? <em>{hint}</em> : null}
    </div>
  );
}

function DetailStat({
  label,
  value,
}: {
  label: string;
  value: string | number;
}) {
  return (
    <div className="detail-stat">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function MetaRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="meta-row">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

export default App;
