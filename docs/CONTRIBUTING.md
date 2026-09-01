# CONTRIBUTING

## قواعد غير قابلة للنقاش
1. عمل على feature branches: `feat/<module>-<topic>` — لا commit مباشر على main.
2. قبل كل PR: `npm run build` + `npm test` + `npm run test:e2e` — كلها خضراء.
3. لا `git reset --hard` ولا حذف بيانات/ملفات مهمة بدون سبب موثق.
4. لا أسرار في Git (`.env` مستثنى). قيم جديدة ⇒ عدّل `.env.example` بقيم وهمية.
5. لا `any` في TypeScript إلا بتعليق مبرر.
6. لا Business Logic داخل Controllers — في Services؛ الوصول للبيانات عبر Prisma Models/Repositories.
7. كل endpoint: DTO validation + response envelope الموحد + ترميز أخطاء قياسي.
8. الوثائق في `docs/` تُحدَّث مع أي تغيير معماري (لا تغييرات صامتة).

## بنية commit
`feat(auth): refresh token family revocation` — imperative، نطاق واحد لكل commit.
