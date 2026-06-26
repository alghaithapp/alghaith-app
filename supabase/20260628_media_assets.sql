-- Media assets registry (R2 URLs per variant).

CREATE TABLE IF NOT EXISTS public.media_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_type text NOT NULL,
  owner_id text NOT NULL,
  role text NOT NULL DEFAULT 'gallery',
  variant text NOT NULL DEFAULT 'original',
  url text NOT NULL,
  width integer,
  height integer,
  bytes integer,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT media_assets_owner_variant_key UNIQUE (owner_type, owner_id, role, variant)
);

CREATE INDEX IF NOT EXISTS idx_media_assets_owner
  ON public.media_assets (owner_type, owner_id);

DROP TRIGGER IF EXISTS trg_media_assets_updated_at ON public.media_assets;
CREATE TRIGGER trg_media_assets_updated_at
BEFORE UPDATE ON public.media_assets
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
