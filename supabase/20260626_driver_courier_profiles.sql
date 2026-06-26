-- Phase 2: driver/courier profiles in dedicated tables; strip from app_state.

CREATE TABLE IF NOT EXISTS public.driver_profiles (
  phone text PRIMARY KEY REFERENCES public.app_users(phone) ON DELETE CASCADE,
  display_name text,
  driver_type text NOT NULL DEFAULT 'taxi',
  approval_status text NOT NULL DEFAULT 'pending',
  is_approved boolean NOT NULL DEFAULT false,
  available boolean NOT NULL DEFAULT true,
  is_suspended boolean NOT NULL DEFAULT false,
  latitude double precision,
  longitude double precision,
  profile_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.courier_profiles (
  phone text PRIMARY KEY REFERENCES public.app_users(phone) ON DELETE CASCADE,
  display_name text,
  approval_status text NOT NULL DEFAULT 'pending',
  is_approved boolean NOT NULL DEFAULT false,
  available boolean NOT NULL DEFAULT true,
  is_suspended boolean NOT NULL DEFAULT false,
  profile_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_driver_profiles_approval
  ON public.driver_profiles (approval_status, is_approved);
CREATE INDEX IF NOT EXISTS idx_courier_profiles_approval
  ON public.courier_profiles (approval_status, is_approved);

DROP TRIGGER IF EXISTS trg_driver_profiles_updated_at ON public.driver_profiles;
CREATE TRIGGER trg_driver_profiles_updated_at
BEFORE UPDATE ON public.driver_profiles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_courier_profiles_updated_at ON public.courier_profiles;
CREATE TRIGGER trg_courier_profiles_updated_at
BEFORE UPDATE ON public.courier_profiles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Extend merge_app_state (Phase 1 + Phase 2 keys)
CREATE OR REPLACE FUNCTION merge_app_state(p_phone TEXT, p_state JSONB)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_incoming JSONB;
BEGIN
  v_incoming := COALESCE(p_state, '{}'::JSONB)
    - 'orders' - 'items' - 'merchantStore' - 'driverProfile' - 'courierProfile';

  INSERT INTO app_state (phone, state, updated_at)
  VALUES (p_phone, v_incoming, NOW())
  ON CONFLICT (phone)
  DO UPDATE SET
    state = CASE
      WHEN p_state IS NULL THEN EXCLUDED.state
      ELSE (COALESCE(app_state.state, '{}'::JSONB) || v_incoming)
        - 'orders' - 'items' - 'merchantStore' - 'driverProfile' - 'courierProfile'
    END,
    updated_at = NOW();

  RETURN (SELECT state FROM app_state WHERE phone = p_phone);
END;
$$;

-- Atomic courier approval (courier_profiles)
CREATE OR REPLACE FUNCTION atomic_approve_courier(p_phone TEXT, p_approved BOOLEAN)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_status TEXT;
  v_profile JSONB;
BEGIN
  v_status := CASE WHEN p_approved THEN 'approved' ELSE 'pending' END;
  v_profile := COALESCE(
    (SELECT profile_payload FROM courier_profiles WHERE phone = p_phone),
    '{}'::JSONB
  );
  v_profile := jsonb_set(v_profile, '{isApproved}', to_jsonb(p_approved));
  v_profile := jsonb_set(v_profile, '{approvalStatus}', to_jsonb(v_status));
  IF p_approved THEN
    v_profile := v_profile - 'rejectionReasonKey' - 'rejectionMessageAr' - 'rejectedAt';
  END IF;

  INSERT INTO courier_profiles (
    phone, approval_status, is_approved, profile_payload, updated_at
  )
  VALUES (
    p_phone, v_status, p_approved, v_profile, NOW()
  )
  ON CONFLICT (phone)
  DO UPDATE SET
    approval_status = v_status,
    is_approved = p_approved,
    profile_payload = v_profile,
    updated_at = NOW();

  RETURN jsonb_build_object('success', true, 'phone', p_phone, 'approved', p_approved);
END;
$$;

CREATE OR REPLACE FUNCTION atomic_reject_courier(
  p_phone TEXT, p_reason_key TEXT, p_message_ar TEXT
)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_profile JSONB;
BEGIN
  v_profile := COALESCE(
    (SELECT profile_payload FROM courier_profiles WHERE phone = p_phone),
    '{}'::JSONB
  );
  v_profile := jsonb_set(v_profile, '{isApproved}', 'false'::JSONB);
  v_profile := jsonb_set(v_profile, '{approvalStatus}', '"rejected"'::JSONB);
  v_profile := jsonb_set(v_profile, '{rejectionReasonKey}', to_jsonb(p_reason_key));
  v_profile := jsonb_set(v_profile, '{rejectionMessageAr}', to_jsonb(p_message_ar));
  v_profile := jsonb_set(v_profile, '{rejectedAt}', to_jsonb(NOW()));

  INSERT INTO courier_profiles (
    phone, approval_status, is_approved, profile_payload, updated_at
  )
  VALUES (
    p_phone, 'rejected', false, v_profile, NOW()
  )
  ON CONFLICT (phone)
  DO UPDATE SET
    approval_status = 'rejected',
    is_approved = false,
    profile_payload = v_profile,
    updated_at = NOW();

  RETURN jsonb_build_object('success', true, 'phone', p_phone);
END;
$$;

CREATE OR REPLACE FUNCTION atomic_approve_driver(p_phone TEXT, p_approved BOOLEAN)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_status TEXT;
  v_profile JSONB;
BEGIN
  v_status := CASE WHEN p_approved THEN 'approved' ELSE 'pending' END;
  v_profile := COALESCE(
    (SELECT profile_payload FROM driver_profiles WHERE phone = p_phone),
    '{}'::JSONB
  );
  v_profile := jsonb_set(v_profile, '{isApproved}', to_jsonb(p_approved));
  v_profile := jsonb_set(v_profile, '{approvalStatus}', to_jsonb(v_status));
  IF p_approved THEN
    v_profile := v_profile - 'rejectionReasonKey' - 'rejectionMessageAr' - 'rejectedAt';
  END IF;

  INSERT INTO driver_profiles (
    phone, approval_status, is_approved, profile_payload, updated_at
  )
  VALUES (
    p_phone, v_status, p_approved, v_profile, NOW()
  )
  ON CONFLICT (phone)
  DO UPDATE SET
    approval_status = v_status,
    is_approved = p_approved,
    profile_payload = v_profile,
    updated_at = NOW();

  RETURN jsonb_build_object('success', true, 'phone', p_phone, 'approved', p_approved);
END;
$$;

CREATE OR REPLACE FUNCTION atomic_reject_driver(
  p_phone TEXT, p_reason_key TEXT, p_message_ar TEXT
)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_profile JSONB;
BEGIN
  v_profile := COALESCE(
    (SELECT profile_payload FROM driver_profiles WHERE phone = p_phone),
    '{}'::JSONB
  );
  v_profile := jsonb_set(v_profile, '{isApproved}', 'false'::JSONB);
  v_profile := jsonb_set(v_profile, '{approvalStatus}', '"rejected"'::JSONB);
  v_profile := jsonb_set(v_profile, '{rejectionReasonKey}', to_jsonb(p_reason_key));
  v_profile := jsonb_set(v_profile, '{rejectionMessageAr}', to_jsonb(p_message_ar));
  v_profile := jsonb_set(v_profile, '{rejectedAt}', to_jsonb(NOW()));

  INSERT INTO driver_profiles (
    phone, approval_status, is_approved, profile_payload, updated_at
  )
  VALUES (
    p_phone, 'rejected', false, v_profile, NOW()
  )
  ON CONFLICT (phone)
  DO UPDATE SET
    approval_status = 'rejected',
    is_approved = false,
    profile_payload = v_profile,
    updated_at = NOW();

  RETURN jsonb_build_object('success', true, 'phone', p_phone);
END;
$$;

CREATE OR REPLACE FUNCTION atomic_set_driver_online(p_phone TEXT, p_is_online BOOLEAN)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_profile JSONB;
BEGIN
  v_profile := COALESCE(
    (SELECT profile_payload FROM driver_profiles WHERE phone = p_phone),
    '{}'::JSONB
  );
  v_profile := jsonb_set(v_profile, '{available}', to_jsonb(p_is_online));
  v_profile := jsonb_set(v_profile, '{updatedAt}', to_jsonb(NOW()));

  INSERT INTO driver_profiles (
    phone, available, profile_payload, updated_at
  )
  VALUES (
    p_phone, p_is_online, v_profile, NOW()
  )
  ON CONFLICT (phone)
  DO UPDATE SET
    available = p_is_online,
    profile_payload = v_profile,
    updated_at = NOW();

  INSERT INTO taxi_driver_status (phone, is_online, updated_at)
  VALUES (p_phone, p_is_online, NOW())
  ON CONFLICT (phone)
  DO UPDATE SET is_online = p_is_online, updated_at = NOW();

  RETURN jsonb_build_object('success', true, 'phone', p_phone, 'is_online', p_is_online);
END;
$$;

-- One-time cleanup of legacy blobs
UPDATE public.app_state
SET state = state - 'merchantStore' - 'driverProfile' - 'courierProfile',
    updated_at = NOW()
WHERE state ? 'merchantStore' OR state ? 'driverProfile' OR state ? 'courierProfile';
