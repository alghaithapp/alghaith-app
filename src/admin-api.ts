import type {
  AdminAccountSummary,
  AdminReports,
  AdminSession,
  AdminTaxiTrip,
  AppUpdatePolicy,
  MaintenancePolicy,
  CourierSummary,
  DriverPreRegisterPayload,
  DriverPreRegisterResponse,
  HomeCategoriesConfig,
  HomeCategoryPlatformOverride,
  MerchantDetails,
  MerchantPreRegisterPayload,
  MerchantPreRegisterResponse,
  MerchantSummary,
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

export async function loadCouriers(token: string): Promise<CourierSummary[]> {
  return request<CourierSummary[]>(DATABASE_API_BASE_URL, '/db/admin/couriers', { token });
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
