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
