import type {
  AdminAccountSummary,
  AdminNotifications,
  AdminPermissions,
  AdminReports,
  AdminSession,
  AdminSummary,
  AdminTaxiTrip,
  AppUpdatePolicy,
  MaintenancePolicy,
  CourierSummary,
  DriverSummary,
  DriverPreRegisterPayload,
  DriverPreRegisterResponse,
  HomeCategoriesConfig,
  HomeCategoryPlatformOverride,
  MerchantDetails,
  MerchantPreRegisterPayload,
  MerchantPreRegisterResponse,
  MerchantSummary,
  PendingProductSummary,
  ProfessionalPreRegisterPayload,
  ProfessionalPreRegisterResponse,
  ProfessionalSummary,
  ProfessionalDetails,
  CourierPreRegisterPayload,
  CourierPreRegisterResponse,
  DoctorPharmacyPreRegisterPayload,
  DoctorPharmacyPreRegisterResponse,
  CustomerPreRegisterPayload,
  CustomerPreRegisterResponse,
  ToggleBazaarResponse,
} from './admin-types';

const DEFAULT_DATABASE_API_BASE = 'https://alghaith-app-production.up.railway.app';
const DEFAULT_PHONE_AUTH_BASE = 'https://lively-wind-9d98.alghaithapp.workers.dev';

function normalizeBaseUrl(input: string | undefined, fallback: string) {
  const raw = String(input || '').trim();
  if (!raw) return fallback;
  return raw.replace(/\/+$/, '');
}

function resolveApiBaseUrl(envValue: string | undefined, fallback: string) {
  if (!import.meta.env.DEV) {
    return fallback;
  }
  return normalizeBaseUrl(envValue, fallback);
}

export const DATABASE_API_BASE_URL = resolveApiBaseUrl(
  import.meta.env.VITE_BACKEND_URL,
  DEFAULT_DATABASE_API_BASE,
);
export const PHONE_AUTH_BASE_URL = resolveApiBaseUrl(
  import.meta.env.VITE_PHONE_AUTH_URL,
  DEFAULT_PHONE_AUTH_BASE,
);

let tauriInvoke: ((cmd: string, args?: Record<string, unknown>) => Promise<unknown>) | null = null;
let tauriProbeDone = false;

async function getTauriInvoke() {
  if (tauriProbeDone) return tauriInvoke;
  tauriProbeDone = true;
  try {
    const isTauriRuntime =
      typeof window !== 'undefined' &&
      Boolean((window as Window & { isTauri?: boolean }).isTauri);
    if (!isTauriRuntime) {
      tauriInvoke = null;
      return null;
    }
    const mod = await import('@tauri-apps/api/core');
    if (typeof mod?.invoke === 'function') {
      tauriInvoke = mod.invoke;
    }
  } catch {
    tauriInvoke = null;
  }
  return tauriInvoke;
}

