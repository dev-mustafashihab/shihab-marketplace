# SCREEN INVENTORY — جرد الشاشات وتصنيف المراحل

القاعدة: لا يُنفذ خارج الـ MVP. (C=Customer, V=Vendor, A=Admin)

## MVP (Phase 10 الأساسي — 22 شاشة C + 8 V)

### Core / Onboarding (C)
| # | الشاشة | الغرض | CTA الرئيسي |
|---|---|---|---|
| 1 | Splash | تهيئة + جلسة | — (تلقائي) |
| 2 | Onboarding (3 شرائح) | قيمة التطبيق في 15 ثانية | «ابدأ» / تخطي |
| 3 | Location Permission | دقة الاقتراحات القريبة | «تفعيل الموقع» / «لاحقاً» |
| 4 | Login | دخول | «تسجيل الدخول» |
| 5 | Register | حساب جديد (اسم/بريد/جوال/كلمة) | «إنشاء الحساب» |
| 6 | OTP | توثيق الجوال | «تأكيد» |

### Discovery (C)
| # | الشاشة | ملاحظات |
|---|---|---|
| 7 | Home | كما في IA: موقع/بحث/تصنيفات/عروض/قريب/باقات |
| 8 | Search Results | قائمة/خريطة + فلاتر (سعر، تقييم، مسافة، متاح الآن) |
| 9 | Category | مثل 8 مع فلتر سعة للصالات |
| 10 | Vendor Details | Hero + خدمات + تقييمات + سياسات + Map + CTA ثابت |
| 11 | Service Details | خيارات/إضافات + CTA «اختر الوقت» |
| 12 | Gallery | Full-screen معطلات |

### Booking (C)
| # | الشاشة | ملاحظات |
|---|---|---|
| 13 | Booking Stepper | 5 خطوات: تاريخ/وقت/مورد+إضافات/بيانات/ملخص |
| 14 | Calendar/Slots | حالات اليوم والفترة + سبب التعذر |
| 15 | Checkout | ملخص + سعر نهائي + طريقة دفع + [تأكيد ودفع] |
| 16 | Payment | استضافة مزود/كارت محفوظ |
| 17 | Booking Confirmation | نجاح + رقم + إجراءات (تقويم/تتبع) |

### Manage (C)
| # | الشاشة | ملاحظات |
|---|---|---|
| 18 | Bookings List | قادمة/سابقة + StatusBadge |
| 19 | Booking Details | حالة + تواصل + إلغاء/تقييم حسب السياسة |
| 20 | Orders List + Timeline | F2 |
| 21 | Cart + Checkout (طلبات) | عنوان/تسليم/دفع |
| 22 | Profile Hub | بروفايل/عناوين/مفضلة/إشعارات/لغة/دعم |

### Vendor (V) — MVP مصغر
| # | الشاشة | ملاحظات |
|---|---|---|
| V1 | Vendor Register + Status | تسجيل قصير + «قيد التحقق» |
| V2 | Dashboard | حجوزات اليوم + Pending + أرباح مصغرة |
| V3 | Requests | قبول/رفض بضغطة |
| V4 | Resources | CRUD بسيط |
| V5 | Services & Prices | CRUD بسيط |
| V6 | Availability | أسبوعي + إغلاقات |
| V7 | Calendar | يوم/مورد |
| V8 | Earnings | إجمالي/عمولة/صافي/سحوبات |

### Admin (A) — ويب، Phase 8 (خارج MVP موبايل لكن مرصودة)
Shell + Tables: Vendors/Verification/Bookings/Refunds/Settings/Audit.

## PHASE 2 (بعد إطلاق MVP)
Chat كامل، Favorites بشاشة مستقلة، Notifications Center غني، Reviews writing متقدم، Coupons wallet، Event Planner التفاعلي الكامل (F3 MVP = نموذج بسيط), Arabic numerals toggle, Dark mode.

## PHASE 3
Wallet داخلي، Packages builder للبائع، Loyalty، Multi-vendor event bundle (حجز عدة بنود خطة بدفعة واحدة)، Vendor staff accounts، Analytics dashboards.

## Offline/Connectivity
كل الشاشات الرئيسية تتحمل شبكة ضعيفة: Skeleton + retry، وآخر نتائج مخبأة للقراءة.
