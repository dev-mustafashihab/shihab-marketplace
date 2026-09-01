# API Design — v1

Base: `/api/v1` — Swagger حي: `/api/docs`.

## التنسيق الموحد

نجاح:
```json
{ "success": true, "data": {}, "message": null, "meta": { "page": 1, "limit": 20, "total": 42, "totalPages": 3 } }
```
خطأ:
```json
{ "success": false, "message": "Human readable", "code": "ERROR_CODE", "errors": [{ "field": "email", "message": "..." }] }
```

## أكواد الأخطاء القياسية
`VALIDATION_ERROR` `UNAUTHORIZED` `FORBIDDEN` `NOT_FOUND` `DUPLICATE_RESOURCE` `CONFLICT` `RATE_LIMITED` `INTERNAL_ERROR`

## المصادقة (مطبَّق في Phase 1)

| Method | Path | Auth | ملاحظات |
|---|---|---|---|
| POST | /auth/register | عام | يرجع accessToken+refreshToken |
| POST | /auth/login | عام | قفل بعد 5 إخفاقات 15 دقيقة |
| POST | /auth/refresh | عام | دوران + كشف إعادة استخدام (إبطال العائلة) |
| POST | /auth/logout | Bearer | إبطال refresh المرسل |
| GET | /auth/me | Bearer | identity + permissions |

## المستخدمون والأدوار (مطبَّق)

| Method | Path | الصلاحية |
|---|---|---|
| GET/PATCH | /users/me/profile | المستخدم نفسه |
| GET | /users | `users:read` (admin) — صفحات+بحث+فلتر role |
| GET | /roles | `roles:read` (admin) |

## مخطط باقي الوحدات (تصميم)

```
/vendors  GET (بحث/قريب/تقييم) | GET /:id | POST (تسجيل بائع) | PUT /:id/verification
/catalog  /categories /services /products /venues (CRUD + فلاتر)
/resources CRUD + /:id/blockouts
/availability GET /:resourceId?date=...
/bookings  POST (يطلب Idempotency-Key) | GET /:id | POST /:id/cancel | POST /:id/confirm (vendor/admin)
/orders    POST /checkout | GET /:id | POST /:id/cancel
/payments  POST /intent | POST /webhook/:provider (توقيع موثق) | POST /refund
/wallets   GET /me | GET /me/transactions | POST /payouts
/reviews   POST | GET /vendor/:id
/favorites GET/PUT
/notifications GET | PATCH /preferences
/chat      GET /conversations | POST /conversations/:id/messages
/search    GET /?q=&near=&radius_km=&category=&price_max=&open_now=
/admin     إدارة: users/vendors/verification/bookings/refunds/commissions/settings/audit
```

قواعد: Versioning بالمسار، DTO + class-validator لكل مدخل، Rate limit عام 60/د (+ أشد على auth)، Idempotency-Key إلزامي على POST المالية.

---

## Phase 2 — Vendors / Categories / Services / Products / Resources / Availability (منفذة)

| Method | Endpoint | Auth | الوصف |
|---|---|---|---|
| GET | /categories?includeInactive | عام | تصنيفات نشطة (أو الكل للأدمن عبر `categories:manage`) |
| POST/PATCH/DELETE | /categories[/:id] | categories:manage | إدارة التصنيفات |
| GET | /vendors?page&limit&categoryId&q | عام | بحث البائعين **المعتمدين فقط** + pagination |
| GET | /vendors/:idOrSlug | عام | تفاصيل بائع (uuid أو slug) + خدماته وموارده |
| GET | /vendors/me/profile | Bearer | متجر البائع الحالي (للداشبورد) |
| POST | /vendors | Bearer (VENDOR) | إنشاء متجر — واحد لكل مالك، يبدأ PENDING |
| PATCH | /vendors/:id | Bearer (owner أو ADMIN) | تحديث؛ تغيير status للـ ADMIN فقط (IDOR محمي) |
| GET | /vendors/admin/queue/:status | vendors:verify | طوابير التوثيق (تستخدم tuple envelope) |
| GET | /services/public/vendor/:vendorId | عام | خدمات نشطة لبائع |
| GET/POST | /services/mine، /services | Bearer | خدمات متجر البائع الحالي |
| PATCH/DELETE | /services/:id | Bearer + ownership | تعديل/حذف خدمة |
| GET | /products/vendor/:vendorId (عام) + mine/POST/PATCH/DELETE | Bearer | نفس نمط الخدمات |
| GET/POST/PATCH/DELETE | /resources/mine … | Bearer + ownership | موارد الحجز (VENUE/STAFF/EQUIPMENT/OTHER) |
| GET | /availability/resource/:resourceId | عام | جدول أسبوعي لمورد |
| PUT | /availability/resource/:resourceId | Bearer + ownership | استبدال كامل للجدول (ذري، weekday 0-6، دقائق 0-1440) |

**ملاحظة عقد:** `GET /vendors/admin/queue/:status` يرجع tuple `[total, rows]` داخل الـ envelope (بدون meta) — سيُوحَّد في Phase 3 عند لمس الواجهة الأمامية للأدمن.
