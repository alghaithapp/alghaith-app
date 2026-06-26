const {
  selectSingleByPhone,
  selectMany,
  resolvePhoneKey,
  saveRow,
  nowIso,
  normalizeArray,
  assertSupabaseAdmin,
} = require('./common');
const { ensureAppUser } = require('./users');

function rowToOfferMap(row) {
  if (!row) return null;
  return {
    id: String(row.id || '').trim(),
    titleAr: row.title_ar || '',
    titleEn: row.title_en || '',
    discountPercent: Number(row.discount_percent || 0),
    startDate: row.start_date || '',
    endDate: row.end_date || '',
    productNamesAr: normalizeArray(row.product_names_ar),
    isActive: row.is_active !== false,
  };
}

function offerToRow(phoneKey, offer = {}) {
  const id = String(offer.id || '').trim();
  if (!id) throw new Error('Offer id is required.');
  return {
    id,
    phone: phoneKey,
    title_ar: String(offer.titleAr ?? offer.title_ar ?? '').trim(),
    title_en: String(offer.titleEn ?? offer.title_en ?? '').trim(),
    discount_percent: Number.parseInt(offer.discountPercent ?? offer.discount_percent, 10) || 0,
    start_date: String(offer.startDate ?? offer.start_date ?? '').trim(),
    end_date: String(offer.endDate ?? offer.end_date ?? '').trim(),
    product_names_ar: normalizeArray(offer.productNamesAr ?? offer.product_names_ar),
    is_active: offer.isActive !== false && offer.is_active !== false,
    updated_at: nowIso(),
  };
}

async function getMerchantOffers(phone) {
  const phoneKey = await resolvePhoneKey(phone);
  const rows = await selectMany(
    'merchant_offers',
    [{ method: 'eq', column: 'phone', value: phoneKey }],
    { column: 'updated_at', ascending: false },
    100
  );
  return (rows || []).map(rowToOfferMap).filter(Boolean);
}

async function saveMerchantOffer(phone, offer = {}) {
  const phoneKey = await resolvePhoneKey(phone);
  await ensureAppUser(phoneKey);
  const row = offerToRow(phoneKey, offer);
  await saveRow('merchant_offers', row, 'id');
  return rowToOfferMap(row);
}

async function deleteMerchantOffer(phone, offerId) {
  const phoneKey = await resolvePhoneKey(phone);
  const id = String(offerId || '').trim();
  if (!id) throw new Error('Offer id is required.');
  const supabase = assertSupabaseAdmin();
  const { error } = await supabase
    .from('merchant_offers')
    .delete()
    .eq('id', id)
    .eq('phone', phoneKey);
  if (error) throw new Error(error.message);
}

async function getMerchantReviewsForMerchant(phone) {
  const phoneKey = await resolvePhoneKey(phone);
  const rows = await selectMany(
    'merchant_reviews',
    [{ method: 'eq', column: 'merchant_phone', value: phoneKey }],
    { column: 'created_at', ascending: false },
    100
  );
  return (rows || []).map((row) => ({
    id: String(row.order_id || row.id || '').trim(),
    customerName: String(row.customer_name || row.customer_phone || '').trim(),
    stars: Number(row.stars || 0),
    comment: String(row.comment || '').trim(),
    date: row.created_at
      ? new Date(row.created_at).toLocaleDateString('ar-EG')
      : '',
    reply: String(row.reply || '').trim() || null,
  }));
}

async function replyMerchantReview(phone, reviewId, reply) {
  const phoneKey = await resolvePhoneKey(phone);
  const id = String(reviewId || '').trim();
  if (!id) throw new Error('Review id is required.');
  const supabase = assertSupabaseAdmin();
  const { data, error } = await supabase
    .from('merchant_reviews')
    .update({ reply: String(reply || '').trim(), updated_at: nowIso() })
    .eq('merchant_phone', phoneKey)
    .or(`order_id.eq.${id},id.eq.${id}`)
    .select()
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) throw new Error('Review not found.');
  return {
    id: String(data.order_id || data.id || '').trim(),
    customerName: String(data.customer_name || data.customer_phone || '').trim(),
    stars: Number(data.stars || 0),
    comment: String(data.comment || '').trim(),
    date: data.created_at
      ? new Date(data.created_at).toLocaleDateString('ar-EG')
      : '',
    reply: String(data.reply || '').trim() || null,
  };
}

module.exports = {
  getMerchantOffers,
  saveMerchantOffer,
  deleteMerchantOffer,
  getMerchantReviewsForMerchant,
  replyMerchantReview,
  rowToOfferMap,
};
