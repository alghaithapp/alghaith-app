-- Phase 3: app_state UI-only + admin_roles + merchant_offers tables.

CREATE TABLE IF NOT EXISTS public.admin_roles (
  phone text PRIMARY KEY REFERENCES public.app_users(phone) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'admin',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_roles_role ON public.admin_roles (role);

DROP TRIGGER IF EXISTS trg_admin_roles_updated_at ON public.admin_roles;
CREATE TRIGGER trg_admin_roles_updated_at
BEFORE UPDATE ON public.admin_roles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS public.merchant_offers (
  id text PRIMARY KEY,
  phone text NOT NULL REFERENCES public.app_users(phone) ON DELETE CASCADE,
  title_ar text NOT NULL DEFAULT '',
  title_en text NOT NULL DEFAULT '',
  discount_percent integer NOT NULL DEFAULT 0,
  start_date text NOT NULL DEFAULT '',
  end_date text NOT NULL DEFAULT '',
  product_names_ar jsonb NOT NULL DEFAULT '[]'::jsonb,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_merchant_offers_phone
  ON public.merchant_offers (phone, is_active);

DROP TRIGGER IF EXISTS trg_merchant_offers_updated_at ON public.merchant_offers;
CREATE TRIGGER trg_merchant_offers_updated_at
BEFORE UPDATE ON public.merchant_offers
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- UI-only merge: strip all keys except the allow-list.
CREATE OR REPLACE FUNCTION merge_app_state(p_phone TEXT, p_state JSONB)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_allowed TEXT[] := ARRAY[
    'darkMode', 'inAppAlertsEnabled', 'notificationsEnabled',
    'lastMainTab', 'homeCategoryFilter', 'catalogSearchHistory',
    'drafts', 'syncHints', 'skippedCustomerSetup', 'driverType',
    'taxiFavoritePlaces', 'adminRole', 'admin_role', 'lang',
    'accountSuspended', 'suspendedAt'
  ];
  v_incoming JSONB := '{}'::JSONB;
  v_merged JSONB;
  v_key TEXT;
BEGIN
  IF p_state IS NOT NULL THEN
    FOREACH v_key IN ARRAY v_allowed LOOP
      IF p_state ? v_key THEN
        v_incoming := jsonb_set(v_incoming, ARRAY[v_key], p_state -> v_key, true);
      END IF;
    END LOOP;
  END IF;

  INSERT INTO app_state (phone, state, updated_at)
  VALUES (p_phone, v_incoming, NOW())
  ON CONFLICT (phone)
  DO UPDATE SET
    state = CASE
      WHEN p_state IS NULL THEN EXCLUDED.state
      ELSE (
        SELECT COALESCE(jsonb_object_agg(key, value), '{}'::JSONB)
        FROM (
          SELECT key, value
          FROM jsonb_each(
            COALESCE(app_state.state, '{}'::JSONB) || v_incoming
          )
          WHERE key = ANY(v_allowed)
        ) filtered
      )
    END,
    updated_at = NOW();

  RETURN (SELECT state FROM app_state WHERE phone = p_phone);
END;
$$;

-- Migrate adminAccess from app_state into admin_roles
INSERT INTO public.admin_roles (phone, role, updated_at)
SELECT
  s.phone,
  COALESCE(NULLIF(TRIM(s.state ->> 'adminRole'), ''), NULLIF(TRIM(s.state ->> 'admin_role'), ''), 'admin'),
  NOW()
FROM public.app_state s
WHERE (s.state ->> 'adminAccess')::boolean IS TRUE
ON CONFLICT (phone) DO UPDATE SET
  role = EXCLUDED.role,
  updated_at = NOW();

-- Migrate merchantOffers from app_state into merchant_offers
INSERT INTO public.merchant_offers (
  id, phone, title_ar, title_en, discount_percent,
  start_date, end_date, product_names_ar, is_active, updated_at
)
SELECT
  COALESCE(NULLIF(TRIM(offer ->> 'id'), ''), gen_random_uuid()::text),
  s.phone,
  COALESCE(offer ->> 'titleAr', ''),
  COALESCE(offer ->> 'titleEn', ''),
  COALESCE((offer ->> 'discountPercent')::integer, 0),
  COALESCE(offer ->> 'startDate', ''),
  COALESCE(offer ->> 'endDate', ''),
  COALESCE(offer -> 'productNamesAr', '[]'::jsonb),
  COALESCE((offer ->> 'isActive')::boolean, true),
  NOW()
FROM public.app_state s
CROSS JOIN LATERAL jsonb_array_elements(
  CASE
    WHEN jsonb_typeof(s.state -> 'merchantOffers') = 'array'
    THEN s.state -> 'merchantOffers'
    ELSE '[]'::jsonb
  END
) AS offer
ON CONFLICT (id) DO UPDATE SET
  phone = EXCLUDED.phone,
  title_ar = EXCLUDED.title_ar,
  title_en = EXCLUDED.title_en,
  discount_percent = EXCLUDED.discount_percent,
  start_date = EXCLUDED.start_date,
  end_date = EXCLUDED.end_date,
  product_names_ar = EXCLUDED.product_names_ar,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();

-- Strip non-UI keys from existing rows
UPDATE public.app_state
SET state = (
  SELECT COALESCE(jsonb_object_agg(key, value), '{}'::JSONB)
  FROM jsonb_each(state) AS e(key, value)
  WHERE key IN (
    'darkMode', 'inAppAlertsEnabled', 'notificationsEnabled',
    'lastMainTab', 'homeCategoryFilter', 'catalogSearchHistory',
    'drafts', 'syncHints', 'skippedCustomerSetup', 'driverType',
    'taxiFavoritePlaces', 'adminRole', 'admin_role', 'lang',
    'accountSuspended', 'suspendedAt'
  )
),
updated_at = NOW()
WHERE state <> '{}'::jsonb;
