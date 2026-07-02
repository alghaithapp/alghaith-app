-- Admin panel: doctor/pharmacy contact fields on merchant_profiles
ALTER TABLE IF EXISTS public.merchant_profiles
  ADD COLUMN IF NOT EXISTS doctor_phone text,
  ADD COLUMN IF NOT EXISTS clinic_phone text;

COMMENT ON COLUMN public.merchant_profiles.doctor_phone IS 'Doctor direct contact number';
COMMENT ON COLUMN public.merchant_profiles.clinic_phone IS 'Clinic or pharmacy front-desk number';
