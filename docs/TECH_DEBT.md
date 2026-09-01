# TECH DEBT — مسجل المؤجلين (P3/P4)

البروتوكول §15: ما يؤجل يُسجل هنا ولا يُنسى.

| ID | الأولوية | البند | الأثر | المرحلة المقترحة |
|---|---|---|---|---|
| TD-1 | P3 | صور VendorCard بلا تحميل حقيقي (placeholder أيقونة) — تحتاج CachedNetworkImage + fallback | جمالية | Phase 2 (ربط API) |
| TD-2 | P3 | google_fonts يجلب الخط runtime — للإنتاج: تجميع الخط محلياً في assets | أداء/أوفلاين | قبل النشر |
| TD-3 | P4 | Rate limit على /auth/login|register عام 60/د بدل 10/د مخصصة لكل مسار | تحسين أمني طفيف | Phase 2 |
| TD-4 | P4 | أزرار المنتصف الخلفية (bottom nav) غير منفذة بعد في Flutter | مطلوب Phase 10 | Phase 10 |
| TD-5 | P4 | Dark theme معمّر لكن غير معروض للمستخدم (مفتاح إعدادات لاحقاً) | تحسين | Phase 10 |

ملاحظة إصلاح منفذ: Java 21 بلا jlink يكسر بناء APK — الحل JAVA_HOME=java-17 موثق في DEPLOYMENT.md (ليس ديناً، قرار مثبت).

## إضافات ما بعد Phase 11 (مسجلة حسب البروتوكول §15)
| ID | الأولوية | البند | المرحلة |
|---|---|---|---|
| TD-6 | P3 | GET /vendors/admin/queue و GET /notifications يرجعان tuple [total,rows] بدل envelope meta موحد | Phase 11+ |
| TD-7 | P3 | flutter analyze فيه 7 infos (prefer_const) — لا errors | مستمر |
| TD-8 | P4 | فلتر openNow في /search معرف لكن غير مربوط بساعات العمل بعد | Phase 11+ |
| TD-9 | P4 | دفعات العميل من شاشة البائع تطلب رصيد كامل — لا مبلغ جزئي | لاحقاً |
