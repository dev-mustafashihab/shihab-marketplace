-- Phase 7: Search + Nearby (PostGIS)

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE "vendors" ADD COLUMN IF NOT EXISTS "location" geography(Point,4326);

-- مزامنة location من lat/lng (المصدر الحقيقة)
CREATE OR REPLACE FUNCTION vendors_set_location() RETURNS trigger AS $$
BEGIN
  IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
    NEW.location := ST_SetSRID(ST_MakePoint(NEW.longitude::float8, NEW.latitude::float8), 4326)::geography;
  ELSE
    NEW.location := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS vendors_set_location_trigger ON "vendors";
CREATE TRIGGER vendors_set_location_trigger
BEFORE INSERT OR UPDATE OF latitude, longitude ON "vendors"
FOR EACH ROW EXECUTE FUNCTION vendors_set_location();

-- تحديث الصفوف الموجودة
UPDATE "vendors" SET latitude = latitude WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

CREATE INDEX IF NOT EXISTS "vendors_location_gix" ON "vendors" USING gist("location");
