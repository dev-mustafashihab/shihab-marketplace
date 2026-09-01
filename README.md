# Shihab Marketplace

منصّة Marketplace للخدمات والمناسبات: حجوزات صالات/مسابح/شاليهات/صالونات، طلبات مطاعم وهدايا، باقات كاملة — Modular Monolith قابل للتحول إلى Microservices.

## Stack

| الطبقة | التقنية |
|---|---|
| Backend | NestJS 11 + TypeScript 5 (REST، versioned `/api/v1`) |
| Database | PostgreSQL 16 + PostGIS 3.4 (Prisma 6 ORM) |
| Cache/Queue | Redis 7 (+ BullMQ لاحقاً) |
| Auth | JWT Access 15m + Refresh 7d بدوران وكشف إعادة استخدام |
| Docs | Swagger على `/api/docs` |
| Infra | Docker Compose (postgres:5433، redis:6380، backend:5400) |

## التشغيل السريع

```bash
# 1) البنية
cd infrastructure && docker compose --env-file .env up -d

# 2) Backend
cd backend
cp .env.example .env          # ثم عدّل DATABASE_URL/JWT secrets
npm install
npx prisma migrate deploy
npx prisma db seed
npm run start:prod            # http://127.0.0.1:5400/api/v1
```

## حسابات البذر (Phase 1)

| الدور | البريد | كلمة المرور |
|---|---|---|
| ADMIN | تُضبط في `backend/.env` عبر `SEED_ADMIN_EMAIL` / `SEED_ADMIN_PASSWORD` | (لا يوجد افتراضي — تعمّد Credentials في الكود) |
| CUSTOMER | customer@marketplace.local | Customer@2026 |
| VENDOR | vendor@marketplace.local | Vendor@2026 |

> حسابات البذر demo للتجربة المحلية فقط. غيّرها (أو احذفها من seed) قبل أي نشر.

## الاختبارات

```bash
npm test                       # Unit (6)
npm run test:e2e               # E2E على marketplace_test (8)
```

## الوثائق

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) — المعمارية وحدود الـ Modules
- [DATABASE.md](docs/DATABASE.md) — ERD + المخطط الكامل
- [API.md](docs/API.md) — تصميم الـ API
- [SECURITY.md](docs/SECURITY.md) — نموذج الأمان
- [BOOKING_ENGINE.md](docs/BOOKING_ENGINE.md) — محرك الحجز ومنع الـ double booking
- [PAYMENTS.md](docs/PAYMENTS.md) — الدفع والعمولة والـ Ledger
- [ROADMAP.md](docs/ROADMAP.md) — خطة المراحل 1→12
- [DEPLOYMENT.md](docs/DEPLOYMENT.md) + [CONTRIBUTING.md](docs/CONTRIBUTING.md)
