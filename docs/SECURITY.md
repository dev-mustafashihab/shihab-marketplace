# Security Model

## المصادقة
- **Access JWT**: 15 دقيقة، لا حالة، يحمي identity + role (لا صلاحيات مفصلة داخله تاريخية).
- **Refresh JWT**: 7 أيام، `typ=refresh`، يُخزن **SHA-256 hash** فقط في `refresh_tokens` مع:
  - **دوران** عند كل استخدام (القديم يُعلَّم `ROTATED`).
  - **كشف إعادة استخدام**: أي استخدام لرمز مُدوَّر ⇒ إبطال `family_id` كاملاً (`FAMILY_REVOKED_REUSE_DETECTED`).
- **قفل الحساب**: 5 إخفاقات ⇒ قفل 15 دقيقة؛ زمن استجابة موحد لعدم كشف وجود الحساب.

## الترخيص
- Guards بالترتيب: `JwtAuthGuard` → `ThrottlerGuard` → `PermissionsGuard` (المصادقة قبل التفويض — خطأ ترتيب سبّب 401 جماعية وتم إصلاحه والتحقق منه).
- RBAC ثنائي الطبقة: `@Roles()` للأدوار الكبيرة، `@Permissions()` مفصلة (مثال: `bookings:decide`)، `ADMIN` = `*`.

## حماية المدخلات
- `ValidationPipe` global: whitelist + forbidNonWhitelisted (رفض الحقول المجهولة) + تحويل صريح فقط.
- Prisma يستخدم parameterized queries (لا SQL injection).
- helmet (secure headers) + CORS whitelist من `CORS_ORIGINS`.

## أسرار
- كل شيء عبر `.env` (مستثنى من Git عبر `.gitignore`) — `envValidationSchema` (Joi) يرفض الإقلاع بسرّ أقل من 32 حرفاً أو DATABASE_URL ناقص.
- `.env.example` بلا قيم حقيقية. `infrastructure/.env` لكلمة مرور Postgres فقط (chmod 600).

## الخصوصية والتسجيل
- لا تُسجل أبداً: passwords، tokens، payment secrets.
- `audit_logs` لأثر العمليات الحساسة (من/ماذا/متى/IP).

## Idempotency & Webhooks
- `Idempotency-Key` إلزامي على العمليات المالية (checkout/payments).
- Webhooks مزودي الدفع تُتحقق بتوقيع HMAC قبل أي معالجة.

## Rate limiting
- عام 60/دقيقة/دخيل (قابل للضبط)، و10/دقيقة على auth login/register (Phase 1: عبر ضبط THROTTLE_*؛ التخصيص لكل مسار عند توسيع auth).
