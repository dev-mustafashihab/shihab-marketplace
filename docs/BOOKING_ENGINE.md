# BOOKING ENGINE — المحرك العام ومنع الـ Double Booking

## المبدأ
لا أنظمة حجز منفصلة. كل ما يُحجز هو **Resource**:
- Venue → Main Hall / VIP Hall / Garden
- Salon → Barber1 / Barber2 / Stylist
- Pool/Chalet → الكيان نفسه resource
- Employee (مصور/موسيقي) → resource بشخص

السلسلة: `vendor → resource → resource_availability (قواعد أسبوعية) → bookings`

## آلة الحالات
```
PENDING ──confirm──▶ CONFIRMED ──start──▶ IN_SERVICE? ──complete──▶ COMPLETED
   │ ──reject──▶ REJECTED        │
   └──expire (TTL 15د)─▶ EXPIRED └──cancel──▶ CANCELLED (قواعد إلغاء حسب الوقت)
```
كل انتقال يُسجل في `booking_status_history` (from/to/actor/reason/at).

## منع الـ Double Booking (3 طبقات)

### 1) قاعدة توفر (قبل كل شيء)
`resource_availability` يحدد نوافذ العمل؛ `resource_blockouts` إغلاقات. الطلب خارج النوافذ يُرفض مباشرة.

### 2) قيد قاعدة بيانات (الطبقة الصلبة)
```sql
ALTER TABLE bookings ADD CONSTRAINT no_double_booking
  EXCLUDE USING gist (resource_id WITH =, tstzrange(starts_at, ends_at) WITH &&)
  WHERE (status IN ('PENDING','CONFIRMED'));
```
حتى لو تخطى كود التطبيق، Postgres نفسه يرفض التداخل بـ `23P01` (يُحوَّل لـ `409 SLOT_TAKEN`).

### 3) Transaction + Row Lock (منع race conditions)
```ts
await prisma.$transaction(async (tx) => {
  // قفل صف المورد: كل عمليات الحجز المتزامنة تتصنف هنا
  await tx.$queryRaw`SELECT id FROM resources WHERE id = ${resourceId} FOR UPDATE`;
  // فحص availability/blockouts + التداخل الزمني داخل نفس الـ tx
  // ثم إنشاء booking بحالة PENDING + booking_items + سجل history
});
```
`SELECT FOR UPDATE` يضمن أن محاولتين متزامنتين لن تقرأا «متاح» معاً: الثانية تنتظر ثم ترى التعارض.

## عناصر إضافية
- **Idempotency**: `Idempotency-Key` على POST /bookings — إعادة المحاولة تعيد الحجز نفسه ولا تخلق ثنائياً.
- **Expiration**: PENDING بلا دفع خلال 15 دقيقة → EXPIRED (BullMQ delayed job + تأكيد عند القراءة).
- **لا ثقة بالعميل**: السعر والمدة والمورد يُعاد حسابهم من DB داخل السيرفر.

## الاختبارات المطلوبة (Phase 3)
- محاولتان متزامنتان على نفس الفترة ⇒ واحدة 201 وواحدة 409.
- تجاوز blockout ⇒ 422. خارج نافذة توفر ⇒ 422.
- انتهاء PENDING ⇒ EXPIRED ويُحرر الوقت.
- إلغاء CONFIRMED قبل/بعد عتبة الإلغاء ⇒ قواعد الاسترجاع.
