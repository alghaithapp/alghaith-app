-- =============================================================================
-- Atomic procedures for multi-table writes
-- Each function wraps related table updates in a single transaction
-- Prevents data inconsistency if one write fails
-- =============================================================================

-- 1. Atomic merchant approval (merchant_profiles + app_state.merchantStore)
CREATE OR REPLACE FUNCTION atomic_approve_merchant(p_phone TEXT, p_approved BOOLEAN)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_state JSONB;
  v_store JSONB;
  v_status TEXT;
BEGIN
  v_status := CASE WHEN p_approved THEN 'approved' ELSE 'pending' END;

  UPDATE merchant_profiles
  SET is_approved = p_approved,
      approval_status = v_status,
      rejection_reason_key = NULL,
      rejection_message_ar = NULL,
      rejected_at = NULL,
      updated_at = NOW()
  WHERE phone = p_phone;

  v_state := COALESCE((SELECT state FROM app_state WHERE phone = p_phone), '{}'::JSONB);
  v_store := COALESCE(v_state->'merchantStore', '{}'::JSONB);
  v_store := jsonb_set(v_store, '{isApproved}', to_jsonb(p_approved));
  v_store := jsonb_set(v_store, '{is_approved}', to_jsonb(p_approved));
  v_store := jsonb_set(v_store, '{approvalStatus}', to_jsonb(v_status));
  v_store := jsonb_set(v_store, '{approval_status}', to_jsonb(v_status));
  v_store := jsonb_set(v_store, '{rejectionReasonKey}', 'null'::JSONB);
  v_store := jsonb_set(v_store, '{rejection_reason_key}', 'null'::JSONB);
  v_store := jsonb_set(v_store, '{rejectionMessageAr}', 'null'::JSONB);
  v_store := jsonb_set(v_store, '{rejection_message_ar}', 'null'::JSONB);
  v_store := jsonb_set(v_store, '{rejectedAt}', 'null'::JSONB);
  v_store := jsonb_set(v_store, '{rejected_at}', 'null'::JSONB);
  v_state := jsonb_set(v_state, '{merchantStore}', v_store);

  INSERT INTO app_state (phone, state, updated_at)
  VALUES (p_phone, v_state, NOW())
  ON CONFLICT (phone)
  DO UPDATE SET state = v_state, updated_at = NOW();

  RETURN jsonb_build_object('success', true, 'phone', p_phone, 'approved', p_approved);
END;
$$;

-- 2. Atomic merchant rejection (merchant_profiles + app_state.merchantStore)
CREATE OR REPLACE FUNCTION atomic_reject_merchant(p_phone TEXT, p_reason_key TEXT, p_message_ar TEXT)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_state JSONB;
  v_store JSONB;
BEGIN
  UPDATE merchant_profiles
  SET is_approved = false,
      approval_status = 'rejected',
      rejection_reason_key = p_reason_key,
      rejection_message_ar = p_message_ar,
      rejected_at = NOW(),
      updated_at = NOW()
  WHERE phone = p_phone;

  v_state := COALESCE((SELECT state FROM app_state WHERE phone = p_phone), '{}'::JSONB);
  v_store := COALESCE(v_state->'merchantStore', '{}'::JSONB);
  v_store := jsonb_set(v_store, '{isApproved}', 'false'::JSONB);
  v_store := jsonb_set(v_store, '{is_approved}', 'false'::JSONB);
  v_store := jsonb_set(v_store, '{approvalStatus}', '"rejected"'::JSONB);
  v_store := jsonb_set(v_store, '{approval_status}', '"rejected"'::JSONB);
  v_store := jsonb_set(v_store, '{rejectionReasonKey}', to_jsonb(p_reason_key));
  v_store := jsonb_set(v_store, '{rejection_reason_key}', to_jsonb(p_reason_key));
  v_store := jsonb_set(v_store, '{rejectionMessageAr}', to_jsonb(p_message_ar));
  v_store := jsonb_set(v_store, '{rejection_message_ar}', to_jsonb(p_message_ar));
  v_store := jsonb_set(v_store, '{rejectedAt}', to_jsonb(NOW()));
  v_store := jsonb_set(v_store, '{rejected_at}', to_jsonb(NOW()));
  v_state := jsonb_set(v_state, '{merchantStore}', v_store);

  INSERT INTO app_state (phone, state, updated_at)
  VALUES (p_phone, v_state, NOW())
  ON CONFLICT (phone)
  DO UPDATE SET state = v_state, updated_at = NOW();

  RETURN jsonb_build_object('success', true, 'phone', p_phone);
