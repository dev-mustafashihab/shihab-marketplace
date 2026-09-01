# DELIVERY PROTOCOL — آلية التسليم بين المراحل (ملزم)

> وثيقة العقد من مالك المشروع. أي Phase بدون استيفاء هذا البروتوكول = غير مسلّمة.

## 1) قاعدة الانتقال
IMPLEMENT → SELF REVIEW → TEST → FIX → SECURITY CHECK → DOCUMENTATION → BUILD → DELIVERY REPORT → **WAIT FOR APPROVAL**
لا تبدأ Phase التالية إلا بعد كلمة **APPROVED** صراحة من المالك.

## 2) Delivery Package لكل Phase
A. Summary — B. Files Changed (Created/Modified/Deleted + سبب) — C. Database Changes — D. API Changes (METHOD/ENDPOINT/AUTH/PURPOSE/REQUEST/RESPONSE) — E. Tests (أعداد ونتائج) — F. Verification (lint/typecheck/unit/integration/e2e/build — أي فشل = ليست مكتملة).

## 3) Definition of Done
Code ✓ No TS errors ✓ No lint ✓ Migrations ✓ Tests written+passing ✓ API documented ✓ Security reviewed ✓ Error handling ✓ Logging ✓ Env documented ✓ Docs updated ✓ Build succeeds ✓ No secrets committed ✓

## 4) Git
Commit format: `feat(phase-01): project foundation and authentication`. قبل commit: git status/diff/diff --cached + فحص أسرار. لا squash/reset/force-push بدون موافقة.

## 5) Migrations
كل تغيير DB عبر Migration فقط. versioned/reviewable/rollback-aware. قبل التسليم: **fresh database migration test** يجب أن ينجح.

## 6) API Contract
Swagger/OpenAPI محدث قبل إنهاء أي Phase فيها APIs. Breaking Changes موثقة فقط.

## 7) Backward Compatibility
بعد كل Phase: Regression tests للمراحل السابقة + الجديدة. نجاح الكل شرط.

## 8) Performance
slow queries / missing indexes / N+1 / unbounded queries / pagination في القوائم. لا SELECT * عشوائي.

## 9) Security Gate
AuthN/AuthZ/Validation/RBAC/Rate limit/Sensitive data/SQLi/IDOR/Broken access/Secrets/Logs/Uploads/Webhooks. مشكلة عالية الخطورة = المرحلة غير مكتملة حتى تُحل.

## 10) Deployment
Local → Tests → Build → Docker → Staging → Smoke → Delivery. Production بموافقة صريحة فقط.

## 11) Phase Gate
التقرير النهائي بالقالم الموحد (Status/Implemented/Files/Database/APIs/Tests/Lint/TypeCheck/Build/Security/Migration/Regression/Documentation/Git Commit/Known Issues/Next Phase/Approval Required: YES).

## 12) عند فشل الاختبارات
TEST → FAIL → ANALYZE → FIX → TEST AGAIN. لا إخفاء. إذا عالج خارج نطاقي: BLOCKED + Problem/Why/What I need/Recommended.

## 13) القرارات
داخلي قابل للعكس → أقرر. أما Architecture/DB Model/Payment/Security/AuthN/Public API/Infra/Data Migration/Cost/3rd-party → أتوقف وأسأل.

## 14) شرط بدء Phase
Previous APPROVED + Tests PASS + Build PASS + DB stable + Docs updated + Git clean. غير ذلك: لا بدء.

## 15) أولويات الإصلاح
P0 Security/DataLoss/Payment → P1 Core → P2 Major يجب إصلاحها قبل الانتقال. P3/P4 تؤجل وتسجل في TECH_DEBT.md.

## 16) Final Handoff
Final Audit (11 محوراً) ثم FINAL DELIVERY REPORT ثم Production Readiness Review → Approval → Deployment.
