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
CREATE OR REPLACE FUNCTION public.notify_admin_new_driver()
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

-- Fix notify_admin_new_merchant trigger: use COALESCE with store_name and display_name
CREATE OR REPLACE FUNCTION public.notify_admin_new_merchant()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.admin_notifications (type, title, body, data)
  VALUES (
    'new_merchant',
    'تاجر جديد',
    'تاجر جديد سجل في المنصة: ' || COALESCE(NEW.store_name, NEW.display_name, 'غير معروف'),
    jsonb_build_object('phone', NEW.phone, 'merchantPhone', NEW.phone)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
