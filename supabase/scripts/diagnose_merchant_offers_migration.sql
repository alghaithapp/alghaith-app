-- Diagnostics: why merchant_offers migration inserted 0 rows.

-- 1) Any offers still in app_state?
SELECT
  s.phone,
  jsonb_array_length(s.state -> 'merchantOffers') AS offer_count
FROM public.app_state s
WHERE s.state ? 'merchantOffers'
  AND jsonb_typeof(s.state -> 'merchantOffers') = 'array'
  AND jsonb_array_length(s.state -> 'merchantOffers') > 0
ORDER BY offer_count DESC
LIMIT 20;

-- 2) Merchants missing app_users.id (blocks INSERT)?
SELECT COUNT(*) AS merchants_without_user_id
FROM public.merchant_profiles mp
LEFT JOIN public.app_users u ON u.phone = mp.phone
WHERE u.id IS NULL;

-- 3) Sample app_state keys (see if offers lived under another key)
SELECT
  s.phone,
  array_agg(DISTINCT k.key ORDER BY k.key) AS state_keys
FROM public.app_state s
CROSS JOIN LATERAL jsonb_object_keys(s.state) AS k(key)
GROUP BY s.phone
LIMIT 10;

-- 4) Current table size
SELECT COUNT(*) AS merchant_offers_count FROM public.merchant_offers;
