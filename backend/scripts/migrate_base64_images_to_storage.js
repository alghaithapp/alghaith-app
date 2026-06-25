#!/usr/bin/env node
/**
 * ينقل صور Base64 من merchant_products و merchant_profiles إلى Supabase Storage
 * ويحدّث السجلات بروابط عامة.
 *
 * Usage:
 *   node scripts/migrate_base64_images_to_storage.js
 *   node scripts/migrate_base64_images_to_storage.js --dry-run
 *   node scripts/migrate_base64_images_to_storage.js --limit 50
 */
const fs = require('fs');
const path = require('path');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const { createClient } = require('@supabase/supabase-js');
const {
  isRemoteImageUrl,
  isBase64Image,
} = require('../services/image_refs');

function normalizeSupabaseUrl(url) {
  let normalized = String(url || '').trim();
  if (normalized.endsWith('/rest/v1/')) {
    normalized = normalized.slice(0, -'/rest/v1/'.length);
  } else if (normalized.endsWith('/rest/v1')) {
    normalized = normalized.slice(0, -'/rest/v1'.length);
  }
  while (normalized.endsWith('/')) normalized = normalized.slice(0, -1);
  return normalized;
}

function decodeBase64Payload(value) {
  let payload = String(value || '').trim();
  if (!payload) return null;
  if (payload.includes('base64,')) {
    payload = payload.split('base64,').pop();
  }
  try {
    const buffer = Buffer.from(payload, 'base64');
    if (!buffer.length) return null;
    return buffer;
  } catch (_) {
    return null;
  }
}

function mimeFromBase64(value) {
  const trimmed = String(value || '').trim();
  if (trimmed.startsWith('iVBOR')) return 'image/png';
  if (trimmed.startsWith('/9j/')) return 'image/jpeg';
  if (trimmed.startsWith('R0lG')) return 'image/gif';
  if (trimmed.startsWith('UklGR')) return 'image/webp';
  return 'image/jpeg';
}

function extFromMime(mime) {
  switch (mime) {
    case 'image/png':
      return 'png';
    case 'image/webp':
      return 'webp';
    case 'image/gif':
      return 'gif';
    default:
      return 'jpg';
  }
}

async function uploadBuffer({ supabaseUrl, serviceKey, bucket, objectPath, buffer, contentType }) {
  const uploadUrl = `${supabaseUrl}/storage/v1/object/${bucket}/${objectPath}`;
  const response = await fetch(uploadUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${serviceKey}`,
      apikey: serviceKey,
      'Content-Type': contentType,
      'x-upsert': 'true',
      'cache-control': 'public, max-age=31536000, immutable',
    },
    body: buffer,
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Upload failed (${response.status}): ${text}`);
  }
  return `${supabaseUrl}/storage/v1/object/public/${bucket}/${objectPath}`;
}

async function migrateProductRow({
  supabase,
  supabaseUrl,
  serviceKey,
  row,
  dryRun,
}) {
  const current = String(row.image_base64 || '').trim();
  if (!isBase64Image(current) || isRemoteImageUrl(current)) {
    const imageUrl = isRemoteImageUrl(row.image)
      ? String(row.image).trim()
      : isRemoteImageUrl(current)
        ? current
        : '';
    if (imageUrl && row.image !== imageUrl) {
      if (dryRun) {
        console.log(`[dry-run] product ${row.id}: normalize image URL`);
        return 'normalized';
      }
      await supabase
        .from('merchant_products')
        .update({ image: imageUrl, image_base64: null })
        .eq('id', row.id);
      return 'normalized';
    }
    return 'skipped';
  }

  const buffer = decodeBase64Payload(current);
  if (!buffer) return 'invalid';

  const mime = mimeFromBase64(current);
  const ext = extFromMime(mime);
  const objectPath = `migrated/products/${row.id}.${ext}`;

  if (dryRun) {
    console.log(`[dry-run] product ${row.id}: upload ${objectPath}`);
    return 'dry-run';
  }

  const publicUrl = await uploadBuffer({
    supabaseUrl,
    serviceKey,
    bucket: 'uploads',
    objectPath,
    buffer,
    contentType: mime,
  });

  await supabase
    .from('merchant_products')
    .update({ image: publicUrl, image_base64: null })
    .eq('id', row.id);

  return 'migrated';
}

async function migrateProfileField({
  supabase,
  supabaseUrl,
  serviceKey,
  phone,
  fieldName,
  value,
  dryRun,
}) {
  const current = String(value || '').trim();
  if (!isBase64Image(current) || isRemoteImageUrl(current)) return 'skipped';

  const buffer = decodeBase64Payload(current);
  if (!buffer) return 'invalid';

  const mime = mimeFromBase64(current);
  const ext = extFromMime(mime);
  const safePhone = String(phone || 'unknown').replace(/[^a-zA-Z0-9_-]/g, '_');
  const objectPath = `migrated/profiles/${safePhone}/${fieldName}.${ext}`;

  if (dryRun) {
    console.log(`[dry-run] profile ${phone}: ${fieldName} -> ${objectPath}`);
    return 'dry-run';
  }

  const publicUrl = await uploadBuffer({
    supabaseUrl,
    serviceKey,
    bucket: 'uploads',
    objectPath,
    buffer,
    contentType: mime,
  });

  const update =
    fieldName === 'profile_image'
      ? { profile_image_base64: publicUrl }
      : { [`${fieldName}_url`]: publicUrl };

  await supabase.from('merchant_profiles').update(update).eq('phone', phone);
  return 'migrated';
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const limitArg = process.argv.find((arg) => arg.startsWith('--limit='));
  const limit = limitArg ? Number.parseInt(limitArg.split('=')[1], 10) : 0;

  const supabaseUrl = normalizeSupabaseUrl(process.env.SUPABASE_URL);
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!supabaseUrl || !serviceKey) {
    throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.');
  }

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let productQuery = supabase
    .from('merchant_products')
    .select('id, image, image_base64')
    .order('created_at', { ascending: false });
  if (limit > 0) productQuery = productQuery.limit(limit);

  const { data: products, error: productsError } = await productQuery;
  if (productsError) throw productsError;

  const stats = { migrated: 0, normalized: 0, skipped: 0, invalid: 0, dryRun: 0 };

  for (const row of products || []) {
    const result = await migrateProductRow({
      supabase,
      supabaseUrl,
      serviceKey,
      row,
      dryRun,
    });
    stats[result] = (stats[result] || 0) + 1;
  }

  let profileQuery = supabase
    .from('merchant_profiles')
    .select('phone, profile_image_base64, cover_image_url, logo_image_url');
  if (limit > 0) profileQuery = profileQuery.limit(limit);

  const { data: profiles, error: profilesError } = await profileQuery;
  if (profilesError) throw profilesError;

  for (const profile of profiles || []) {
    for (const [field, value] of [
      ['profile_image', profile.profile_image_base64],
      ['cover_image', profile.cover_image_url],
      ['logo_image', profile.logo_image_url],
    ]) {
      const result = await migrateProfileField({
        supabase,
        supabaseUrl,
        serviceKey,
        phone: profile.phone,
        fieldName: field,
        value,
        dryRun,
      });
      stats[result] = (stats[result] || 0) + 1;
    }
  }

  console.log(JSON.stringify({ dryRun, stats }, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
