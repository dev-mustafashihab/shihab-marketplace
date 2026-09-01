# DATABASE — ERD والمخطط

Phase 1 مطبَّق فعلياً (Prisma migrations). البقية مصممة هنا وستُضاف migrations لكل مرحلة.

## Phase 1 (مطبَّق)

```
users 1—1 profiles
users 1—* refresh_tokens   (token_hash unique، family_id للسلسلة، revoked_reason)
roles  1—* permissions     (permissions.role_id nullable لتصنيف الصلاحيات العامة)
users  1—* audit_logs      (actor_id nullable، action/entity/entity_id/diff jsonb)
```

Enums: `UserRole(CUSTOMER|VENDOR|ADMIN)`، `UserStatus(ACTIVE|SUSPENDED|DELETED)`.
أعمدة فيزيائية snake_case عبر `@map`. كلمة المرور bcrypt فقط. قفل الحساب: `failed_attempts` + `locked_until`.

## ERD الكامل (المراحل القادمة)

```
vendors ─┬─< vendor_staff
         ├─< vendor_categories >─ categories
         ├─< services ─< service_resources >─ resources
         └─< products

resources ─< resource_availability (قواعد أسبوعية)
          ─< resource_blockouts   (إغلاقات استثنائية)

users ─< bookings ─< booking_items >─ bookable (service|product|package)
      │        ─< booking_status_history (PENDING→CONFIRMED→…→EXPIRED)
      │        ─< payments
      └─< carts ─< cart_items >─ products
users ─< orders ─< order_items ─< order_status_history
      └─< wallets? no: vendors 1—1 wallets ─< wallet_transactions (ledger)
payouts >─ wallets        settlements (تسوية دورية)
coupons/promotions ─< redemption
reviews (booking_id|order_id، منع التقييم بلا شراء), favorites
conversations ─< messages (ربط اختياري بـ booking/order)
media, addresses, notification_preferences, settings, analytics_events
```

## قرارات جوهرية

1. **Generic Booking Engine**: لا `wedding_bookings`/`pool_bookings`. كل ما يحجز هو `resource` (قاعة، حلاق، ملعب، طاولة). الـ Vendor يعرّف موارده وقواعد توفرها.
2. **منع Double Booking**: قيد فريد جزئي في PostgreSQL + قفل صفوف داخل transaction:

```sql
-- قيد فريد جزئي: لا تداخل حجوزات مؤكدة/معلقة على نفس المورد
ALTER TABLE bookings ADD CONSTRAINT no_double_booking
  EXCLUDE USING gist (
    resource_id WITH =,
    tstzrange(starts_at, ends_at) WITH &&
  ) WHERE (status IN ('PENDING','CONFIRMED'));
```
   وعلى مستوى الكود: `SELECT ... FOR UPDATE` على صف المورد داخل `prisma.$transaction` قبل الفحص/الإدراج (تفاصيل: BOOKING_ENGINE.md).
3. **Ledger إلزامي**: رصيد الـ vendor مشتق من `wallet_transactions` (نوع الحركة: SALE/COMMISSION/REFUND/PAYOUT/ADJUSTMENT) — لا يُخزن رصيد واحد قابل للفساد.
4. **Idempotency**: `idempotency_keys(user_id, key, scope, result_ref)` للـ checkout والـ payments.
5. **Audit**: كل تغيير حساس يُسجل في `audit_logs` مع diff JSON.
