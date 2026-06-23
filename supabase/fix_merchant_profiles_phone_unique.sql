-- Fix ON CONFLICT (phone) for merchant_profiles upserts in admin sync.
-- Run once in Supabase → SQL Editor.

-- Keep the newest row per phone if duplicates exist.
DELETE FROM public.merchant_profiles mp
WHERE mp.id IN (
  SELECT id
  FROM (
    SELECT
      id,
      ROW_NUMBER() OVER (
        PARTITION BY phone
        ORDER BY updated_at DESC NULLS LAST, created_at DESC NULLS LAST
      ) AS rn
    FROM public.merchant_profiles
  ) ranked
  WHERE ranked.rn > 1
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.merchant_profiles'::regclass
      AND contype = 'u'
      AND pg_get_constraintdef(oid) ILIKE '%(phone)%'
  ) THEN
    ALTER TABLE public.merchant_profiles
      ADD CONSTRAINT merchant_profiles_phone_key UNIQUE (phone);
  END IF;
END $$;
