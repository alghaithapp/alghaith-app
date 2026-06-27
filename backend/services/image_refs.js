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

const BASE64_FIELD_RE = /base64/i;

/** يزيل حقول Base64 من أي كائن قبل إرساله للعميل أو حفظه. */
function stripBase64Deep(value) {
  if (value == null) return value;
  if (Array.isArray(value)) {
    return value.map(stripBase64Deep);
  }
  if (typeof value !== 'object') {
    if (typeof value === 'string' && isBase64Image(value)) return '';
    return value;
  }

  const out = {};
  for (const [key, raw] of Object.entries(value)) {
    if (BASE64_FIELD_RE.test(key)) {
      if (typeof raw === 'string' && isRemoteImageUrl(raw)) {
        if (key.includes('profile')) out.profile_image_url = raw;
        else if (key.includes('cover')) out.cover_image_url = raw;
        else if (key.includes('logo')) out.logo_image_url = raw;
      } else if (Array.isArray(raw)) {
        const urls = raw
          .map((entry) => String(entry || '').trim())
          .filter((entry) => isRemoteImageUrl(entry));
        if (urls.length) out[key] = urls;
      }
      continue;
    }

    if (key === 'image' || key === 'imageUrl' || key === 'image_url') {
      const remote = pickRemoteImageUrl(raw);
      out[key] = remote || (isBase64Image(raw) ? '' : raw);
      continue;
    }

    out[key] = stripBase64Deep(raw);
  }
  return out;
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
  if (asset && !isBase64Image(asset)) {
    return { image: asset, image_base64: null };
  }

  return { image: '', image_base64: null };
}

function serializeProductRowForClient(row) {
  if (!row || typeof row !== 'object') return row;
  const out = stripBase64Deep({ ...row });
  const remote = pickRemoteImageUrl(
    out.image_url,
    out.image,
    out.image_base64,
    out.imageBase64
  );
  if (remote) {
    out.image = remote;
    out.image_url = remote;
  } else if (isBase64Image(out.image)) {
    out.image = '';
  }
  delete out.image_base64;
  delete out.imageBase64;

  const gallery = out.gallery_images_base64 ?? out.galleryImagesBase64;
  if (Array.isArray(gallery)) {
    out.gallery_images_base64 = gallery
      .map((entry) => String(entry || '').trim())
      .filter((entry) => isRemoteImageUrl(entry));
  }

  if (out.price !== undefined && out.price !== null) {
    out.price = Number.parseInt(String(out.price).replace(/,/g, ''), 10) || 0;
  }
  if (out.discounted_price !== undefined && out.discounted_price !== null) {
    out.discounted_price =
      Number.parseInt(String(out.discounted_price).replace(/,/g, ''), 10) || 0;
  }
  if (out.original_price !== undefined && out.original_price !== null) {
    out.original_price =
      Number.parseInt(String(out.original_price).replace(/,/g, ''), 10) || 0;
  }

  return out;
}

function normalizeMerchantImageField(value) {
  const trimmed = String(value || '').trim();
  if (!trimmed) return { url: '', base64: null };
  if (isRemoteImageUrl(trimmed)) return { url: trimmed, base64: null };
  if (isBase64Image(trimmed)) return { url: '', base64: null };
  return { url: trimmed, base64: null };
}

function serializeMerchantProfileForClient(profile) {
  if (!profile || typeof profile !== 'object') return profile;
  const out = stripBase64Deep({ ...profile });

  const cover = pickRemoteImageUrl(
    out.cover_image_url,
    out.coverImageUrl,
    out.coverImageBase64
  );
  if (cover) out.cover_image_url = cover;

  const logo = pickRemoteImageUrl(out.logo_image_url, out.logoImageUrl, out.logoImageBase64);
  if (logo) out.logo_image_url = logo;

  const profileImage = pickRemoteImageUrl(
    out.profile_image_url,
    out.profileImageUrl,
    out.profile_image_base64,
    out.profileImageBase64
  );
  if (profileImage) {
    out.profile_image_url = profileImage;
  }
  delete out.profile_image_base64;
  delete out.profileImageBase64;
  delete out.coverImageBase64;
  delete out.logoImageBase64;

  if (Array.isArray(out.work_sample_images_base64)) {
    out.work_sample_images_base64 = out.work_sample_images_base64.filter((entry) =>
      isRemoteImageUrl(entry)
    );
  }

  return out;
}

function serializeCustomerProfileForClient(profile) {
  if (!profile || typeof profile !== 'object') return profile;
  const out = stripBase64Deep({ ...profile });
  const avatar = pickRemoteImageUrl(
    out.avatar_url,
    out.avatarUrl,
    out.avatar_base64,
    out.customer_avatar_base64
  );
  if (avatar) out.avatar_url = avatar;
  delete out.avatar_base64;
  delete out.customer_avatar_base64;
  delete out.avatarBase64;
  delete out.customerAvatarBase64;
  return out;
}

function serializeUserStateForClient(state) {
  if (!state || typeof state !== 'object') return state || {};
  return stripBase64Deep(state);
}

module.exports = {
  isRemoteImageUrl,
  isBase64Image,
  pickRemoteImageUrl,
  stripBase64Deep,
  normalizeProductImagePayload,
  serializeProductRowForClient,
  normalizeMerchantImageField,
  serializeMerchantProfileForClient,
  serializeCustomerProfileForClient,
  serializeUserStateForClient,
};
