const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');

function isR2Configured() {
  return Boolean(
    process.env.R2_ACCOUNT_ID &&
      process.env.R2_ACCESS_KEY_ID &&
      process.env.R2_SECRET_ACCESS_KEY
  );
}

function getR2Client() {
  if (!isR2Configured()) return null;
  return new S3Client({
    region: 'auto',
    endpoint: `https://${process.env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: process.env.R2_ACCESS_KEY_ID,
      secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
    },
  });
}

function getR2BucketName() {
  return String(process.env.R2_BUCKET_NAME || 'alghaith-images').trim();
}

function getR2PublicBaseUrl() {
  return String(process.env.R2_PUBLIC_BASE_URL || '').trim().replace(/\/+$/, '');
}

function shouldUseMediaPrefix(baseUrl) {
  const trimmed = String(baseUrl || '').trim();
  return trimmed.includes('workers.dev');
}

function buildR2PublicUrl(objectPath) {
  const base = getR2PublicBaseUrl();
  if (!base) {
    throw new Error('R2_PUBLIC_BASE_URL is required for public image URLs.');
  }
  const path = String(objectPath || '').replace(/^\/+/, '');
  return shouldUseMediaPrefix(base) ? `${base}/media/${path}` : `${base}/${path}`;
}

function isSupabaseStorageUrl(value) {
  const trimmed = String(value || '').trim();
  return trimmed.includes('.supabase.co/storage/v1/object/');
}

function isWorkerMediaUrl(value) {
  const trimmed = String(value || '').trim();
  return trimmed.includes('.workers.dev/media/');
}

function isR2PublicUrl(value) {
  const trimmed = String(value || '').trim();
  if (!trimmed.startsWith('http')) return false;
  const base = getR2PublicBaseUrl();
  if (base && trimmed.startsWith(base)) return true;
  return isWorkerMediaUrl(trimmed);
}

async function uploadBufferToR2({ objectPath, buffer, contentType }) {
  const client = getR2Client();
  if (!client) {
    throw new Error('R2 is not configured (R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY).');
  }

  await client.send(
    new PutObjectCommand({
      Bucket: getR2BucketName(),
      Key: objectPath,
      Body: buffer,
      ContentType: contentType || 'application/octet-stream',
      CacheControl: 'public, max-age=31536000, immutable',
    })
  );

  return buildR2PublicUrl(objectPath);
}

module.exports = {
  isR2Configured,
  getR2PublicBaseUrl,
  buildR2PublicUrl,
  isSupabaseStorageUrl,
  isR2PublicUrl,
  isWorkerMediaUrl,
  uploadBufferToR2,
};
