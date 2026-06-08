import type {
  AdminReports,
  AdminSession,
  MerchantDetails,
  MerchantSummary,
} from './admin-types';

const DEFAULT_DATABASE_API_BASE = 'https://alghaith-app-production.up.railway.app';
const DEFAULT_PHONE_AUTH_BASE = 'https://lively-wind-9d98.alghaithapp.workers.dev';

function normalizeBaseUrl(input: string | undefined, fallback: string) {
  const raw = String(input || '').trim();
  if (!raw) return fallback;
  return raw.replace(/\/+$/, '');
}

export const DATABASE_API_BASE_URL = normalizeBaseUrl(
  import.meta.env.VITE_BACKEND_URL,
  DEFAULT_DATABASE_API_BASE,
);
export const PHONE_AUTH_BASE_URL = normalizeBaseUrl(
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

  const response = await fetch(`${baseUrl}${path}`, {
    ...options,
    headers,
  });

  const text = await response.text();
  const payload = text ? JSON.parse(text) : null;

  if (!response.ok) {
    const message =
      payload && typeof payload.message === 'string'
        ? payload.message
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

export async function loadMerchantDetails(
  token: string,
  merchantPhone: string,
): Promise<MerchantDetails> {
  const query = new URLSearchParams({ merchantPhone });
  return request<MerchantDetails>(DATABASE_API_BASE_URL, `/db/admin/merchant-details?${query}`, {
    token,
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

export async function toggleMerchantBazaar(
  token: string,
  merchantPhone: string,
  isBazaarMember: boolean,
) {
  return request(DATABASE_API_BASE_URL, '/db/admin/merchant-bazaar', {
    method: 'PUT',
    token,
    body: JSON.stringify({ merchantPhone, isBazaarMember }),
  });
}