async function request<T>(
  baseUrl: string,
  path: string,
  options: RequestInit & { token?: string } = {},
): Promise<T> {
  const url = `${baseUrl}${path}`;
  const headers: Record<string, string> = {
    Accept: 'application/json, text/plain, */*',
    'Content-Type': 'application/json',
  };
  if (options.token) {
    headers['Authorization'] = `Bearer ${options.token}`;
  }

  const invoke = await getTauriInvoke();

  if (invoke) {
    // Use Rust backend via Tauri IPC — no CORS issues
    const raw = await invoke('api_request', {
      url,
      method: options.method || 'GET',
      headers,
      body: options.body as string | null,
    }) as string;

    const newlineIdx = raw.indexOf('\n');
    const statusCode = parseInt(raw.substring(0, newlineIdx), 10);
    const body = raw.substring(newlineIdx + 1);

    if (!body) {
      if (statusCode >= 400) throw new Error(`Request failed (${statusCode})`);
      return null as T;
    }

    if (/^\s*</.test(body)) {
      throw new Error('الخادم أعاد صفحة HTML بدل JSON.');
    }

    let payload: unknown;
    try {
      payload = JSON.parse(body);
    } catch {
      throw new Error('استجابة غير متوقعة من الخادم.');
    }

    if (statusCode >= 400) {
      const msg = payload && typeof payload === 'object' && 'message' in (payload as Record<string, unknown>)
        ? (payload as { message: string }).message
        : `Request failed (${statusCode})`;
      throw new Error(msg);
    }

    return payload as T;
  }

  // Browser fallback — use native fetch
  const response = await fetch(url, {
    method: options.method || 'GET',
    headers,
    body: options.body as string | undefined,
  });

  const text = await response.text();

  if (!text) {
    if (!response.ok) throw new Error(`Request failed (${response.status})`);
    return null as T;
  }

  if (/^\s*</.test(text)) {
    throw new Error('الخادم أعاد صفحة HTML بدل JSON.');
  }

  let payload: unknown;
  try {
    payload = JSON.parse(text);
  } catch {
    throw new Error('استجابة غير متوقعة من الخادم.');
  }

  if (!response.ok) {
    const msg = payload && typeof payload === 'object' && 'message' in (payload as Record<string, unknown>)
      ? (payload as { message: string }).message
      : `Request failed (${response.status})`;
    throw new Error(msg);
  }

  return payload as T;
}

export async function sendCode(phone: string, channel = 'sms') {
  await request(PHONE_AUTH_BASE_URL, '/auth/send-code', {
    method: 'POST',
    body: JSON.stringify({ phone, channel }),
  });
}

export async function verifyCode(phone: string, code: string): Promise<AdminSession> {
  return request<AdminSession>(PHONE_AUTH_BASE_URL, '/auth/verify-code', {
    method: 'POST',
    body: JSON.stringify({ phone, code }),
  });
}

export async function loadAdminReports(token: string): Promise<AdminReports> {
  return request<AdminReports>(DATABASE_API_BASE_URL, '/db/admin/reports', { token });
}

export async function loadMerchants(token: string): Promise<MerchantSummary[]> {
  return request<MerchantSummary[]>(DATABASE_API_BASE_URL, '/db/admin/merchants', { token });
}

export async function loadProfessionals(token: string): Promise<ProfessionalSummary[]> {
  return request<ProfessionalSummary[]>(DATABASE_API_BASE_URL, '/db/admin/professionals', { token });
}

export async function loadProfessionalDetails(token: string, professionalPhone: string): Promise<ProfessionalDetails> {
  return request<ProfessionalDetails>(
    DATABASE_API_BASE_URL,
    `/db/admin/professional-details?${new URLSearchParams({ professionalPhone })}`,
    { token },
  );
}

export async function loadCouriers(token: string): Promise<CourierSummary[]> {
  return request<CourierSummary[]>(DATABASE_API_BASE_URL, '/db/admin/couriers', { token });
}

export async function loadDrivers(token: string): Promise<DriverSummary[]> {
  return request<DriverSummary[]>(DATABASE_API_BASE_URL, '/db/admin/drivers', { token });
}

export async function loadAdminAccounts(token: string): Promise<AdminAccountSummary[]> {
  return request<AdminAccountSummary[]>(DATABASE_API_BASE_URL, '/db/admin/accounts', { token });
}

export async function suspendAdminAccount(token: string, accountPhone: string, isSuspended: boolean) {
  return request(DATABASE_API_BASE_URL, '/db/admin/account-suspend', {
    method: 'PUT', token, body: JSON.stringify({ accountPhone, isSuspended }),
  });
}

export async function updateAdminAccountRole(token: string, accountPhone: string, role: string) {
  return request(DATABASE_API_BASE_URL, '/db/admin/account-role', {
    method: 'PUT', token, body: JSON.stringify({ accountPhone, role }),
  });
}

