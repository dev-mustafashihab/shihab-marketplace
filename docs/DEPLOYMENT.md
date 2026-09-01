# DEPLOYMENT

## بيئة التطوير (الحالية)
```bash
cd infrastructure && docker compose --env-file .env up -d   # postgres:5433 redis:6380
cd backend && npm install && npx prisma migrate deploy && npx prisma db seed
npm run build && npm run start:prod                          # API على 127.0.0.1:5400
```

## إنتاج (خطة)
1. `NODE_ENV=production` + أسرار جديدة (لا تُعاد استخدام أسرار التطوير).
2. `prisma migrate deploy` فقط (لا `migrate dev`).
3. Backend خلف nginx/Traefik مع TLS؛ الحاويات على شبكة داخلية فقط (لا منشور للـ DB/Redis على 127.0.0.1 العام).
4. `pm2` أو خدمة systemd للـ backend (أو Compose service مع restart policy).
5. نسخ احتياطي يومي: `pg_dump` + offsite، واختبار استرجاع شهري.
6. Health: `/api/v1/health` للـ load balancer.

## نشر Flutter (لاحقاً)
Build على CI، توزيع APK داخلي (أو المتاجر لاحقاً)، توجيه التطبيق إلى `https://<domain>/api/v1`.
