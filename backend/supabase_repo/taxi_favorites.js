const { v4: uuidv4 } = require('uuid');
const { resolvePhoneKey, nowIso } = require('./common');
const { getUserState, saveUserState } = require('./users');

const MAX_PLACES = 10;

function normalizePlace(raw = {}) {
  const lat = Number(raw.lat ?? raw.latitude ?? 0);
  const lng = Number(raw.lng ?? raw.longitude ?? 0);
  const address = String(raw.address ?? raw.addressText ?? raw.address_text ?? '').trim();
  const label = String(raw.label ?? '').trim();
  return {
    id: String(raw.id || uuidv4()).trim(),
    label: label || 'مكان مفضل',
    address,
    lat: Number.isFinite(lat) ? lat : 0,
    lng: Number.isFinite(lng) ? lng : 0,
    sortOrder: Number.parseInt(raw.sortOrder ?? raw.sort_order, 10) || 0,
    updatedAt: raw.updatedAt || raw.updated_at || nowIso(),
  };
}

function readPlaces(state) {
  const list = state?.taxiFavoritePlaces;
  if (!Array.isArray(list)) return [];
  return list
    .map((item) => normalizePlace(item))
    .filter((item) => item.address && item.lat && item.lng)
    .sort((a, b) => a.sortOrder - b.sortOrder || a.label.localeCompare(b.label, 'ar'));
}

async function getTaxiFavoritePlaces(phone) {
  const phoneKey = await resolvePhoneKey(phone);
  const state = (await getUserState(phoneKey)) || {};
  return readPlaces(state);
}

async function saveTaxiFavoritePlace(phone, data = {}) {
  const phoneKey = await resolvePhoneKey(phone);
  const state = (await getUserState(phoneKey)) || {};
  const places = readPlaces(state);
  const next = normalizePlace(data);

  if (!next.address) {
    throw new Error('Address is required.');
  }
  if (!next.lat || !next.lng) {
    throw new Error('Valid coordinates are required.');
  }

  const existingIndex = places.findIndex((item) => item.id === next.id);
  if (existingIndex >= 0) {
    places[existingIndex] = { ...places[existingIndex], ...next, updatedAt: nowIso() };
  } else {
    if (places.length >= MAX_PLACES) {
      throw new Error(`Maximum ${MAX_PLACES} favorite places allowed.`);
    }
    next.sortOrder = places.length;
    places.push({ ...next, updatedAt: nowIso() });
  }

  await saveUserState(phoneKey, {
    ...state,
    taxiFavoritePlaces: places,
  });
  return places;
}

async function deleteTaxiFavoritePlace(phone, placeId) {
  const phoneKey = await resolvePhoneKey(phone);
  const id = String(placeId || '').trim();
  if (!id) throw new Error('Place id is required.');

  const state = (await getUserState(phoneKey)) || {};
  const places = readPlaces(state).filter((item) => item.id !== id);

  await saveUserState(phoneKey, {
    ...state,
    taxiFavoritePlaces: places,
  });
  return places;
}

module.exports = {
  getTaxiFavoritePlaces,
  saveTaxiFavoritePlace,
  deleteTaxiFavoritePlace,
  MAX_PLACES,
};