export async function deleteAdminAccount(token: string, accountPhone: string) {
  return request(DATABASE_API_BASE_URL, '/db/admin/account', {
    method: 'DELETE', token, body: JSON.stringify({ accountPhone }),
  });
}

export async function deleteDriverAccount(token: string, driverPhone: string) {
  const params = new URLSearchParams({ driverPhone });
  return request(DATABASE_API_BASE_URL, `/db/admin/driver?${params}`, {
    method: 'DELETE',
    token,
  });
}

export async function toggleCourierApproval(token: string, courierPhone: string, isApproved: boolean) {
  return request(DATABASE_API_BASE_URL, '/db/admin/courier-approval', {
    method: 'PUT', token, body: JSON.stringify({ courierPhone, isApproved }),
  });
}

export async function rejectCourierApplication(token: string, courierPhone: string, rejectionMessageAr: string, reasonKey = 'custom') {
  return request(DATABASE_API_BASE_URL, '/db/admin/courier-rejection', {
    method: 'PUT', token, body: JSON.stringify({ courierPhone, reasonKey, rejectionMessageAr }),
  });
}

export async function toggleDriverApproval(token: string, driverPhone: string, isApproved: boolean) {
  return request(DATABASE_API_BASE_URL, '/db/admin/driver-approval', {
    method: 'PUT', token, body: JSON.stringify({ driverPhone, isApproved }),
  });
}

export async function rejectDriverApplication(token: string, driverPhone: string, rejectionMessageAr: string, reasonKey = 'custom') {
  return request(DATABASE_API_BASE_URL, '/db/admin/driver-rejection', {
    method: 'PUT', token, body: JSON.stringify({ driverPhone, reasonKey, rejectionMessageAr }),
  });
}

export async function loadMerchantDetails(token: string, merchantPhone: string): Promise<MerchantDetails> {
  return request<MerchantDetails>(DATABASE_API_BASE_URL, `/db/admin/merchant-details?${new URLSearchParams({ merchantPhone })}`, { token });
}

export async function toggleMerchantApproval(token: string, merchantPhone: string, isApproved: boolean) {
  return request(DATABASE_API_BASE_URL, '/db/admin/merchant-approval', {
    token, method: 'PUT', body: JSON.stringify({ merchantPhone, isApproved }),
  });
}

// -- Admin Merchant Products Management --
export async function loadAdminMerchantProducts(token: string, merchantPhone: string) {
  const q = new URLSearchParams({ merchantPhone });
  return request(DATABASE_API_BASE_URL, `/db/admin/merchant-products?${q.toString()}`, { token });
}

export async function saveAdminMerchantProduct(token: string, merchantPhone: string, productData: any) {
  return request(DATABASE_API_BASE_URL, '/db/admin/merchant-product', {
    method: 'PUT', token, body: JSON.stringify({ merchantPhone, ...productData }),
  });
}

export async function deleteAdminMerchantProduct(token: string, merchantPhone: string, id: string) {
  const q = new URLSearchParams({ merchantPhone, id });
  return request(DATABASE_API_BASE_URL, `/db/admin/merchant-product?${q.toString()}`, {
    method: 'DELETE', token,
  });
}

export async function loadPendingProducts(token: string, category?: string): Promise<PendingProductSummary[]> {
  const q = new URLSearchParams();
  if (category) q.set('category', category);
  const suffix = q.toString() ? `?${q.toString()}` : '';
  return request<PendingProductSummary[]>(DATABASE_API_BASE_URL, `/db/admin/pending-products${suffix}`, { token });
}

export async function toggleProductApproval(
  token: string,
  merchantPhone: string,
  productId: string,
  isApproved: boolean,
  rejectionMessageAr?: string,
) {
  return request(DATABASE_API_BASE_URL, '/db/admin/product-approval', {
    method: 'PUT',
    token,
    body: JSON.stringify({ merchantPhone, productId, isApproved, rejectionMessageAr }),
  });
}

