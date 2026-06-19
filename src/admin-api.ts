import type {
  AdminAccountSummary,
  AdminReports,
  AdminSession,
  AppUpdatePolicy,
  CourierSummary,
  HomeCategoriesConfig,
  HomeCategoryPlatformOverride,
  MerchantDetails,
  MerchantSummary,
  ToggleBazaarResponse,
} from './admin-types';

// Tauri v2 HTTP plugin to bypass WebView restrictions on cross-origin fetch.
// We use a memoized static import pattern — import() only once at module init.
let tauriFetchModule: { fetch: typeof globalThis.fetch } | null = null;
let tauriFetchAttempted = false;

async function getTauriFetch(): Promise<typeof globalThis.fetch | null> {
  if (!tauriFetchAttempted) {
    tauriFetchAttempted = true;
    try {
      // This import succeeds only when running inside Tauri (plugin registered).
      const mod = await import('@tauri-apps/plugin-http');
      tauriFetchModule = mod;
    } catch {
      // Browser / non-Tauri environment — use native fetch.
      tauriFetchModule = null;
    }
  }
  return tauriFetchModule?.fetch ?? null;
}

function headersToObject(headers: Headers): Record<string, string> {
  const obj: Record<string, string> = {};
  headers.forEach((value, key) => { obj[key] = value; });
  return obj;
}

const DEFAULT_DATABASE_API_BASE = 'https://alghaith-app-production.up.railway.app';
const DEFAULT_PHONE_AUTH_BASE = 'https://lively-wind-9d98.alghaithapp.workers.dev';

function normalizeBaseUrl(input: string | undefined, fallback: string) {
  const raw = String(input || '').trim();
  if (!raw) return fallback;
  return raw.replace(/\/+$/, '');
}