END;
$$;

-- 3. Atomic freeze toggle (merchant_profiles + app_state.merchantStore)
CREATE OR REPLACE FUNCTION atomic_toggle_frozen(p_phone TEXT, p_is_frozen BOOLEAN)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_state JSONB;
  v_store JSONB;
BEGIN
  UPDATE merchant_profiles
  SET is_frozen = p_is_frozen,
      updated_at = NOW()
  WHERE phone = p_phone;

  v_state := COALESCE((SELECT state FROM app_state WHERE phone = p_phone), '{}'::JSONB);
  v_store := COALESCE(v_state->'merchantStore', '{}'::JSONB);
  v_store := jsonb_set(v_store, '{isFrozen}', to_jsonb(p_is_frozen));
  v_store := jsonb_set(v_store, '{is_frozen}', to_jsonb(p_is_frozen));
  v_state := jsonb_set(v_state, '{merchantStore}', v_store);

  INSERT INTO app_state (phone, state, updated_at)
  VALUES (p_phone, v_state, NOW())
  ON CONFLICT (phone)
  DO UPDATE SET state = v_state, updated_at = NOW();

  RETURN jsonb_build_object('success', true, 'phone', p_phone, 'is_frozen', p_is_frozen);
END;
$$;

-- 4. Atomic courier approval (app_state.courierProfile)
CREATE OR REPLACE FUNCTION atomic_approve_courier(p_phone TEXT, p_approved BOOLEAN)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_state JSONB;
  v_profile JSONB;
  v_status TEXT;
BEGIN
  v_status := CASE WHEN p_approved THEN 'approved' ELSE 'pending' END;
  v_state := COALESCE((SELECT state FROM app_state WHERE phone = p_phone), '{}'::JSONB);
  v_profile := COALESCE(v_state->'courierProfile', '{}'::JSONB);

  v_profile := jsonb_set(v_profile, '{isApproved}', to_jsonb(p_approved));
  v_profile := jsonb_set(v_profile, '{approvalStatus}', to_jsonb(v_status));
  IF p_approved THEN
    v_profile := v_profile - 'rejectionReasonKey' - 'rejectionMessageAr' - 'rejectedAt';
  END IF;
  v_state := jsonb_set(v_state, '{courierProfile}', v_profile);

  INSERT INTO app_state (phone, state, updated_at)
  VALUES (p_phone, v_state, NOW())
  ON CONFLICT (phone)
  DO UPDATE SET state = v_state, updated_at = NOW();

  RETURN jsonb_build_object('success', true, 'phone', p_phone, 'approved', p_approved);
END;
$$;

-- 5. Atomic courier rejection (app_state.courierProfile)
CREATE OR REPLACE FUNCTION atomic_reject_courier(p_phone TEXT, p_reason_key TEXT, p_message_ar TEXT)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_state JSONB;
  v_profile JSONB;