// -- Admin Media Management --
export async function loadAdminMediaAssets(token: string, ownerType: string, ownerId: string) {
  const q = new URLSearchParams({ ownerType, ownerId });
  // In the legacy code, fetchWithToken might not exist, but request is used here
  // Wait, the API url is /media/assets, NOT /db/admin/...
  // Let's use fetch directly with the DATABASE_API_BASE_URL
  const res = await fetch(`${DATABASE_API_BASE_URL || ''}/media/assets?${q.toString()}`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  if (!res.ok) throw new Error('Failed to load media assets');
  return res.json();
}

export async function rejectMerchantApplication(token: string, merchantPhone: string, rejectionMessageAr: string, reasonKey = 'custom') {
  return request(DATABASE_API_BASE_URL, '/db/admin/merchant-rejection', {
    token, method: 'PUT', body: JSON.stringify({ merchantPhone, reasonKey, rejectionMessageAr }),
  });
}

export async function toggleMerchantFreeze(token: string, merchantPhone: string, isFrozen: boolean) {
  return request(DATABASE_API_BASE_URL, '/db/admin/merchant-freeze', {
    method: 'PUT', token, body: JSON.stringify({ merchantPhone, isFrozen }),
  });
}

export async function syncMerchantBazaarProducts(token: string, merchantPhone: string) {
  return request<{ success: boolean; synced: number; totalEligible: number }>(
    DATABASE_API_BASE_URL, '/db/admin/merchant-bazaar-sync', {
      method: 'POST', token, body: JSON.stringify({ merchantPhone }),
    },
  );
}

export async function toggleMerchantBazaar(token: string, merchantPhone: string, isBazaarMember: boolean) {
  return request<ToggleBazaarResponse>(DATABASE_API_BASE_URL, '/db/admin/merchant-bazaar', {
    method: 'PUT', token, body: JSON.stringify({ merchantPhone, isBazaarMember }),
  });
}

export async function preRegisterMerchant(
  token: string,
  payload: MerchantPreRegisterPayload,
) {
  return request<MerchantPreRegisterResponse>(
    DATABASE_API_BASE_URL,
    '/db/admin/merchant-pre-register',
    {
      method: 'POST',
      token,
      body: JSON.stringify(payload),
    },
  );
}

export async function updateMerchantCategory(
  token: string,
  payload: import('./admin-types').MerchantCategoryUpdatePayload,
) {
  return request<import('./admin-types').MerchantCategoryUpdateResponse>(
    DATABASE_API_BASE_URL,
    '/db/admin/merchant-category',
    {
      method: 'PUT',
      token,
      body: JSON.stringify(payload),
    },
  );
}

export async function preRegisterDriver(
  token: string,
  payload: DriverPreRegisterPayload,
) {
  return request<DriverPreRegisterResponse>(
    DATABASE_API_BASE_URL,
    '/db/admin/driver-pre-register',
    {
      method: 'POST',
      token,
      body: JSON.stringify(payload),
    },
  );
}

export async function preRegisterCourier(
  token: string,
  payload: CourierPreRegisterPayload,
) {
  return request<CourierPreRegisterResponse>(
    DATABASE_API_BASE_URL,
    '/db/admin/courier-pre-register',
    {
      method: 'POST',
      token,
      body: JSON.stringify(payload),
    },
  );
}

export async function preRegisterCustomer(
  token: string,
  payload: import('./admin-types').CustomerPreRegisterPayload,
) {
  return request<import('./admin-types').CustomerPreRegisterResponse>(
    DATABASE_API_BASE_URL,
    '/db/admin/customer-pre-register',
    { method: 'POST', token, body: JSON.stringify(payload) },
  );
}

export async function preRegisterDoctor(
  token: string,
  payload: DoctorPharmacyPreRegisterPayload,
) {
  return request<DoctorPharmacyPreRegisterResponse>(
    DATABASE_API_BASE_URL,
    '/db/admin/doctor-pre-register',
    { method: 'POST', token, body: JSON.stringify({ ...payload, subscriberPhone: payload.subscriberPhone }) },
  );
}

export async function preRegisterPharmacy(
  token: string,
  payload: DoctorPharmacyPreRegisterPayload,
) {
  return request<DoctorPharmacyPreRegisterResponse>(
    DATABASE_API_BASE_URL,
    '/db/admin/pharmacy-pre-register',
    { method: 'POST', token, body: JSON.stringify({ ...payload, subscriberPhone: payload.subscriberPhone }) },
  );
}

export async function preRegisterDoctorPharmacy(
  token: string,
  payload: DoctorPharmacyPreRegisterPayload,
) {
  return request<DoctorPharmacyPreRegisterResponse>(
    DATABASE_API_BASE_URL,
    '/db/admin/beauty-pre-register',
    {
      method: 'POST',
      token,
      body: JSON.stringify(payload),
    },
  );
}

export async function preRegisterProfessional(
  token: string,
  payload: ProfessionalPreRegisterPayload,
) {
  return request<ProfessionalPreRegisterResponse>(
    DATABASE_API_BASE_URL,
    '/db/admin/professional-pre-register',
    {
      method: 'POST',
      token,
      body: JSON.stringify(payload),
    },
  );
}

export async function loadAppUpdatePolicy(token: string): Promise<AppUpdatePolicy> {
  return request<AppUpdatePolicy>(DATABASE_API_BASE_URL, '/db/admin/app-update-policy', { token });
}

export async function saveAppUpdatePolicy(token: string, policy: Record<string, unknown>) {
  return request<{ success: boolean; policy: AppUpdatePolicy }>(DATABASE_API_BASE_URL, '/db/admin/app-update-policy', {
    method: 'PUT', token, body: JSON.stringify(policy),
  });
}

export async function loadMaintenancePolicy(token: string): Promise<MaintenancePolicy> {
  return request<MaintenancePolicy>(DATABASE_API_BASE_URL, '/db/admin/maintenance', { token });
}

export async function saveMaintenancePolicy(token: string, policy: Record<string, unknown>) {
  return request<{ success: boolean; policy: MaintenancePolicy }>(DATABASE_API_BASE_URL, '/db/admin/maintenance', {
    method: 'PUT', token, body: JSON.stringify(policy),
  });
}

export async function loadHomeCategoriesConfig(token: string): Promise<HomeCategoriesConfig> {
  return request<HomeCategoriesConfig>(DATABASE_API_BASE_URL, '/app/home-categories', { token });
}

export async function saveHomeCategoriesConfig(token: string, overrides: Record<string, HomeCategoryPlatformOverride>): Promise<HomeCategoriesConfig> {
  return request<HomeCategoriesConfig>(DATABASE_API_BASE_URL, '/db/admin/home-categories', {
    method: 'PUT', token, body: JSON.stringify({ overrides }),
  });
}

export async function sendPushNotification(
  token: string,
  payload: { title: string; body: string; audience: string; platform?: string; storeUpdate?: boolean },
) {
  return request<{
    sent: number;
    failed: number;
    message: string;
    tokenCount?: number;
    inAppCount?: number;
    broadcastId?: string;
  }>(
    DATABASE_API_BASE_URL,
    '/db/admin/messages/broadcast',
    {
      method: 'POST',
      token,
      body: JSON.stringify(payload),
    },
  );
}

export interface AdminNotification {
  id: string;
  type: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
  is_read: boolean;
  created_at: string;
}

export async function loadAdminNotifications(token: string, unreadOnly = false): Promise<AdminNotification[]> {
  const qs = unreadOnly ? '?unreadOnly=true' : '';
  return request<AdminNotification[]>(DATABASE_API_BASE_URL, `/db/admin/notifications${qs}`, { token });
}

export async function markAdminNotificationsRead(token: string, ids?: string[]) {
  return request<{ success: boolean }>(DATABASE_API_BASE_URL, '/db/admin/notifications/read', {
    method: 'PUT',
    token,
    body: JSON.stringify(ids ? { ids } : {}),
  });
}

export async function loadAdminTaxiTrips(token: string, status?: string) {
  const query = status ? `?status=${encodeURIComponent(status)}` : '';
  return request<AdminTaxiTrip[]>(
    DATABASE_API_BASE_URL,
    `/db/admin/taxi/trips${query}`,
    { token },
  );
}

export async function loadAdminTaxiComplaints(token: string) {
  return request<AdminTaxiTrip[]>(
    DATABASE_API_BASE_URL,
    '/db/admin/taxi/complaints',
    { token },
  );
}

// ── Admin Management ────────────────────────────────────────────────────

export interface AdminListResponse {
  admins: AdminSummary[];
  myPermissions: AdminPermissions;
}

export async function loadAllAdmins(token: string): Promise<AdminListResponse> {
  return request<AdminListResponse>(DATABASE_API_BASE_URL, '/db/admin/admins', { token });
}

export async function inviteAdmin(token: string, targetPhone: string, permissions: AdminPermissions) {
  return request<{ success: boolean; phone: string; permissions: AdminPermissions }>(
    DATABASE_API_BASE_URL,
    '/db/admin/admin-invite',
    { method: 'POST', token, body: JSON.stringify({ targetPhone, permissions }) },
  );
}

export async function updateAdminPermissions(token: string, targetPhone: string, permissions: AdminPermissions) {
  return request<{ success: boolean; phone: string; permissions: AdminPermissions }>(
    DATABASE_API_BASE_URL,
    '/db/admin/admin-permissions',
    { method: 'PUT', token, body: JSON.stringify({ targetPhone, permissions }) },
  );
}

export async function removeAdmin(token: string, targetPhone: string) {
  return request<{ success: boolean; phone: string }>(
    DATABASE_API_BASE_URL,
    '/db/admin/admin-remove',
    { method: 'DELETE', token, body: JSON.stringify({ targetPhone }) },
  );
}

export async function loadMyAdminRole(token: string): Promise<{ role: string; permissions: AdminPermissions | null; accounts: unknown[] }> {
  return request(DATABASE_API_BASE_URL, '/db/admin/roles', { token });
}

// ── Dynamic App Config (Read) ──────────────────────────────────
async function loadAppConfig<T>(token: string, path: string): Promise<T> {
  return request<T>(DATABASE_API_BASE_URL, `/app/config/${path}`, { method: 'GET', token });
}

// ── Dynamic App Config (Write - Admin) ─────────────────────────
export async function saveAppConfig(token: string, key: string, value: unknown) {
  return request(DATABASE_API_BASE_URL, '/app/config/admin/configs', {
    method: 'PUT',
    token,
    body: JSON.stringify({ key, value }),
  });
}

export async function loadTaxiPricing(token: string) {
  return loadAppConfig<Record<string, unknown>>(token, 'taxi-pricing');
}
export async function saveTaxiPricing(token: string, value: Record<string, unknown>) {
  return saveAppConfig(token, 'taxi_pricing', value);
}

export async function loadTaxiConfig(token: string) {
  return loadAppConfig<Record<string, unknown>>(token, 'taxi-config');
}
export async function saveTaxiConfig(token: string, value: Record<string, unknown>) {
  return saveAppConfig(token, 'taxi_config', value);
}

export async function loadMapDefaults(token: string) {
  return loadAppConfig<Record<string, unknown>>(token, 'map-defaults');
}
export async function saveMapDefaults(token: string, value: Record<string, unknown>) {
  return saveAppConfig(token, 'map_defaults', value);
}

export async function loadHomeCategories(token: string) {
  return loadAppConfig<{ order: string[]; categories: Record<string, { titleAr: string; enabled: boolean }> }>(token, 'home-categories');
}
export async function saveHomeCategories(token: string, value: Record<string, unknown>) {
  return saveAppConfig(token, 'home_categories', value);
}

export async function loadSubCategories(token: string) {
  return loadAppConfig<Record<string, Array<{ id: string; titleAr: string; titleEn: string }>>>(token, 'sub-categories');
}
export async function saveSubCategories(token: string, value: Record<string, unknown>) {
  return saveAppConfig(token, 'sub_categories', value);
}

export async function loadNeighborhoods(token: string) {
  return loadAppConfig<Record<string, unknown>>(token, 'neighborhoods');
}
export async function saveNeighborhoods(token: string, value: Record<string, unknown>) {
  return saveAppConfig(token, 'neighborhoods', value);
}

export async function loadNotificationTexts(token: string) {
  return loadAppConfig<Record<string, unknown>>(token, 'notification-texts');
}
export async function saveNotificationTexts(token: string, value: Record<string, unknown>) {
  return saveAppConfig(token, 'notification_texts', value);
}

export async function loadAppTheme(token: string) {
  return loadAppConfig<Record<string, unknown>>(token, 'app-theme');
}
export async function saveAppTheme(token: string, value: Record<string, unknown>) {
  return saveAppConfig(token, 'app_theme', value);
}

export async function uploadImage(token: string, file: File): Promise<string> {
  const formData = new FormData();
  formData.append('file', file);
  formData.append('bucket', 'uploads');

  const url = `${PHONE_AUTH_BASE_URL}/upload`;
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
    },
    body: formData,
  });

  const text = await response.text();
  if (!response.ok) {
    let msg = 'فشل رفع الصورة';
    try { const p = JSON.parse(text); msg = p.message || msg; } catch { msg = text || msg; }
    throw new Error(msg);
  }

  const payload = JSON.parse(text);
  if (!payload.url) throw new Error('لم يتم استلام رابط الصورة من الخادم.');
  return payload.url;
}

