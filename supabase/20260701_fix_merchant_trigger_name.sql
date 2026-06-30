-- Fix trigger functions that reference NEW.name (column does not exist on merchant_profiles)
-- merchant_profiles has store_name, not name

CREATE OR REPLACE FUNCTION public.notify_admin_new_merchant()
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
