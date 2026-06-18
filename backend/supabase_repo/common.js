const { createClient } = require('@supabase/supabase-js');
const WebSocket = require('ws');

function normalizeSupabaseUrl(url) {
  if (!url) return '';
  let normalized = String(url).trim();
  if (normalized.endsWith('/rest/v1/')) {
    normalized = normalized.slice(0, -'/rest/v1/'.length);
  } else if (normalized.endsWith('/rest/v1')) {
    normalized = normalized.slice(0, -'/rest/v1'.length);
  }
  while (normalized.endsWith('/')) {
    normalized = normalized.slice(0, -1);
  }
  return normalized;
}

const supabaseUrl = normalizeSupabaseUrl(
  process.env.SUPABASE_URL || process.env.SUPABASE_PROJECT_URL || ''
);
const supabaseServiceRoleKey =
  process.env.SUPABASE_SERVICE_ROLE_KEY ||
  process.env.SUPABASE_SERVICE_ROLE ||
  '';
const isConfigured = Boolean(supabaseUrl && supabaseServiceRoleKey);

function decodeJwtPayload(token) {
  const parts = String(token || '').split('.');
  if (parts.length < 2) return null;
  const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, '=');
  try {
    const json = Buffer.from(padded, 'base64').toString('utf8');
    return JSON.parse(json);
  } catch (_) {
    return null;
  }
}

const supabaseKeyPayload = decodeJwtPayload(supabaseServiceRoleKey);
const supabaseKeyRole = supabaseKeyPayload?.role || null;
const isLikelyAnonKey = supabaseKeyRole === 'anon';
const isLikelyServiceRoleKey = supabaseKeyRole === 'service_role';

let supabaseAdmin = null;
const schemaColumnCache = new Map();

function getSupabaseAdmin() {
  if (supabaseAdmin) return supabaseAdmin;
  if (!supabaseUrl || !supabaseServiceRoleKey) {
    return null;
  }
  supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
    realtime: {
      transport: WebSocket,
    },
  });
  return supabaseAdmin;
}

function assertSupabaseAdmin() {
  const admin = getSupabaseAdmin();
  if (!admin) {
    throw new Error(
      'SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required for database operations.'
    );
  }
  return admin;
}

function nowIso() {
  return new Date().toISOString();
}

function assignIfDefined(target, key, value) {
  if (value !== undefined) {
    target[key] = value;
  }
}

function normalizeArray(value) {
  if (Array.isArray(value)) return value;
  if (typeof value === 'string' && value.trim().length > 0) {
    try {
      const parsed = JSON.parse(value);
      if (Array.isArray(parsed)) {
        return parsed;
      }
    } catch (_) {}
  }
  return [];
}

function normalizeObject(value) {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value;
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    try {
      const parsed = JSON.parse(value);
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        return parsed;
      }
    } catch (_) {}
  }
  return {};
}

function parseOptionalBoolean(value) {
  if (value === undefined || value === null) return undefined;
  if (typeof value === 'boolean') return value;
  const normalized = String(value).trim().toLowerCase();
  if (!normalized) return undefined;
  if (['true', '1', 'yes', 'y', 'on'].includes(normalized)) return true;
  if (['false', '0', 'no', 'n', 'off'].includes(normalized)) return false;
  return undefined;
}

function isUuid(value) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    String(value || '').trim()
  );
}

function getPhoneVariants(phone) {
  const digits = String(phone || '').replace(/\D/g, '');
  if (digits.length < 10) {
    const trimmed = String(phone || '').trim();
    return trimmed ? [trimmed] : [];
  }
  const core = digits.slice(-10);
  return [`+964${core}`, `964${core}`, `0${core}`, core];
}

function canonicalPhone(phone) {
  const digits = String(phone || '').replace(/\D/g, '');
  if (!digits) return '';
  if (digits.startsWith('0') && digits.length >= 11) {
    return `+964${digits.slice(1)}`;
  }
  if (digits.startsWith('964')) {
    return `+${digits}`;
  }
  if (digits.length === 10 && digits.startsWith('7')) {
    return `+964${digits}`;
  }
  const trimmed = String(phone || '').trim();
  return trimmed.startsWith('+') ? trimmed : `+${digits}`;
}

function phonesOverlap(left, right) {
  const leftVariants = new Set(getPhoneVariants(left));
  if (leftVariants.size === 0) return false;
  for (const variant of getPhoneVariants(right)) {
    if (leftVariants.has(variant)) {
      return true;
    }
  }
  return false;
}

