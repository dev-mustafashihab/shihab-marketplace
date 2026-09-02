-- Hardening P0: ledger idempotency + payout single-active + FK indexes

-- PHASE 3: منع تكرار الحدث المالي
-- تنظيف أي تكرارات تاريخية (يحتفظ بالأقدم)
DELETE FROM wallet_transactions a
USING wallet_transactions b
WHERE a.id > b.id
  AND a.type = b.type
  AND a.ref_type IS NOT DISTINCT FROM b.ref_type
  AND a.ref_id IS NOT DISTINCT FROM b.ref_id
  AND a.currency = b.currency;
CREATE UNIQUE INDEX wallet_transactions_type_reftype_refid_currency_key
  ON wallet_transactions (type, ref_type, ref_id, currency);

-- PHASE 6: دفعة نشطة واحدة لكل بائع
CREATE UNIQUE INDEX payouts_one_active_per_vendor
  ON payouts (vendor_id)
  WHERE status IN ('REQUESTED', 'APPROVED');

-- FK indexes المفقودة (Phase 14/migrations + أداء)
CREATE INDEX IF NOT EXISTS idx_order_status_history_order ON order_status_history(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_booking ON payments(booking_id);
CREATE INDEX IF NOT EXISTS idx_permissions_role ON permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_media_vendor ON media(vendor_id);
CREATE INDEX IF NOT EXISTS idx_media_owner ON media(owner_id);
CREATE INDEX IF NOT EXISTS idx_booking_items_booking ON booking_items(booking_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_cart ON cart_items(cart_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_product ON cart_items(product_id);
CREATE INDEX IF NOT EXISTS idx_favorites_vendor ON favorites(vendor_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product ON order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_reviews_vendor ON reviews(vendor_id);
CREATE INDEX IF NOT EXISTS idx_reviews_user ON reviews(customer_id);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_wallet ON wallet_transactions(wallet_id);
