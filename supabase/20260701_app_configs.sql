-- جدول الإعدادات الديناميكية — يُعدّل من لوحة الأدمن بدون تحديث التطبيق
CREATE TABLE IF NOT EXISTS public.app_configs (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL DEFAULT '{}',
  label TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.app_configs ENABLE ROW LEVEL SECURITY;

-- إدراج الإعدادات الافتراضية
INSERT INTO public.app_configs (key, value, label) VALUES
  ('taxi_pricing', '{
    "tuktuk": {"base": 1000, "extraKm": 250, "min": 1000},
    "wazz": {"base": 1500, "extraKm": 300, "min": 1500},
    "economic": {"base": 1500, "extraKm": 500, "min": 1500},
    "maxFare": 50000,
    "includedKm": 2.0,
    "roundingStep": 250
  }'::jsonb, 'أسعار التكسي'),
  
  ('taxi_config', '{
    "searchTimeoutSeconds": 300,
    "maxStops": 3,
    "matchingRadiusKm": 10,
    "matchingRadiusExpandKm": 25,
    "maxDriversPerNotify": 40
  }'::jsonb, 'إعدادات التكسي'),
  
  ('map_defaults', '{
    "centerLat": 32.9256,
    "centerLng": 44.7766,
    "defaultZoom": 12
  }'::jsonb, 'إعدادات الخريطة'),
  
  ('neighborhoods', '{}'::jsonb, 'الأماكن المحفوظة (الأحياء)'),
  
  ('app_theme', '{}'::jsonb, 'الألوان والثيم'),
  
  ('notification_texts', '{}'::jsonb, 'نصوص الإشعارات الداخلية'),
  
  ('home_categories', '{
    "order": ["restaurant", "cars", "product", "eden_printing", "global_shopping"],
    "categories": {
      "restaurant": {"titleAr": "المطاعم", "enabled": true},
      "cars": {"titleAr": "السيارات", "enabled": true},
      "product": {"titleAr": "التسوق", "enabled": true},
      "eden_printing": {"titleAr": "طباعة وإعلانات", "enabled": true},
      "global_shopping": {"titleAr": "التسوق من الخارج", "enabled": true}
    }
  }'::jsonb, 'الأقسام الرئيسية'),
  
  ('sub_categories', '{
    "eden_printing": [
      {"id": "printing", "titleAr": "طباعة", "titleEn": "Printing"},
      {"id": "advertising", "titleAr": "إعلانات", "titleEn": "Advertising"}
    ],
    "global_shopping": [
      {"id": "china", "titleAr": "الصين", "titleEn": "China"},
      {"id": "iran", "titleAr": "إيران", "titleEn": "Iran"}
    ],
    "professional": [],
    "beauty": [],
    "real_estate": [],
    "cars": [],
    "offers": []
  }'::jsonb, 'الفئات الفرعية')
ON CONFLICT (key) DO NOTHING;
