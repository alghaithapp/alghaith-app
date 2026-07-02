-- Optional: profile image URL column for merchant_profiles (admin pre-register uploads)
ALTER TABLE IF EXISTS public.merchant_profiles
  ADD COLUMN IF NOT EXISTS profile_image_url text;

COMMENT ON COLUMN public.merchant_profiles.profile_image_url IS 'Public URL for merchant/doctor/pharmacy profile image (R2/CDN)';
