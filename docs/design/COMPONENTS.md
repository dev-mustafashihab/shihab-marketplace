# COMPONENTS — مكتبة المكونات

كل مكون: الحالات الـ9 (default/pressed/focused/disabled/loading/error/success/selected/empty حيث ينطبق) + قواعد RTL + أبعاد من Tokens فقط.

## الأساس (Core)
| المكون | الوصف | الحالات |
|---|---|---|
| **AppButton** | primary/secondary/ghost/destructive؛ ارتفاع 52؛ Full-width خيار | loading (spinner+نص محفوظ العرض)، disabled مع سبب tooltip-less |
| **AppTextField** | label عائم + hint + خطأ تحت الحقل | error برسالة بشرية، success check خفيف |
| **AppSearchBar** | مسافة 52، أيقونة مسح، debounce 300ms | loading مؤشر داخلي |
| **AppCard** | surface، radiusM، e1، لمعان ضغط خفيف | — |
| **StatusBadge** | Pending رملي/Confirmed أخضر/Cancelled أحمر باهت/Completed رمادي/Expired باهت | — |
| **PriceCard** | صفوف مفصلة + إجمالي displayL + فواصل colorBorder | discount بخط أخضر |
| **RatingWidget** | نجوم 14px + عدد التقييمات + متوسط Bold | write-mode نصف نجمة |
| **FilterChip** | selected=primary 12% خلفية + حدود primary | multi-select |
| **BottomSheet** | drag handle، radiusL، حد أقصى 90% شاشة | swipe-to-dismiss |
| **AppDialog** | عنوان/رسالة/فعلان (تأكيد primary، إلغاء ghost) | — |
| **SkeletonLoader** | shimmer 1.2s على شكل المحتوى الفعلي | — |
| **EmptyState** | رسم خفيف + عنوان + سطر شرح + CTA | إلزامي بديل «No data» |
| **ErrorState** | رسالة بشرية + retry + report id مخفي | — |

## المجال (Domain)
| المكون | المحتوى | ملاحظات |
|---|---|---|
| **VendorCard** | صورة 4:3، اسم، VerifyBadge، تقييم، «من $X»، مسافة | ارتفاع ثابت شبكتين عمودين (أفقي carousel = عرض 240) |
| **ServiceCard** | صورة مصغرة، اسم، مدة، سعر من | CTA ضمني (كارت كامل لمس) |
| **ProductCard** | صورة مربعة، اسم، سعر، +/- كمية | للسلة |
| **BookingCard** | Vendor+خدمة، تاريخ/وقت، StatusBadge، (خريطة مصغرة للقادمة) | إعادة حجز للسابقة |
| **CategoryItem** | أيقونة دائرية 64 + تسمية | شبكة 4 أعمدة |
| **OfferCard** | شعار Offer بخلفية Accent 10%، خصم، صلاحية | مقتصد اللون |
| **DatePicker** | شهر واحد، أيام حالات التوفر، RTL-aware (السبت بداية عربية اختياري — الافتراضي: الاثنين) | يمتد لمستقبلي 6 أشهر |
| **TimeSlot** | chip 48px ارتفاع، حالات متاح/محجوز/قريب/مختار | شبكة 3 أعمدة |
| **StepperHeader** | نقاط + تسميات + تقدم | taps للسابقة فقط |
| **OrderTimeline** | عمودي، نقاط بألوان الحالة، وقت كل مرحلة | Current = منتفخ |
| **LocationBar** | أيقونة موقع + اسم منطقة + chevron | يفتح Sheets مدن |

## قواعد الاستخدام
- لا ينفذ Widget أي spacing خارج Tokens؛ لا hex؛ لا text style يدوي (من app_typography فقط).
- كل مكون نصي يدعم maxLines+ellipsis مقصود.
- المكون يُستخدم من `core/widgets` فقط — إعادة تعريف محلي = رفض مراجعة.
- الوصولية: semantic labels للنجوم/الحالات/الأزرار الأيقونية؛ hit area 48؛ علاقة تباين 4.5:1 للنص.
