-- Fix ON CONFLICT (phone) for merchant_profiles upserts in admin sync.
-- Safe for tables where phone is PRIMARY KEY (no id column).
-- Run once in Supabase → SQL Editor.

-- 1) Remove duplicate phones if any (uses ctid — no id column required).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'merchant_profiles'
      AND column_name = 'updated_at'
  ) THEN
    DELETE FROM public.merchant_profiles
    WHERE ctid IN (
      SELECT ctid
      FROM (
        SELECT
          ctid,
          ROW_NUMBER() OVER (
            PARTITION BY phone
            ORDER BY updated_at DESC NULLS LAST
          ) AS rn
        FROM public.merchant_profiles
      ) ranked
      WHERE ranked.rn > 1
    );
  ELSE
    DELETE FROM public.merchant_profiles a
    USING public.merchant_profiles b
    WHERE a.phone = b.phone
      AND a.ctid < b.ctid;
  END IF;
END $$;

-- 2) Add UNIQUE(phone) only if phone is not already PRIMARY KEY or UNIQUE.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.merchant_profiles'::regclass
      AND contype = 'p'
      AND pg_get_constraintdef(oid) ILIKE '%(phone)%'
  ) THEN
    RAISE NOTICE 'merchant_profiles.phone is already PRIMARY KEY — nothing to add.';
    RETURN;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.merchant_profiles'::regclass
      AND contype = 'u'
      AND pg_get_constraintdef(oid) ILIKE '%(phone)%'
  ) THEN
    ALTER TABLE public.merchant_profiles
      ADD CONSTRAINT merchant_profiles_phone_key UNIQUE (phone);
    RAISE NOTICE 'Added UNIQUE constraint on merchant_profiles.phone';
  ELSE
    RAISE NOTICE 'UNIQUE constraint on merchant_profiles.phone already exists.';
  END IF;
END $$;
