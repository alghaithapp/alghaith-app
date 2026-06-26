-- Migrate merchantOffers from app_state → merchant_offers (production schema).
-- merchant_profiles: phone PK, user_id uuid (no id column).

INSERT INTO public.merchant_offers (
  id,
  merchant_user_id,
  merchant_service_id,
  service_id,
  title_ar,
  title_en,
  discount_percent,
  start_date,
  end_date,
  product_names_ar,
  is_active,
  updated_at
)
SELECT
  CASE
    WHEN NULLIF(TRIM(offer ->> 'id'), '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      THEN NULLIF(TRIM(offer ->> 'id'), '')::uuid
    ELSE gen_random_uuid()
  END,
  u.id,
  COALESCE(mp.user_id, u.id),
  COALESCE(
    NULLIF(TRIM(offer ->> 'serviceId'), ''),
    NULLIF(TRIM(offer ->> 'service_id'), ''),
    NULLIF(TRIM(mp.primary_service_id), ''),
    NULLIF(TRIM(mp.active_service_id), ''),
    'restaurant'
  ),
  COALESCE(offer ->> 'titleAr', ''),
  COALESCE(offer ->> 'titleEn', ''),
  COALESCE((offer ->> 'discountPercent')::integer, 0),
  CASE
    WHEN NULLIF(TRIM(COALESCE(offer ->> 'startDate', offer ->> 'start_date')), '') IS NULL THEN NULL::date
    ELSE (substring(
      NULLIF(TRIM(COALESCE(offer ->> 'startDate', offer ->> 'start_date')), '')
      from 1 for 10
    ))::date
  END,
  CASE
    WHEN NULLIF(TRIM(COALESCE(offer ->> 'endDate', offer ->> 'end_date')), '') IS NULL THEN NULL::date
    ELSE (substring(
      NULLIF(TRIM(COALESCE(offer ->> 'endDate', offer ->> 'end_date')), '')
      from 1 for 10
    ))::date
  END,
  COALESCE(
    (
      SELECT array_agg(elem ORDER BY ord)
      FROM jsonb_array_elements_text(
        CASE
          WHEN jsonb_typeof(COALESCE(offer -> 'productNamesAr', offer -> 'product_names_ar', '[]'::jsonb)) = 'array'
            THEN COALESCE(offer -> 'productNamesAr', offer -> 'product_names_ar', '[]'::jsonb)
          ELSE '[]'::jsonb
        END
      ) WITH ORDINALITY AS t(elem, ord)
    ),
    ARRAY[]::text[]
  ),
  COALESCE((offer ->> 'isActive')::boolean, true),
  NOW()
FROM public.app_state s
INNER JOIN public.app_users u ON u.phone = s.phone
LEFT JOIN public.merchant_profiles mp ON mp.phone = s.phone
CROSS JOIN LATERAL jsonb_array_elements(
  CASE
    WHEN jsonb_typeof(s.state -> 'merchantOffers') = 'array'
      THEN s.state -> 'merchantOffers'
    ELSE '[]'::jsonb
  END
) AS offer
WHERE u.id IS NOT NULL
ON CONFLICT (id) DO UPDATE SET
  merchant_user_id = EXCLUDED.merchant_user_id,
  merchant_service_id = COALESCE(EXCLUDED.merchant_service_id, merchant_offers.merchant_service_id),
  service_id = EXCLUDED.service_id,
  title_ar = EXCLUDED.title_ar,
  title_en = EXCLUDED.title_en,
  discount_percent = EXCLUDED.discount_percent,
  start_date = EXCLUDED.start_date,
  end_date = EXCLUDED.end_date,
  product_names_ar = EXCLUDED.product_names_ar,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();
