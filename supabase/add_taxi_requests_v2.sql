-- Taxi requests v2 - إضافة أعمدة جديدة لجدول طلبات التكسي
-- توفر هذه الأعمدة حقولاً منفصلة للبيانات الأساسية للتوسع المستقبلي
-- مع بقاء request_payload كـ JSONB للمرونة

-- إضافة الأعمدة الجديدة (إن لم تكن موجودة)
ALTER TABLE public.taxi_requests ADD COLUMN IF NOT EXISTS pickup_lat double precision;
ALTER TABLE public.taxi_requests ADD COLUMN IF NOT EXISTS pickup_lng double precision;
ALTER TABLE public.taxi_requests ADD COLUMN IF NOT EXISTS dropoff_lat double precision;
ALTER TABLE public.taxi_requests ADD COLUMN IF NOT EXISTS dropoff_lng double precision;
ALTER TABLE public.taxi_requests ADD COLUMN IF NOT EXISTS distance_km double precision;
ALTER TABLE public.taxi_requests ADD COLUMN IF NOT EXISTS taxi_type text;
ALTER TABLE public.taxi_requests ADD COLUMN IF NOT EXISTS fare_economic integer;
ALTER TABLE public.taxi_requests ADD COLUMN IF NOT EXISTS fare_super integer;
ALTER TABLE public.taxi_requests ADD COLUMN IF NOT EXISTS fare integer;
ALTER TABLE public.taxi_requests ADD COLUMN IF NOT EXISTS driver_rating integer;
ALTER TABLE public.taxi_requests ADD COLUMN IF NOT EXISTS cash_collected boolean default false;
ALTER TABLE public.taxi_requests ADD COLUMN IF NOT EXISTS accepted_at timestamptz;
ALTER TABLE public.taxi_requests ADD COLUMN IF NOT EXISTS completed_at timestamptz;
ALTER TABLE public.taxi_requests ADD COLUMN IF NOT EXISTS cancellation_reason text;
ALTER TABLE public.taxi_requests ADD COLUMN IF NOT EXISTS is_paid boolean default false;
ALTER TABLE public.taxi_requests ADD COLUMN IF NOT EXISTS driver_name text;
ALTER TABLE public.taxi_requests ADD COLUMN IF NOT EXISTS vehicle_info text;

-- إنشاء فهارس للأعمدة الجديدة
CREATE INDEX IF NOT EXISTS idx_taxi_requests_taxi_type ON public.taxi_requests (taxi_type);
CREATE INDEX IF NOT EXISTS idx_taxi_requests_fare ON public.taxi_requests (fare);
CREATE INDEX IF NOT EXISTS idx_taxi_requests_completed_at ON public.taxi_requests (completed_at);
