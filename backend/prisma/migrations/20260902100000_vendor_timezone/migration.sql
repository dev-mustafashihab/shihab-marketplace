-- PHASE 10: توقيت البائع المحلي لفحص التوفر (افتراضي دمشق)
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS timezone VARCHAR(64) NOT NULL DEFAULT 'Asia/Damascus';
