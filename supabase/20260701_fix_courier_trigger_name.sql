-- Fix notify_admin_new_courier trigger: use display_name instead of name
-- courier_profiles has display_name column, not name
CREATE OR REPLACE FUNCTION public.notify_admin_new_courier()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.admin_notifications (type, title, body, data)
  VALUES (
    'new_courier',
    'مندوب جديد',
    'مندوب توصيل جديد سجل في المنصة: ' || COALESCE(NEW.display_name, 'غير معروف'),
    jsonb_build_object('phone', NEW.phone, 'courierPhone', NEW.phone)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix notify_admin_new_driver trigger: use display_name instead of name
-- driver_profiles has display_name column, not name
DROP TRIGGER IF EXISTS trg_admin_notify_driver_insert ON driver_profiles;
DROP FUNCTION IF EXISTS public.notify_admin_new_driver();
CREATE FUNCTION public.notify_admin_new_driver()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.admin_notifications (type, title, body, data)
  VALUES (
    'new_driver',
    'سائق جديد',
    'سائق جديد سجل في المنصة: ' || COALESCE(NEW.display_name, 'غير معروف'),
    jsonb_build_object('phone', NEW.phone, 'driverPhone', NEW.phone)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE TRIGGER trg_admin_notify_driver_insert
  AFTER INSERT ON driver_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_admin_new_driver();

-- Fix notify_admin_new_merchant trigger: use COALESCE with store_name and display_name
DROP TRIGGER IF EXISTS trg_admin_notify_merchant_insert ON merchant_profiles;
DROP FUNCTION IF EXISTS public.notify_admin_new_merchant();
CREATE FUNCTION public.notify_admin_new_merchant()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.admin_notifications (type, title, body, data)
  VALUES (
    'new_merchant',
    'تاجر جديد',
    'تاجر جديد سجل في المنصة: ' || COALESCE(NEW.store_name, 'غير معروف'),
    jsonb_build_object('phone', NEW.phone, 'merchantPhone', NEW.phone)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE TRIGGER trg_admin_notify_merchant_insert
  AFTER INSERT ON merchant_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_admin_new_merchant();

-- Fix notify_admin_new_courier trigger: use display_name instead of name
DROP TRIGGER IF EXISTS trg_admin_notify_courier_insert ON courier_profiles;
DROP FUNCTION IF EXISTS public.notify_admin_new_courier();
CREATE FUNCTION public.notify_admin_new_courier()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.admin_notifications (type, title, body, data)
  VALUES (
    'new_courier',
    'مندوب جديد',
    'مندوب توصيل جديد سجل في المنصة: ' || COALESCE(NEW.display_name, 'غير معروف'),
    jsonb_build_object('phone', NEW.phone, 'courierPhone', NEW.phone)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE TRIGGER trg_admin_notify_courier_insert
  AFTER INSERT ON courier_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_admin_new_courier();