async function selectSingleByPhone(table, phone) {
  const variants = getPhoneVariants(phone);
  if (variants.length === 0) return null;

  const supabase = assertSupabaseAdmin();
  const { data, error } = await supabase
    .from(table)
    .select()
    .in('phone', variants)
    .order('updated_at', { ascending: false })
    .limit(1);
  if (error) throw new Error(error.message);
  if (!Array.isArray(data) || data.length === 0) return null;
  return data[0];
}

async function resolvePhoneKey(phone) {
  const raw = String(phone || '').trim();
  if (!raw) return raw;

  const tables = ['app_users', 'customer_profiles', 'merchant_profiles', 'app_state'];
  for (const table of tables) {
    const existing = await selectSingleByPhone(table, phone);
    if (existing?.phone) {
      return existing.phone;
    }
  }
  const canonical = canonicalPhone(phone);
  // مفاتيح نظامية غير رقمية (مثل إعدادات المنصة) تُحفظ كما هي.
  if (canonical) return canonical;
  return raw;
}

async function selectSingle(table, column, value) {
  const supabase = assertSupabaseAdmin();
  const { data, error } = await supabase
    .from(table)
    .select()
    .eq(column, value)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data || null;
}

async function selectMany(table, filters = [], orderBy = null) {
  const supabase = assertSupabaseAdmin();
  let query = supabase.from(table).select();
  for (const filter of filters) {
    query = query[filter.method](filter.column, filter.value);
  }
  if (orderBy) {
    query = query.order(orderBy.column, { ascending: orderBy.ascending });
  }
  const { data, error } = await query;
  if (error) throw new Error(error.message);
  return Array.isArray(data) ? data : [];
}

async function hasColumn(table, column) {
  const cacheKey = `${table}.${column}`;
  if (schemaColumnCache.has(cacheKey)) {
    return schemaColumnCache.get(cacheKey);
  }

  const supabase = assertSupabaseAdmin();
  const { error } = await supabase.from(table).select(column).limit(1);
  const exists = !error;
  schemaColumnCache.set(cacheKey, exists);
  return exists;
}

async function saveRow(table, payload, conflictColumn) {
  const supabase = assertSupabaseAdmin();
  let conflictValue = payload[conflictColumn];
  if (
    conflictValue === undefined ||
    conflictValue === null ||
    String(conflictValue).trim() === ''
  ) {
    throw new Error(`Missing ${conflictColumn} for ${table}.`);
  }

  if (conflictColumn === 'phone') {
    conflictValue = await resolvePhoneKey(conflictValue);
    payload.phone = conflictValue;
    const existing = await selectSingleByPhone(table, conflictValue);
    if (existing) {
      const { data, error } = await supabase
        .from(table)
        .update(payload)
        .eq('phone', existing.phone)
        .select();
      if (error) throw new Error(error.message);
      if (Array.isArray(data)) return data[0] || null;
      return data || null;
    }
  } else {
    const existingQuery = await supabase
      .from(table)
      .select(conflictColumn)
      .eq(conflictColumn, conflictValue)
      .maybeSingle();
    if (existingQuery.error) {
      throw new Error(existingQuery.error.message);
    }

    if (existingQuery.data) {
      const { data, error } = await supabase
        .from(table)
        .update(payload)
        .eq(conflictColumn, conflictValue)
        .select();
      if (error) throw new Error(error.message);
      if (Array.isArray(data)) return data[0] || null;
      return data || null;
    }
  }

  const { data, error } = await supabase.from(table).insert(payload).select();
  if (error) throw new Error(error.message);
  if (Array.isArray(data)) return data[0] || null;
  return data || null;
}

async function deleteRow(table, column, value) {
  const supabase = assertSupabaseAdmin();
  const { error } = await supabase.from(table).delete().eq(column, value);
  if (error) throw new Error(error.message);
}

const PLATFORM_SETTINGS_PHONE = '__platform_settings__';
const PLATFORM_ADMIN_PHONES = Object.freeze([
  '07744009992',
  '+9647744009992',
]);

module.exports = {
  isConfigured,
  supabaseKeyRole,
  isLikelyAnonKey,
  isLikelyServiceRoleKey,
  canonicalPhone,
  normalizeSupabaseUrl,
  decodeJwtPayload,
  getSupabaseAdmin,
  assertSupabaseAdmin,
  nowIso,
  assignIfDefined,
  normalizeArray,
  normalizeObject,
  parseOptionalBoolean,
  isUuid,
  getPhoneVariants,
  phonesOverlap,
  selectSingleByPhone,
  resolvePhoneKey,
  selectSingle,
  selectMany,
  hasColumn,
  saveRow,
  deleteRow,
  PLATFORM_SETTINGS_PHONE,
  PLATFORM_ADMIN_PHONES,
};