BEGIN
  v_state := COALESCE((SELECT state FROM app_state WHERE phone = p_phone), '{}'::JSONB);
  v_profile := COALESCE(v_state->'courierProfile', '{}'::JSONB);

  v_profile := jsonb_set(v_profile, '{isApproved}', 'false'::JSONB);
  v_profile := jsonb_set(v_profile, '{approvalStatus}', '"rejected"'::JSONB);
  v_profile := jsonb_set(v_profile, '{rejectionReasonKey}', to_jsonb(p_reason_key));
  v_profile := jsonb_set(v_profile, '{rejectionMessageAr}', to_jsonb(p_message_ar));
  v_profile := jsonb_set(v_profile, '{rejectedAt}', to_jsonb(NOW()));
  v_state := jsonb_set(v_state, '{courierProfile}', v_profile);

  INSERT INTO app_state (phone, state, updated_at)
  VALUES (p_phone, v_state, NOW())
  ON CONFLICT (phone)
  DO UPDATE SET state = v_state, updated_at = NOW();

  RETURN jsonb_build_object('success', true, 'phone', p_phone);
END;
$$;

-- 6. Atomic driver approval (app_state.driverProfile)
CREATE OR REPLACE FUNCTION atomic_approve_driver(p_phone TEXT, p_approved BOOLEAN)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_state JSONB;
  v_profile JSONB;
  v_status TEXT;
BEGIN
  v_status := CASE WHEN p_approved THEN 'approved' ELSE 'pending' END;
  v_state := COALESCE((SELECT state FROM app_state WHERE phone = p_phone), '{}'::JSONB);
  v_profile := COALESCE(v_state->'driverProfile', '{}'::JSONB);

  v_profile := jsonb_set(v_profile, '{isApproved}', to_jsonb(p_approved));
  v_profile := jsonb_set(v_profile, '{approvalStatus}', to_jsonb(v_status));
  IF p_approved THEN
    v_profile := v_profile - 'rejectionReasonKey' - 'rejectionMessageAr' - 'rejectedAt';
  END IF;
  v_state := jsonb_set(v_state, '{driverProfile}', v_profile);

  INSERT INTO app_state (phone, state, updated_at)
  VALUES (p_phone, v_state, NOW())
  ON CONFLICT (phone)
  DO UPDATE SET state = v_state, updated_at = NOW();

  RETURN jsonb_build_object('success', true, 'phone', p_phone, 'approved', p_approved);
END;
$$;

-- 7. Atomic driver rejection (app_state.driverProfile)
CREATE OR REPLACE FUNCTION atomic_reject_driver(p_phone TEXT, p_reason_key TEXT, p_message_ar TEXT)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_state JSONB;
  v_profile JSONB;
BEGIN
  v_state := COALESCE((SELECT state FROM app_state WHERE phone = p_phone), '{}'::JSONB);
  v_profile := COALESCE(v_state->'driverProfile', '{}'::JSONB);

  v_profile := jsonb_set(v_profile, '{isApproved}', 'false'::JSONB);
  v_profile := jsonb_set(v_profile, '{approvalStatus}', '"rejected"'::JSONB);
  v_profile := jsonb_set(v_profile, '{rejectionReasonKey}', to_jsonb(p_reason_key));
  v_profile := jsonb_set(v_profile, '{rejectionMessageAr}', to_jsonb(p_message_ar));
  v_profile := jsonb_set(v_profile, '{rejectedAt}', to_jsonb(NOW()));
  v_state := jsonb_set(v_state, '{driverProfile}', v_profile);

  INSERT INTO app_state (phone, state, updated_at)
  VALUES (p_phone, v_state, NOW())
  ON CONFLICT (phone)
  DO UPDATE SET state = v_state, updated_at = NOW();

  RETURN jsonb_build_object('success', true, 'phone', p_phone);
END;
$$;

-- 8. Atomic role update (app_users + app_state)
CREATE OR REPLACE FUNCTION atomic_update_account_role(p_phone TEXT, p_role TEXT)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_state JSONB;
BEGIN
  UPDATE app_users
  SET role = p_role,
      account_type = p_role,
      updated_at = NOW()
  WHERE phone = p_phone;

  v_state := COALESCE((SELECT state FROM app_state WHERE phone = p_phone), '{}'::JSONB);
  v_state := jsonb_set(v_state, '{userRole}', to_jsonb(p_role));
  v_state := jsonb_set(v_state, '{user_role}', to_jsonb(p_role));

  INSERT INTO app_state (phone, state, updated_at)
  VALUES (p_phone, v_state, NOW())
  ON CONFLICT (phone)
  DO UPDATE SET state = v_state, updated_at = NOW();

  RETURN jsonb_build_object('success', true, 'phone', p_phone, 'role', p_role);
