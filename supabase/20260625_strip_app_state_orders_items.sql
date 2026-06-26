-- Phase 1: orders/items must live in customer_orders + merchant_products, not app_state.

CREATE OR REPLACE FUNCTION merge_app_state(p_phone TEXT, p_state JSONB)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_incoming JSONB;
  v_merged JSONB;
BEGIN
  v_incoming := COALESCE(p_state, '{}'::JSONB) - 'orders' - 'items';

  INSERT INTO app_state (phone, state, updated_at)
  VALUES (p_phone, v_incoming, NOW())
  ON CONFLICT (phone)
  DO UPDATE SET
    state = CASE
      WHEN p_state IS NULL THEN EXCLUDED.state
      ELSE (COALESCE(app_state.state, '{}'::JSONB) || v_incoming) - 'orders' - 'items'
    END,
    updated_at = NOW();

  RETURN (SELECT state FROM app_state WHERE phone = p_phone);
END;
$$;

-- One-time cleanup of legacy blobs
UPDATE public.app_state
SET state = state - 'orders' - 'items',
    updated_at = NOW()
WHERE state ? 'orders' OR state ? 'items';
