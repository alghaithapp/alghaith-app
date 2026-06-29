-- Admin notification inbox for real-time alerts in the admin dashboard.

CREATE TABLE IF NOT EXISTS public.admin_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type text NOT NULL DEFAULT 'info',
  title text NOT NULL,
  body text NOT NULL DEFAULT '',
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_notifications_unread
  ON public.admin_notifications (is_read, created_at DESC);

-- Trigger function: insert notification when a new merchant signs up
CREATE OR REPLACE FUNCTION public.notify_admin_new_merchant()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.admin_notifications (type, title, body, data)
  VALUES (
    'new_merchant',
    'تاجر جديد',
    'تاجر جديد سجل في المنصة: ' || COALESCE(NEW.name, NEW.store_name, 'غير معروف'),
    jsonb_build_object('phone', NEW.phone, 'merchantPhone', NEW.phone)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger function: insert notification when a new driver signs up
CREATE OR REPLACE FUNCTION public.notify_admin_new_driver()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.admin_notifications (type, title, body, data)
  VALUES (
    'new_driver',
    'سائق جديد',
    'سائق جديد سجل في المنصة: ' || COALESCE(NEW.name, 'غير معروف'),
    jsonb_build_object('phone', NEW.phone, 'driverPhone', NEW.phone)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger function: insert notification when a new courier signs up
CREATE OR REPLACE FUNCTION public.notify_admin_new_courier()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.admin_notifications (type, title, body, data)
  VALUES (
    'new_courier',
    'مندوب جديد',
    'مندوب توصيل جديد سجل في المنصة: ' || COALESCE(NEW.name, 'غير معروف'),
    jsonb_build_object('phone', NEW.phone, 'courierPhone', NEW.phone)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers on profile tables
DROP TRIGGER IF EXISTS trg_admin_notify_merchant_insert ON public.merchant_profiles;
CREATE TRIGGER trg_admin_notify_merchant_insert
AFTER INSERT ON public.merchant_profiles
FOR EACH ROW EXECUTE FUNCTION public.notify_admin_new_merchant();

DROP TRIGGER IF EXISTS trg_admin_notify_driver_insert ON public.driver_profiles;
CREATE TRIGGER trg_admin_notify_driver_insert
AFTER INSERT ON public.driver_profiles
FOR EACH ROW EXECUTE FUNCTION public.notify_admin_new_driver();

DROP TRIGGER IF EXISTS trg_admin_notify_courier_insert ON public.courier_profiles;
CREATE TRIGGER trg_admin_notify_courier_insert
AFTER INSERT ON public.courier_profiles
FOR EACH ROW EXECUTE FUNCTION public.notify_admin_new_courier();
