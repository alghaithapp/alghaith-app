import { FormEvent, ReactNode, useEffect, useMemo, useState } from 'react';
import {
  AlertTriangle,
  BadgeCheck,
  BarChart3,
  Building2,
  LoaderCircle,
  Lock,
  LogOut,
  Package2,
  Search,
  Shield,
  ShoppingBag,
  Store,
  Users,
} from 'lucide-react';

import {
  loadAdminReports,
  loadMerchantDetails,
  loadMerchants,
  sendCode,
  toggleMerchantBazaar,
  toggleMerchantFreeze,
  verifyCode,
} from './admin-api';
import type {
  AdminReports,
  MerchantDetails,
  MerchantSummary,
} from './admin-types';

const SESSION_STORAGE_KEY = 'alghaith-admin-session-v1';

type AdminView = 'dashboard' | 'merchants' | 'approvals';

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
  const [selectedMerchantPhone, setSelectedMerchantPhone] = useState('');
  const [merchantDetails, setMerchantDetails] = useState<MerchantDetails | null>(
    null,
  );
  const [isLoadingData, setIsLoadingData] = useState(false);
  const [isLoadingDetails, setIsLoadingDetails] = useState(false);
  const [activeActionKey, setActiveActionKey] = useState('');

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
      const [nextReports, nextMerchants] = await Promise.all([
        loadAdminReports(authToken),
        loadMerchants(authToken),
      ]);
      setReports(nextReports);
      setMerchants(nextMerchants);

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
    if (!query) return merchants;
    return merchants.filter((merchant) => {
      const haystack = [
        merchant.storeName,
        merchant.fullName,
        merchant.phone,
        merchant.primaryServiceId,
      ]
        .join(' ')
        .toLowerCase();
      return haystack.includes(query);
    });
  }, [merchants, search]);

  const approvalQueue = useMemo(
    () =>
      merchants.filter(
        (merchant) =>
          canRequestBazaarApproval(merchant) && merchant.isBazaarMember !== true,
      ),
    [merchants],
  );

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

  function handleLogout() {
    window.localStorage.removeItem(SESSION_STORAGE_KEY);
    setToken(null);
    setPhoneNumber('');
    setInputPhone('');
    setOtpCode('');
    setOtpSent(false);
    setReports(null);
    setMerchants([]);
    setMerchantDetails(null);
    setSelectedMerchantPhone('');
    setSuccessMessage('');
    setActionError('');
    setBootError('');
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

  if (!token) {
    return (
      <main className="admin-shell">
        <section className="auth-card">
          <div className="brand-badge">
            <Shield size={30} />
          </div>
          <div className="auth-copy">
            <p className="eyebrow">AL GHAITH ADMIN</p>
            <h1>لوحة إدارة بازار ومطاعم الغيث</h1>
            <p>
              دخول آمن برقم الهاتف لعرض الإحصائيات الكاملة، تجميد التجار، والموافقة
              على النشر داخل قسم بازار ومطاعم الغيث.
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
      <section className="dashboard-layout">
        <aside className="sidebar">
          <div className="sidebar-header">
            <div className="brand-badge small">
              <Shield size={22} />
            </div>
            <div>
              <p className="eyebrow">SUPER ADMIN</p>
              <h2>بازار الغيث</h2>
            </div>
          </div>

          <div className="admin-identity">
            <span>أنت داخل كـ</span>
            <strong dir="ltr">{phoneNumber}</strong>
          </div>

          <nav className="sidebar-nav">
            <button
              className={view === 'dashboard' ? 'nav-item active' : 'nav-item'}
              onClick={() => setView('dashboard')}
            >
              <BarChart3 size={18} />
              <span>الملخص العام</span>
            </button>
            <button
              className={view === 'merchants' ? 'nav-item active' : 'nav-item'}
              onClick={() => setView('merchants')}
            >
              <Store size={18} />
              <span>إدارة التجار</span>
            </button>
            <button
              className={view === 'approvals' ? 'nav-item active' : 'nav-item'}
              onClick={() => setView('approvals')}
            >
              <BadgeCheck size={18} />
              <span>موافقات البازار</span>
            </button>
          </nav>

          <button className="ghost-button logout" onClick={handleLogout}>
            <LogOut size={18} />
            <span>تسجيل الخروج</span>
          </button>
        </aside>

        <section className="content">
          <header className="topbar">
            <div>
              <p className="eyebrow">لوحة إدارة احترافية</p>
              <h1>إحصائيات، موافقات، وإدارة تجار من مكان واحد</h1>
            </div>

            <div className="topbar-search">
              <Search size={18} />
              <input
                placeholder="ابحث عن تاجر أو رقم هاتف"
                value={search}
                onChange={(event) => setSearch(event.target.value)}
              />
            </div>
          </header>

          {bootError ? <div className="message error">{bootError}</div> : null}
          {actionError ? <div className="message error">{actionError}</div> : null}
          {successMessage ? <div className="message success">{successMessage}</div> : null}

          {isLoadingData ? (
            <div className="loading-state">
              <LoaderCircle className="spin" size={28} />
              <span>جار تحميل بيانات لوحة الإدارة...</span>
            </div>
          ) : (
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

              <section className="main-grid">
                <div className="panel wide">
                  <div className="panel-header">
                    <div>
                      <h3>
                        {view === 'approvals'
                          ? 'طلبات الموافقة داخل بازار ومطاعم الغيث'
                          : 'قائمة التجار'}
                      </h3>
                      <p>
                        {view === 'approvals'
                          ? 'الموافقة هنا تفتح للتاجر قسم بازار ومطاعم الغيث لأول مرة فقط.'
                          : 'استعراض الحالة، الأرباح، وعدد الطلبات لكل تاجر.'}
                      </p>
                    </div>
                    <span className="panel-chip">
                      {view === 'approvals' ? approvalQueue.length : filteredMerchants.length}
                    </span>
                  </div>

                  <div className="merchant-list">
                    {(view === 'approvals' ? approvalQueue : filteredMerchants).map((merchant) => {
                      const freezeLoading = activeActionKey === `freeze:${merchant.phone}`;
                      const bazaarLoading = activeActionKey === `bazaar:${merchant.phone}`;
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
                                <h4>{merchant.storeName || 'متجر بدون اسم'}</h4>
                                {merchant.isFrozen ? (
                                  <span className="status-badge danger">مجمّد</span>
                                ) : merchant.isBazaarMember ? (
                                  <span className="status-badge success">مفعل في البازار</span>
                                ) : (
                                  <span className="status-badge muted">بانتظار/خارج البازار</span>
                                )}
                              </div>
                              <p className="merchant-meta">
                                {merchant.fullName || 'بدون اسم مالك'} ·{' '}
                                {serviceLabel(merchant.primaryServiceId)} ·{' '}
                                <span dir="ltr">{merchant.phone}</span>
                              </p>
                              <p className="merchant-description">
                                {merchant.description || 'لا يوجد وصف محفوظ.'}
                              </p>
                            </div>

                            <div className="merchant-stats-inline">
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
                </div>

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
                          <p className="eyebrow">MERCHANT SNAPSHOT</p>
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
              </section>

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
            </>
          )}
        </section>
      </section>
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

function MiniStat({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="mini-stat">
      <span>{label}</span>
      <strong>{value}</strong>
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