function resolveApiBaseUrl(envValue: string | undefined, fallback: string) {
  // In production always use the known Railway/Worker URLs so a misconfigured
  // Vercel env var cannot point the admin panel at the static website (HTML).
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

async function request<T>(
  baseUrl: string,
  path: string,
  options: RequestInit & { token?: string } = {},
): Promise<T> {
  const headers = new Headers(options.headers || {});
  headers.set('Content-Type', 'application/json');
  if (options.token) {
    headers.set('Authorization', `Bearer ${options.token}`);
  }

  // Get the correct fetch implementation
  const fetchFn = await getTauriFetch() ?? globalThis.fetch.bind(globalThis);

  const response = await fetchFn(`${baseUrl}${path}`, {
    ...options,
    // Tauri plugin-http expects plain header objects
    headers: headersToObject(headers),
  });

  const text = await response.text();
  let payload: unknown = null;
  if (text) {
    try {
      payload = JSON.parse(text);
    } catch {
      const looksLikeHtml = /^\s*</.test(text);
      if (looksLikeHtml) {
        throw new Error(
          'الخادم أعاد صفحة HTML بدل JSON. تأكد أن لوحة الإدارة تتصل بخادم Railway وليس بموقع alghaithst.com.',
        );
      }
      throw new Error('استجابة غير متوقعة من الخادم.');
    }
  }

  if (!response.ok) {
    const message =
      payload &&
      typeof payload === 'object' &&
      payload !== null &&
      'message' in payload &&
      typeof (payload as { message?: unknown }).message === 'string'
        ? (payload as { message: string }).message
        : `Request failed (${response.status})`;
    throw new Error(message);
  }

  return payload as T;
}

export async function sendCode(phone: string, channel = 'sms') {
  await request(PHONE_AUTH_BASE_URL, '/auth/send-code', {
    method: 'POST',
    body: JSON.stringify({ phone, channel }),
  });
}

export async function verifyCode(
  phone: string,
  code: string,
): Promise<AdminSession> {
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

export async function loadAdminAccounts(
  token: string,
): Promise<AdminAccountSummary[]> {
  return request<AdminAccountSummary[]>(DATABASE_API_BASE_URL, '/db/admin/accounts', {
    token,
  });
}

export async function suspendAdminAccount(
  token: string,
  accountPhone: string,
  isSuspended: boolean,
) {
  return request(DATABASE_API_BASE_URL, '/db/admin/account-suspend', {
    method: 'PUT',
    token,
    body: JSON.stringify({ accountPhone, isSuspended }),
  });
}

export async function updateAdminAccountRole(
  token: string,
  accountPhone: string,
  role: string,
) {
  return request(DATABASE_API_BASE_URL, '/db/admin/account-role', {
    method: 'PUT',
    token,
    body: JSON.stringify({ accountPhone, role }),
  });
}

export async function deleteAdminAccount(token: string, accountPhone: string) {
  return request(DATABASE_API_BASE_URL, '/db/admin/account', {
    method: 'DELETE',
    token,
    body: JSON.stringify({ accountPhone }),
  });
}

export async function toggleCourierApproval(
  token: string,
  courierPhone: string,
  isApproved: boolean,
) {
  return request(DATABASE_API_BASE_URL, '/db/admin/courier-approval', {
    method: 'PUT',
    token,
    body: JSON.stringify({ courierPhone, isApproved }),
  });
}

export async function rejectCourierApplication(
  token: string,
  courierPhone: string,
  rejectionMessageAr: string,
  reasonKey = 'custom',
) {
  return request(DATABASE_API_BASE_URL, '/db/admin/courier-rejection', {
    method: 'PUT',
    token,
    body: JSON.stringify({ courierPhone, reasonKey, rejectionMessageAr }),
  });
}

export async function toggleDriverApproval(
  token: string,
  driverPhone: string,
  isApproved: boolean,
) {
  return request(DATABASE_API_BASE_URL, '/db/admin/driver-approval', {
    method: 'PUT',
    token,
    body: JSON.stringify({ driverPhone, isApproved }),
  });
}

export async function rejectDriverApplication(
  token: string,
  driverPhone: string,
  rejectionMessageAr: string,
  reasonKey = 'custom',
) {
  return request(DATABASE_API_BASE_URL, '/db/admin/driver-rejection', {
    method: 'PUT',
    token,
    body: JSON.stringify({ driverPhone, reasonKey, rejectionMessageAr }),
  });
}

export async function loadMerchantDetails(
  token: string,
  merchantPhone: string,
): Promise<MerchantDetails> {
  const query = new URLSearchParams({ merchantPhone });
  return request<MerchantDetails>(DATABASE_API_BASE_URL, `/db/admin/merchant-details?${query}`, {
    token,
  });
}

export async function toggleMerchantApproval(
  token: string,
  merchantPhone: string,
  isApproved: boolean,
) {
  return request(DATABASE_API_BASE_URL, '/db/admin/merchant-approval', {
    token,
    method: 'PUT',
    body: JSON.stringify({ merchantPhone, isApproved }),
  });
}

export async function rejectMerchantApplication(
  token: string,
  merchantPhone: string,
  rejectionMessageAr: string,
  reasonKey = 'custom',
) {
  return request(DATABASE_API_BASE_URL, '/db/admin/merchant-rejection', {
    token,
    method: 'PUT',
    body: JSON.stringify({ merchantPhone, reasonKey, rejectionMessageAr }),
  });
}

export async function toggleMerchantFreeze(
  token: string,
  merchantPhone: string,
  isFrozen: boolean,
) {
  return request(DATABASE_API_BASE_URL, '/db/admin/merchant-freeze', {
    method: 'PUT',
    token,
    body: JSON.stringify({ merchantPhone, isFrozen }),
  });
}

export async function syncMerchantBazaarProducts(
  token: string,
  merchantPhone: string,
) {
  return request<{ success: boolean; synced: number; totalEligible: number }>(
    DATABASE_API_BASE_URL,
    '/db/admin/merchant-bazaar-sync',
    {
      method: 'POST',
      token,
      body: JSON.stringify({ merchantPhone }),
    },
  );
}

export async function toggleMerchantBazaar(
  token: string,
  merchantPhone: string,
  isBazaarMember: boolean,
) {
  return request<ToggleBazaarResponse>(
    DATABASE_API_BASE_URL,
    '/db/admin/merchant-bazaar',
    {
      method: 'PUT',
      token,
      body: JSON.stringify({ merchantPhone, isBazaarMember }),
    },
  );
}

export async function loadAppUpdatePolicy(token: string): Promise<AppUpdatePolicy> {
  return request<AppUpdatePolicy>(DATABASE_API_BASE_URL, '/db/admin/app-update-policy', {
    token,
  });
}

export async function saveAppUpdatePolicy(
  token: string,
  policy: Pick<
    AppUpdatePolicy,
    | 'minBuildNumber'
    | 'minVersionName'
    | 'latestBuildNumber'
    | 'latestVersionName'
    | 'messageAr'
    | 'androidStoreUrl'
    | 'iosStoreUrl'
  >,
) {
  return request<{ success: boolean; policy: AppUpdatePolicy }>(
    DATABASE_API_BASE_URL,
    '/db/admin/app-update-policy',
    {
      method: 'PUT',
      token,
      body: JSON.stringify(policy),
    },
  );
}

export async function loadHomeCategoriesConfig(
  token: string,
): Promise<HomeCategoriesConfig> {
  return request<HomeCategoriesConfig>(
    DATABASE_API_BASE_URL,
    '/app/home-categories',
    { token },
  );
}

export async function saveHomeCategoriesConfig(
  token: string,
  overrides: Record<string, HomeCategoryPlatformOverride>,
): Promise<HomeCategoriesConfig> {
  return request<HomeCategoriesConfig>(
    DATABASE_API_BASE_URL,
    '/db/admin/home-categories',
    {
      method: 'PUT',
      token,
      body: JSON.stringify({ overrides }),
    },
  );
}
