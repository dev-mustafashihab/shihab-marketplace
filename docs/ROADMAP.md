# ROADMAP — مراحل التنفيذ

| Phase | المحتوى | الحالة |
|---|---|---|
| 1 | Setup + Architecture + Docker + PostgreSQL/PostGIS + Redis + Auth + Users + Roles/Permissions | **منفَّذة ومُختبرة (14/14 خضراء)** |
| 2 | Vendors + Categories + Services + Products + Resources + Availability | تصميم جاهز — تالية |
| 3 | Booking Engine + منع Double Booking (EXCLUDE + FOR UPDATE + TTL) | تصميم جاهز في BOOKING_ENGINE.md |
| 4 | Orders + Cart + Checkout | — |
| 5 | Payments + Commission + Ledger + Payouts | تصميم في PAYMENTS.md |
| 6 | Reviews + Favorites + Notifications (queue) | — |
| 7 | Search + Nearby (PostGIS) + Filters | **منفَّذة ومُختبرة** |
| 8 | Admin Dashboard (ويب) | **منفَّذة ومُختبرة** |
| 9 | Vendor Dashboard (موبايل ويب) | **منفَّذة ومُختبرة** |
| 10 | Flutter Customer App (Riverpod) | **الشاشات الأساسية منفَّذة** |
| 11 | تفاعل العميل: Auth + تفاصيل بائع + حجز فعلي | **منفَّذ ومُختبر** |
| 12 | Production Readiness + Final Audit | **تم — بانتظار قرار النشر** |

## قاعدة الانتقال
لا يبدأ Module جديد قبل استقرار الحالي: build نظيف + tests خضراء + توثيق محدّث.
