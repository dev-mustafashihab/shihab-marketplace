# ROADMAP — مراحل التنفيذ

| Phase | المحتوى | الحالة |
|---|---|---|
| 1 | Setup + Architecture + Docker + PostgreSQL/PostGIS + Redis + Auth + Users + Roles/Permissions | **منفَّذة ومُختبرة (14/14 خضراء)** |
| 2 | Vendors + Categories + Services + Products + Resources + Availability | تصميم جاهز — تالية |
| 3 | Booking Engine + منع Double Booking (EXCLUDE + FOR UPDATE + TTL) | تصميم جاهز في BOOKING_ENGINE.md |
| 4 | Orders + Cart + Checkout | — |
| 5 | Payments + Commission + Ledger + Payouts | تصميم في PAYMENTS.md |
| 6 | Reviews + Favorites + Notifications (queue) | — |
| 7 | Search + Nearby (PostGIS) + Filters | — |
| 8 | Admin Dashboard | — |
| 9 | Vendor Dashboard | — |
| 10 | Flutter Customer App (Riverpod) | — |
| 11 | Testing شامل + Security + Performance | أساس Phase 1 موجود (unit/e2e) |
| 12 | Deployment (nginx + CI/CD كامل) | CI مبدئي موجود |

## قاعدة الانتقال
لا يبدأ Module جديد قبل استقرار الحالي: build نظيف + tests خضراء + توثيق محدّث.
