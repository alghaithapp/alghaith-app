function isRemoteImageUrl(value) {
  const trimmed = String(value || '').trim();
  return trimmed.startsWith('http://') || trimmed.startsWith('https://');
}

function isBase64Image(value) {
  const trimmed = String(value || '').trim();
  if (!trimmed || isRemoteImageUrl(trimmed)) return false;
  let payload = trimmed;
  if (payload.includes('base64,')) {
    payload = payload.split('base64,').pop();
  }
  return (
    payload.startsWith('iVBOR') ||
    payload.startsWith('/9j/') ||
    payload.startsWith('R0lG') ||
    payload.startsWith('UklGR') ||
    payload.length > 120
  );
}

function pickRemoteImageUrl(...values) {
  for (const value of values) {
    if (isRemoteImageUrl(value)) return String(value).trim();
  }
  return '';
}

function normalizeProductImagePayload(data = {}) {
  const remote = pickRemoteImageUrl(
    data.image_url,
    data.imageUrl,
    data.image,
    data.image_base64,
    data.imageBase64
  );
  if (remote) {
    return { image: remote, image_base64: null };
  }

  const asset = String(data.image ?? '').trim();
  const base64 = String(data.image_base64 ?? data.imageBase64 ?? '').trim();
  return {
    image: asset,
    image_base64: isBase64Image(base64) ? base64 : base64 || null,
  };
}

function serializeProductRowForClient(row) {
  if (!row || typeof row !== 'object') return row;
  const out = { ...row };
  const remote = pickRemoteImageUrl(out.image_url, out.image, out.image_base64);
  if (remote) {
    out.image = remote;
    out.image_url = remote;
    out.image_base64 = '';
  }

  const gallery = out.gallery_images_base64 ?? out.galleryImagesBase64;
  if (Array.isArray(gallery)) {
    const normalized = gallery
      .map((entry) => String(entry || '').trim())
      .filter(Boolean)
      .map((entry) => (isRemoteImageUrl(entry) ? entry : entry));
    out.gallery_images_base64 = normalized.filter((entry) => isRemoteImageUrl(entry));
  }

  return out;
}

function normalizeMerchantImageField(value) {
  const trimmed = String(value || '').trim();
  if (!trimmed) return { url: '', base64: null };
  if (isRemoteImageUrl(trimmed)) return { url: trimmed, base64: null };
  return { url: trimmed, base64: trimmed };
}

function serializeMerchantProfileForClient(profile) {
  if (!profile || typeof profile !== 'object') return profile;
  const out = { ...profile };

  const cover = pickRemoteImageUrl(out.cover_image_url, out.coverImageUrl, out.coverImageBase64);
  if (cover) {
    out.cover_image_url = cover;
  }

  const logo = pickRemoteImageUrl(out.logo_image_url, out.logoImageUrl, out.logoImageBase64);
  if (logo) {
    out.logo_image_url = logo;
  }

  const profileImage = pickRemoteImageUrl(
    out.profile_image_url,
    out.profileImageUrl,
    out.profile_image_base64,
    out.profileImageBase64
  );
  if (profileImage) {
    out.profile_image_url = profileImage;
    out.profile_image_base64 = '';
  } else if (isBase64Image(out.profile_image_base64)) {
    // keep legacy base64 until migrated
  } else if (out.profile_image_base64 && isRemoteImageUrl(out.profile_image_base64)) {
    out.profile_image_url = out.profile_image_base64;
    out.profile_image_base64 = '';
  }

  return out;
}

module.exports = {
  isRemoteImageUrl,
  isBase64Image,
  pickRemoteImageUrl,
  normalizeProductImagePayload,
  serializeProductRowForClient,
  normalizeMerchantImageField,
  serializeMerchantProfileForClient,
};