export interface SupportChatThread {
  thread_type: 'support';
  thread_id: string;
  other_party_phone: string;
  other_party_name: string | null;
  thread_title?: string | null;
  context_label?: string;
  last_message: string;
  last_at: string;
  unread_count: number;
  has_unread: boolean;
}

export interface SupportChatMessage {
  id: string;
  thread_type: string;
  thread_id: string;
  sender_phone: string;
  receiver_phone: string | null;
  sender_name: string | null;
  message_type: string;
  content: string;
  created_at: string;
}

export async function loadSupportThreads(token: string): Promise<SupportChatThread[]> {
  return request<SupportChatThread[]>(DATABASE_API_BASE_URL, '/db/admin/support-threads', { token });
}

export async function loadSupportMessages(
  token: string,
  userPhone: string,
): Promise<SupportChatMessage[]> {
  const encoded = encodeURIComponent(userPhone.trim());
  const rows = await request<SupportChatMessage[]>(
    DATABASE_API_BASE_URL,
    `/db/chat/support/${encoded}`,
    { token },
  );
  return Array.isArray(rows) ? [...rows].reverse() : [];
}

export async function sendSupportMessage(
  token: string,
  userPhone: string,
  content: string,
  senderName = 'الإدارة',
): Promise<SupportChatMessage> {
  const encoded = encodeURIComponent(userPhone.trim());
  return request<SupportChatMessage>(DATABASE_API_BASE_URL, `/db/chat/support/${encoded}`, {
    method: 'POST',
    token,
    body: JSON.stringify({ content, senderName }),
  });
}

export async function markSupportThreadRead(token: string, userPhone: string) {
  const encoded = encodeURIComponent(userPhone.trim());
  return request<{ success: boolean }>(
    DATABASE_API_BASE_URL,
    `/db/chat/support/${encoded}/read`,
    { method: 'POST', token, body: '{}' },
  );
}
