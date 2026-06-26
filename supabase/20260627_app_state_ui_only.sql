-- Phase 3: app_state UI-only + admin_roles + merchant_offers tables.
-- Prerequisite: 20260624 + 20260625 + 20260626 applied (or merge_app_state already updated).

CREATE TABLE IF NOT EXISTS public.admin_roles (
  phone text PRIMARY KEY REFERENCES public.app_users(phone) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'admin',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.merchant_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone text NOT NULL REFERENCES public.app_users(phone) ON DELETE CASCADE,
  title_ar text NOT NULL DEFAULT '',
  title_en text NOT NULL DEFAULT '',
  discount_percent integer NOT NULL DEFAULT 0,
  start_date date,
  end_date date,
  product_names_ar jsonb NOT NULL DEFAULT '[]'::jsonb,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Legacy tables may exist with different column names — normalize before indexes/migration.
DO $$
BEGIN
  IF to_regclass('public.admin_roles') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'admin_roles' AND column_name = 'phone'
    ) THEN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'admin_roles' AND column_name = 'user_phone'
      ) THEN
        ALTER TABLE public.admin_roles RENAME COLUMN user_phone TO phone;
      ELSIF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'admin_roles' AND column_name = 'admin_phone'
      ) THEN
        ALTER TABLE public.admin_roles RENAME COLUMN admin_phone TO phone;
      ELSE
        ALTER TABLE public.admin_roles ADD COLUMN phone text;
      END IF;
    END IF;
  END IF;

  IF to_regclass('public.merchant_offers') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'merchant_offers' AND column_name = 'phone'
    ) THEN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'merchant_offers' AND column_name = 'merchant_phone'
      ) THEN
        ALTER TABLE public.merchant_offers RENAME COLUMN merchant_phone TO phone;
      ELSE
        ALTER TABLE public.merchant_offers ADD COLUMN phone text;
      END IF;
    END IF;
  END IF;
END $$;

ALTER TABLE IF EXISTS public.admin_roles
  ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'admin',
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE IF EXISTS public.merchant_offers
  ADD COLUMN IF NOT EXISTS phone text,
  ADD COLUMN IF NOT EXISTS title_ar text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS title_en text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS discount_percent integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS start_date date,
  ADD COLUMN IF NOT EXISTS end_date date,
  ADD COLUMN IF NOT EXISTS product_names_ar jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_admin_roles_role ON public.admin_roles (role);

DROP TRIGGER IF EXISTS trg_admin_roles_updated_at ON public.admin_roles;
CREATE TRIGGER trg_admin_roles_updated_at
BEFORE UPDATE ON public.admin_roles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE INDEX IF NOT EXISTS idx_merchant_offers_phone
  ON public.merchant_offers (phone, is_active);

-- Ensure admin_roles.phone can be used with ON CONFLICT (legacy tables may lack PK on phone).
CREATE UNIQUE INDEX IF NOT EXISTS idx_admin_roles_phone_unique
  ON public.admin_roles (phone)
  WHERE phone IS NOT NULL;

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

-- Migrate merchantOffers (production schema: merchant_user_id + text[] product_names_ar).
-- For greenfield `phone` column schema, see legacy block in repo history / 20260627b.
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
