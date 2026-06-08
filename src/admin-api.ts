import type {
  AdminReports,
  AdminSession,
  MerchantDetails,
  MerchantSummary,
} from './admin-types';

const DEFAULT_API_BASE = 'https://alghaith-app-production.up.railway.app';

function normalizeBaseUrl(input: string | undefined) {
  const raw = String(input || '').trim();
  if (!raw) return DEFAULT_API_BASE;
  return raw.replace(/\/+$/, '');
}

export const API_BASE_URL = normalizeBaseUrl(import.meta.env.VITE_BACKEND_URL);

async function request<T>(
  path: string,
  options: RequestInit & { token?: string } = {},
): Promise<T> {
  const headers = new Headers(options.headers || {});
  headers.set('Content-Type', 'application/json');
  if (options.token) {
    headers.set('Authorization', `Bearer ${options.token}`);
  }

  const response = await fetch(`${API_BASE_URL}${path}`, {
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
  await request('/auth/send-code', {
    method: 'POST',
    body: JSON.stringify({ phone, channel }),
  });
}

export async function verifyCode(
  phone: string,
  code: string,
): Promise<AdminSession> {
  return request<AdminSession>('/auth/verify-code', {
    method: 'POST',
    body: JSON.stringify({ phone, code }),
  });
}

export async function loadAdminReports(token: string): Promise<AdminReports> {
  return request<AdminReports>('/db/admin/reports', { token });
}

export async function loadMerchants(token: string): Promise<MerchantSummary[]> {
  return request<MerchantSummary[]>('/db/admin/merchants', { token });
}

export async function loadMerchantDetails(
  token: string,
  merchantPhone: string,
): Promise<MerchantDetails> {
  const query = new URLSearchParams({ merchantPhone });
  return request<MerchantDetails>(`/db/admin/merchant-details?${query}`, {
    token,
  });
}

export async function toggleMerchantFreeze(
  token: string,
  merchantPhone: string,
  isFrozen: boolean,
) {
  return request('/db/admin/merchant-freeze', {
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
  return request('/db/admin/merchant-bazaar', {
    method: 'PUT',
    token,
    body: JSON.stringify({ merchantPhone, isBazaarMember }),
  });
}
