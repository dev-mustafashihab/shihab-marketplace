# ARCHITECTURE — Shihab Marketplace

## 1) نمط المعمارية: Modular Monolith

قرار المؤسس: لا Microservices في البداية. كل Module NestJS مستقل بملفاته ومنطقه وجدوله، بحدود صريحة (لا يعبر Module إلى repository آخر مباشرة — فقط عبر Services المصدَّرة)، بحيث يُفصل أي Module لاحقاً إلى خدمة مستقلة بتغيير النقل لا منطق العمل.

**قرار إضافي موثَّق (يطلب المؤسس عدم التغيير الصامت):** اختير **Prisma 6** كـ ORM لأنه يوفر migrations منظمة + types مولّدة + `$queryRaw` لـ `SELECT ... FOR UPDATE` المطلوب لمنع double-booking. عمليات الإنجاز الحرجة (الحجز) ستمر بـ transactions صريحة.

## 2) هيكل المستودع

```
/backend        NestJS API (الكود الأساسي)
/frontend       Flutter Customer App (Phase 10)
/admin          لوحات Admin/Vendor (Phase 8-9)
/infrastructure docker-compose, env, nginx/traefik لاحقاً
/docs           الوثائق المعمارية
/tests          تقارير وأدوات اختبار خارجية
```

## 3) حدود الـ Modules (Backend)

| Module | مسؤوليته | ممنوع عليه |
|---|---|---|
| auth | تسجيل/دخول/دوران refresh/logout/me | لا يعرف أي شيء عن Vendors/Bookings |
| users | البروفايل، قوائم المستخدمين (admin) | لا يصدر رموزاً (ذلك للـ auth) |
| roles | عرض الأدوار والصلاحيات | لا يمنح صلاحيات إلا الـ Admin |
| vendors | المتاجر، التحقق، الموظفون | لا يعدل bookings مباشرة |
| catalog | categories/services/products/venues | لا يعرف الجدولة |
| resources | موارد الحجز (قاعة/حلاق/موظف) + blockouts | لا يحسب الأسعار |
| availability | نوافذ التوفر لكل resource | لا يقرر الحجز |
| **booking** | المحرك العام + قفل الصفوف + آلة الحالات | **لا يعرف أنواع الـ vendors** |
| orders | cart/checkout/طلب مطعم أو منتج | لا يستدعي مزود دفع مباشرة |
| payments | PaymentProvider abstraction + webhooks | لا يلمس ledger |
| settlements | wallets/ledger/payouts/commissions | — |
| reviews, favorites, notifications, chat, search, coupons, promotions, media, admin, analytics, ai | كما في الطلب | — |

**Common** (`src/common`): PrismaService، Guards (JWT→RBAC)، Interceptors (envelope)، Filters (استجابة الأخطاء الموحدة)، Decorators (`@Public`, `@Roles`, `@Permissions`, `@CurrentUser`).

## 4) Flutter (Phase 10) — مختصر

`features/{auth,home,search,vendors,booking,orders,cart,payments,favorites,reviews,notifications,profile,chat}` — State management: **Riverpod** (اختيار واحد ملزم)، Repository Pattern فوق Dio مع اعتراض تجديد التوكن تلقائياً.

## 5) AI (غير إجباري في MVP)

`ai/` Module يعمل كـ orchestrator: يستقبل "عرس 300 بميزانية 3000$"، يفكك المتطلبات، يستعلم catalog/availability عبر Services الداخلية، ويجمع اقتراحاً بسعر. لا منطق أعمال في الـ AI نفسه.

## 6) Location

`vendors` يحمل `latitude/longitude` + عمود PostGIS `geography(Point,4326)` فهرس GIST؛ البحث القريب عبر ST_DWithin مع radius (5/10/20 km).
