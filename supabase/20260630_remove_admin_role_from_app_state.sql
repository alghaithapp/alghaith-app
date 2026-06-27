-- Remove adminRole from app_state merge allow-list (security hardening).
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
    'taxiFavoritePlaces', 'lang',
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

-- Strip legacy admin keys from existing rows.
UPDATE public.app_state
SET state = state - 'adminRole' - 'admin_role' - 'adminAccess' - 'userRole' - 'user_role',
    updated_at = NOW()
WHERE state ?| ARRAY['adminRole', 'admin_role', 'adminAccess', 'userRole', 'user_role'];
