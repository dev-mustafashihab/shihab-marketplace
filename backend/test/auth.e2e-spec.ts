import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import helmet from 'helmet';
import { randomUUID } from 'crypto';
import { AppModule } from '../src/app.module';
import { validationPipeOptions } from '../src/common/config/validation.config';
import { SuccessInterceptor } from '../src/common/interceptors/success.interceptor';
import { ApiExceptionFilter } from '../src/common/filters/api-exception.filter';
import { PrismaService } from '../src/common/prisma.service';

// Run-scoped identity: the suite is safe to run in parallel with itself.
const RUN = randomUUID().slice(0, 8);
const CUSTOMER_EMAIL = `e2e.customer.${RUN}@example.com`;
const LOCK_EMAIL = `e2e.lock.${RUN}@example.com`;
const PASSWORD = 'Str0ng!Passw0rd';

describe('Auth & RBAC (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();
    app.use(helmet());
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(new ValidationPipe(validationPipeOptions));
    app.useGlobalInterceptors(new SuccessInterceptor());
    app.useGlobalFilters(new ApiExceptionFilter());
    await app.init();

    prisma = app.get(PrismaService);
    // Clean only THIS run's identities (users cascade to profile+tokens).
    await prisma.user.deleteMany({
      where: { email: { in: [CUSTOMER_EMAIL, LOCK_EMAIL] } },
    });
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /health is public', async () => {
    const res = await request(app.getHttpServer()).get('/api/v1/health').expect(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.status).toBe('ok');
  });

  it('registers a customer and returns tokens', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({ email: CUSTOMER_EMAIL, password: PASSWORD, firstName: 'عميل' })
      .expect(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.accessToken).toBeTruthy();
    expect(res.body.data.refreshToken).toBeTruthy();
  });

  it('rejects duplicate registration with 403', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({ email: CUSTOMER_EMAIL, password: PASSWORD })
      .expect(403);
  });

  it('rejects weak password with structured validation errors', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({ email: `weak.${RUN}@example.com`, password: '123' })
      .expect(400);
    expect(res.body.code).toBe('VALIDATION_ERROR');
    expect(res.body.errors.length).toBeGreaterThan(0);
  });

  it('login → me → protected endpoints with RBAC → refresh rotation & reuse detection', async () => {
    const login = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .send({ email: CUSTOMER_EMAIL, password: PASSWORD })
      .expect(200);
    const at = login.body.data.accessToken as string;
    const rt = login.body.data.refreshToken as string;

    const me = await request(app.getHttpServer())
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${at}`)
      .expect(200);
    expect(me.body.data.user.email).toBe(CUSTOMER_EMAIL);
    expect(me.body.data.user.role).toBe('CUSTOMER');

    // customer hits admin-only endpoint → 403
    await request(app.getHttpServer())
      .get('/api/v1/users')
      .set('Authorization', `Bearer ${at}`)
      .expect(403);

    // no token → 401
    await request(app.getHttpServer()).get('/api/v1/users').expect(401);

    // admin sees users list
    const adminLogin = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .send({
        email: process.env.SEED_ADMIN_EMAIL,
        password: process.env.SEED_ADMIN_PASSWORD,
      })
      .expect(200);
    const adminAt = adminLogin.body.data.accessToken as string;
    const list = await request(app.getHttpServer())
      .get('/api/v1/users?page=1&limit=5')
      .set('Authorization', `Bearer ${adminAt}`)
      .expect(200);
    expect(list.body.success).toBe(true);
    expect(Array.isArray(list.body.data)).toBe(true);
    expect(list.body.meta.total).toBeGreaterThanOrEqual(2);

    // rotate refresh → new token works
    const r1 = await request(app.getHttpServer())
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: rt })
      .expect(200);
    const rt2 = r1.body.data.refreshToken as string;
    expect(rt2).toBeTruthy();

    // reuse of the rotated token → 401 and revokes the whole family
    await request(app.getHttpServer())
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: rt })
      .expect(401);

    await request(app.getHttpServer())
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: rt2 })
      .expect(401);
  });

  it('locks account after 5 failed logins, then allows after unlock/reset', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({ email: LOCK_EMAIL, password: PASSWORD })
      .expect(201);

    for (let i = 0; i < 5; i++) {
      await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: LOCK_EMAIL, password: 'WrongPass!1' })
        .expect(401);
    }
    // locked even with the correct password
    const locked = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .send({ email: LOCK_EMAIL, password: PASSWORD })
      .expect(403);
    expect(locked.body.message).toContain('locked');

    // simulate lock expiry, then correct password works and resets counters
    await prisma.user.update({
      where: { email: LOCK_EMAIL },
      data: { lockedUntil: new Date(Date.now() - 1000) },
    });
    await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .send({ email: LOCK_EMAIL, password: PASSWORD })
      .expect(200);
    const user = await prisma.user.findUnique({ where: { email: LOCK_EMAIL } });
    expect(user?.failedAttempts).toBe(0);
    expect(user?.lockedUntil).toBeNull();
  });

  it('logout revokes the refresh token', async () => {
    const login = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .send({ email: CUSTOMER_EMAIL, password: PASSWORD })
      .expect(200);
    const at = login.body.data.accessToken as string;
    const rt = login.body.data.refreshToken as string;

    await request(app.getHttpServer())
      .post('/api/v1/auth/logout')
      .set('Authorization', `Bearer ${at}`)
      .send({ refreshToken: rt })
      .expect(200);

    const revoked = await prisma.refreshToken.findFirst({
      where: { user: { email: CUSTOMER_EMAIL }, revokedReason: 'LOGOUT' },
      orderBy: { createdAt: 'desc' },
    });
    expect(revoked).not.toBeNull();

    await request(app.getHttpServer())
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: rt })
      .expect(401);
  });

  it('stores password as bcrypt hash only', async () => {
    const user = await prisma.user.findUnique({ where: { email: CUSTOMER_EMAIL } });
    expect(user?.passwordHash).toMatch(/^\$2[aby]\$\d{2}\$/);
    expect(user?.passwordHash).not.toContain(PASSWORD);
  });
});
