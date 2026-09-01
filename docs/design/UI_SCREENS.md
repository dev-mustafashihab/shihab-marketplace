# UI SCREENS — مواصفات الشاشات (المعيار الملزم قبل تنفيذ أي شاشة)

قالب كل شاشة: الغرض / الدخول / أفعال المستخدم / المكونات / الحالات / API / التنقل / حالات فارغة وخطأ وتحميل.

---

## Home (C)
- **الغرض:** الإقلاع نحو هدف خلال ≤2 لفتات.
- **الدخول:** Bottom tab 1.
- **أفعال:** تغيير الموقع، بحث، لمس تصنيف، لمس عرض/باقة، Plan My Event، فتح Vendor.
- **مكونات:** LocationBar, AppSearchBar, CategoryRow, OfferCarousel, VendorCard(أفقي), PackageCard, SectionHeader, EventPlannerBanner, SkeletonList.
- **الترتيب الرأسي:** موقع→بحث→تصنيفات→PlanMyEvent→عروض→قريب منك→الأكثر طلباً→باقات→شوهد مؤخراً (الأقسام تختفي إن لا بيانات — لا فراغات).
- **حالات:** Loading=Skeleton لكل قسم؛ Error=بانر علوي مع retry مع بقاء الكاش؛ Empty local=«لا نتائج قريبة — وسّع النطاق».
- **API:** GET /search/home-feed (مجمّع)؛ تفعيل الموقع يتقدم بهدوء.
- **تنقل:** →Search/Vendor/Category/Planner.

## Search Results (C)
- **الغرض:** تضييق إلى Vendor محدد.
- **مكونات:** SearchBar دائم، FilterChips (سعر/تقييم/مسافة/متاح الآن/سعة)، SortSheet، VendorCard list، Map toggle، ResultCount.
- **قواعد:** الفلاتر تُطبق فوراً مع عدّاد نتيجة حي؛ Map pin → بطاقة مصغرة فوق الخريطة؛ لا نتيجة = Empty State بفعل «امسح الفلاتر» أو «وسّع المسافة».
- **API:** GET /search?q&filters&page — ترقيم لا نهائي مع Skeleton footer.

## Vendor Details (C)
- **الغرض:** قرار ثقة + الدخول للحجز.
- **مكونات:** HeroGallery, VerifyBadge, RatingWidget, SectionTabs (خدمات/تقييمات/معلومات), AmenitiesChips, WorkingHours, MapMini, PolicyCard, Sticky CTA «احجز الآن».
- **قواعد:** السعر «من $X»؛ التقييم فوق الطية؛ الإلغاء بصيغة بشرية («إلغاء مجاني حتى 48 ساعة قبل»).
- **حالات:** Loading=Skeleton hero+sections؛ Error=كرت إعادة محاولة؛ Closed permanently=بانر ويخفى CTA.
- **API:** GET /vendors/:id (مع first reviews page).

## Booking Stepper (C)
- **الغرض:** حجز بلا احتكاك (5 خطوات، حفظ تلقائي).
- **Progress:** ●─●─○─○─○ (تاريخ/وقت/تفاصيل/بيانات/ملخص) — يمكن الرجوع بلمس النقاط السابقة.
- **كل خطوة:** CTA تالٍ معطّل حتى اكتمال الاختيار (سبب التعطيل ظاهر).
- **الملخص:** PriceCard مفصل (خدمة+إضافات+رسوم+خصم=الإجمالي) + تنبيه «السعر مثبت 15:00 دقيقة» مع عداد.
- **حالات خاصة:** انتهاء العداد → تحديث حي للأسعار/التوفر مع إبقاء المدخلات؛ فترة أصبحت محجوزة → 409 بلطف + 3 بدائل.

## Calendar / Slots (C)
- **أيام:** متاح (افتراضي)، محدود (نقطة برتقالية + «فترتان فقط»)، محجوم (مغلق/كامل — معطل، لمسة تشرح السبب)، اليوم.
- **فترات:** TimeSlot chips: متاح/محجوز (مشطوب)/قريب (Warning)/مختار.
- **قاعدة:** لا نص «غير متاح» وحيداً — دائماً سبب + بديل مقترح.

## Checkout (C)
- **الغرض:** إنهاء ثق بلا مفاجآت.
- **مكونات:** BookingSummaryMini, PriceCard، PaymentMethodSelector (محفوظ/جديد)، CouponField، [تأكيد ودفع].
- **قواعد:** لا شاشة تحميل بيضاء أثناء الدفع — Button loading + منع النقر المزدوج (Idempotency-Key خلف الكواليس)؛ خطأ دفع = حفظ المسار + رسالة مفهومة + محاولة/طريقة بديلة.

## Booking Confirmation (C)
بطاقة نجاح (نجمة خضراء + «حجزك مؤكد»)، رقم الحجز قابل للنسخ، إضافة للتقويم، تفاصيل مصغرة، [تتبع الحجز]. لا دعوات لتقييم التطبيق ولا ضجيج.

## Vendor Dashboard (V)
- **ترتيب الأولوية:** Pending count (إن >0) → حجوزات اليوم (Timeline أفقي) → إيراد اليوم/الأسبوع → روابط سريعة.
- **حالة فتح:** «أنت جاهز للانطلاق» + Checklist إعداد ناقص. أي Empty فيه فعل.

## Admin Table (A)
Desktop-first: جدول كثيف + فلاتر أعمدة + Bulk bar عند التحديد + Drawer للتفاصيل + Confirm dialog للأفعال الخطرة + Audit trail مرئي. (مواصفة تفصيلية عند Phase 8)

---

## قاعدة شاملة
كل شاشة أعلاه تخضع لـ UI Quality Gate (33 بنداً في الطلب) قبل اعتبارها منتهية.
