# PAYMENTS — المعمارية المالية

## الفصل الصارم
`orders/bookings` لا يعرفان مزود دفع. الواجهة:

```ts
interface PaymentProvider {
  createIntent(amount: Money, ref: PaymentRef, idempotencyKey: string): Promise<Intent>;
  capture(intentId: string): Promise<CaptureResult>;
  refund(paymentId: string, amount: Money, reason?: string): Promise<RefundResult>;
  verifyWebhook(headers: Record<string,string>, rawBody: Buffer): Promise<WebhookEvent>;
}
```
إضافة مزود = Implementation جديدة + تسجيلها بالـ DI (Factory). التبديل من إعدادات المنصة.

## التدفق
1. Checkout/Booking-Confirm ⇒ `payments.createIntent` (مع Idempotency-Key).
2. العميل يدفع (redirect أو SDK).
3. Webhook موقّع HMAC ⇒ `verifyWebhook` ⇒ تحديث `payment_transactions` (سجل كامل لكل محاولة).
4. تأكيد الطلب/الحجز فقط عند `captured` (ولا يُؤتمت الإلغاء إلا بـ `refunded`).

## Commission & Ledger (مثال المؤسس: 100 ⇒ 90 vendor + 10 منصة، النسبة من إعدادات admin)

كل حركة مالية = سطر في `wallet_transactions`:
```
SALE(+100) → COMMISSION(-10) → NET_FOR_VENDOR(90) → REFUND(-90 إن وجد) → PAYOUT(-amount عند التحويل)
```
- رصيد الـ vendor = **مشتق دائماً** من مجموع الأسطر (لا عمود رصيد قابل للفساد) + snapshot اختياري للتسريع.
- `payouts` بحالات REQUESTED/APPROVED/PAID/FAILED مع audit.
- `settlements`: تجميع دوري (يومي/أسبوعي) بإغلاق غير قابل للتعديل.

## Idempotency
جدول `idempotency_keys(user_id, key, scope, request_fingerprint, result_ref)` — نفس المفتاح يعيد نفس النتيجة بدون تنفيذ مالي مزدوج. كل عمليات checkout/intent/refund/payout تمر عبره.

## Taxes/Fees
`settings.financial` (commission %، fee ثابت، ضريبة %) قابلة للتعديل من admin، وتُثبت على مستوى الطلب وقت إنشائه (لا تتأثر بتغييرات لاحقة).