END;
$$;

-- 9. Atomic account suspension (app_state + merchant_profiles)
CREATE OR REPLACE FUNCTION atomic_suspend_account(p_phone TEXT, p_is_suspended BOOLEAN)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_state JSONB;
  v_profile JSONB;
BEGIN
  UPDATE merchant_profiles
  SET is_frozen = p_is_suspended,
      updated_at = NOW()
  WHERE phone = p_phone;

  v_state := COALESCE((SELECT state FROM app_state WHERE phone = p_phone), '{}'::JSONB);
  v_state := jsonb_set(v_state, '{accountSuspended}', to_jsonb(p_is_suspended));
  IF p_is_suspended THEN
    v_state := jsonb_set(v_state, '{suspendedAt}', to_jsonb(NOW()));
  ELSE
    v_state := jsonb_set(v_state, '{suspendedAt}', 'null'::JSONB);
  END IF;

  IF v_state ? 'courierProfile' THEN
    v_profile := v_state->'courierProfile';
    IF v_profile ? 'name' THEN
      v_profile := jsonb_set(v_profile, '{isSuspended}', to_jsonb(p_is_suspended));
      v_profile := jsonb_set(v_profile, '{available}', to_jsonb(NOT p_is_suspended));
      v_state := jsonb_set(v_state, '{courierProfile}', v_profile);
    END IF;
  END IF;

  IF v_state ? 'driverProfile' THEN
    v_profile := v_state->'driverProfile';
    IF v_profile ? 'name' THEN
      v_profile := jsonb_set(v_profile, '{isSuspended}', to_jsonb(p_is_suspended));
      v_profile := jsonb_set(v_profile, '{available}', to_jsonb(NOT p_is_suspended));
      v_state := jsonb_set(v_state, '{driverProfile}', v_profile);
    END IF;
  END IF;

  INSERT INTO app_state (phone, state, updated_at)
  VALUES (p_phone, v_state, NOW())
  ON CONFLICT (phone)
  DO UPDATE SET state = v_state, updated_at = NOW();

  RETURN jsonb_build_object('success', true, 'phone', p_phone, 'is_suspended', p_is_suspended);
END;
$$;

-- 10. Atomic driver online status (app_state.driverProfile + taxi_driver_status)
CREATE OR REPLACE FUNCTION atomic_set_driver_online(p_phone TEXT, p_is_online BOOLEAN)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_state JSONB;
  v_profile JSONB;
BEGIN
  v_state := COALESCE((SELECT state FROM app_state WHERE phone = p_phone), '{}'::JSONB);
  v_profile := COALESCE(v_state->'driverProfile', '{}'::JSONB);
  v_profile := jsonb_set(v_profile, '{available}', to_jsonb(p_is_online));
  v_profile := jsonb_set(v_profile, '{updatedAt}', to_jsonb(NOW()));
  v_state := jsonb_set(v_state, '{driverProfile}', v_profile);

  INSERT INTO app_state (phone, state, updated_at)
  VALUES (p_phone, v_state, NOW())
  ON CONFLICT (phone)
  DO UPDATE SET state = v_state, updated_at = NOW();

  INSERT INTO taxi_driver_status (phone, is_online, updated_at)
  VALUES (p_phone, p_is_online, NOW())
  ON CONFLICT (phone)
  DO UPDATE SET is_online = p_is_online, updated_at = NOW();

  RETURN jsonb_build_object('success', true, 'phone', p_phone, 'is_online', p_is_online);
END;
$$;
