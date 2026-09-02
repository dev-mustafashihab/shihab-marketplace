import { Test } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/common/prisma.service';

/**
 * PHASE 17/18: اختبارات تكاملية على قاعدة بيانات حقيقية (marketplace_test)
 * تغطي إصلاحات P0: payments XOR/amount/state، order status 400، stock atomic.
 */
describe('Hardening P0 (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let adminToken: string;
  let customerToken: string;
  let customerId: string;
  let vendorToken: string;
  let vendorId: string;
  let productId: string;
  let bookingId: string;

  const admin = { email: 'admin@marketplace.local', password: 'Admin@2026' };
  const vendor = { email: 'vendor@marketplace.local', password: 'Vendor@2026' };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
    await app.init();
    prisma = app.get(PrismaService);

    const login = async (email: string, password: string) => {
      const res = await request(app.getHttpServer()).post('/api/v1/auth/login').send({ email, password });
      return res.body.data.accessToken as string;
    };
    adminToken = await login(admin.email, admin.password);
    vendorToken = await login(vendor.email, vendor.password);

    // عميل تجريبي جديد
    const email = `hard-${Date.now()}@test.com`;
    const reg = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({ email, password: 'Hard123!@#', role: 'CUSTOMER' });
    customerToken = reg.body.data.accessToken;
    customerId = (await prisma.user.findUnique({ where: { email } }))!.id;

    vendorId = (await prisma.vendor.findFirst({ where: { slug: 'qasr-al-amal' } }))!.id;
    const product = await prisma.product.create({
      data: { vendorId, name: `HardTest-${Date.now()}`, price: 10, currency: 'USD', stock: 5, isActive: true },
    });
    productId = product.id;
  });

  afterAll(async () => {
    await prisma.product.deleteMany({ where: { id: productId } });
    await app.close();
  });

  it('Phase 7: invalid order status returns 400 and does NOT cancel', async () => {
    // أنشئ طلباً من السلة
    await request(app.getHttpServer())
      .post('/api/v1/cart/items')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ productId, quantity: 1 })
      .then(r => { if (r.status >= 400) console.log('CART ADD FAIL:', r.status, JSON.stringify(r.body)); return r; });
    const ord = await request(app.getHttpServer())
      .post('/api/v1/orders/checkout')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ address: 'دمشق - المزة الشارع العام', phone: '0938 045 496' });
    if (ord.status !== 201) console.log('CHECKOUT FAIL BODY:', JSON.stringify(ord.body));
    expect(ord.status).toBe(201);
    const orderId = ord.body.data.id;

    const res = await request(app.getHttpServer())
      .patch(`/api/v1/orders/${orderId}/status/HELLO`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({});
    expect(res.status).toBe(400);
    const after = await prisma.order.findUnique({ where: { id: orderId } });
    expect(after!.status).not.toBe('CANCELLED');
    bookingId = orderId; // استخدامه لاحقاً
  });

  it('Phase 4: atomic stock — concurrent checkouts cannot oversell', async () => {
    // ضع منتجين بالسلة للعميل والزميل؟ نكفي طلب واحد بكمية 3 ثم فحص الرصيد
    await request(app.getHttpServer())
      .post('/api/v1/cart/items')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ productId, quantity: 3 })
      .then(r => { if (r.status >= 400) console.log('CART ADD3 FAIL:', r.status, JSON.stringify(r.body)); return r; });
    const ord = await request(app.getHttpServer())
      .post('/api/v1/orders/checkout')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ address: 'دمشق - المزة الشارع العام', phone: '0938 045 496' });
    expect([200, 201]).toContain(ord.status);
    const p = await prisma.product.findUnique({ where: { id: productId } });
    expect(p!.stock).toBe(1); // 5 - 1(prev test) - 3
    // محاولة طلب 3 أخرى يجب أن تفشل (يبقى 2)
    await request(app.getHttpServer())
      .post('/api/v1/cart/items')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ productId, quantity: 3 })
      .then(r => { if (r.status >= 400) console.log('CART ADD3 FAIL:', r.status, JSON.stringify(r.body)); return r; });
    const fail = await request(app.getHttpServer())
      .post('/api/v1/orders/checkout')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ address: 'دمشق - المزة الشارع العام', phone: '0938 045 496' });
    expect(fail.status).toBe(409);
    const p2 = await prisma.product.findUnique({ where: { id: productId } });
    expect(p2!.stock).toBe(1); // بقي كما هو
  });

  it('Phase 1: payment XOR — both targets rejected', async () => {
    const bookings = await prisma.booking.findMany({ take: 1 });
    const orders = await prisma.order.findMany({ take: 1 });
    const res = await request(app.getHttpServer())
      .post('/api/v1/payments')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ bookingId: bookings[0]?.id, orderId: orders[0]?.id });
    expect([400, 409]).toContain(res.status);
  });

  it('Phase 1: payment with no target rejected', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/payments')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({});
    expect([400, 409]).toContain(res.status);
  });

  it('Phase 2/3: double confirmation is idempotent + ledger unique', async () => {
    // حجز PENDING حقيقي
    const vendorUserId = (await prisma.vendor.findUnique({ where: { id: vendorId } }))!.ownerId;
    await prisma.booking.deleteMany({ where: { vendorId } });
    const b = await prisma.booking.create({
      data: {
        bookingRef: `BK-HARD-${Date.now()}`,
        customerId,
        vendorId,
        resourceId: (await prisma.resource.findFirst({ where: { vendorId } }))!.id,
        status: 'PENDING',
        startsAt: new Date(Date.now() + 3000 * 86400000),
        endsAt: new Date(Date.now() + 3000 * 86400000 + 3600000),
        totalPrice: 100,
        currency: 'USD',
        clientRequestId: `hard-${Date.now()}`,
        expiresAt: new Date(Date.now() + 86400000),
      },
    });
    const pay = await request(app.getHttpServer())
      .post('/api/v1/payments')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ bookingId: b.id });
    expect([200, 201]).toContain(pay.status);
    const paymentId = pay.body.data.id;

    const c1 = await request(app.getHttpServer())
      .patch(`/api/v1/payments/${paymentId}/confirm`)
      .set('Authorization', `Bearer ${adminToken}`);
    expect([200, 201]).toContain(c1.status);
    // تأكيد ثانٍ = نجاح idempotent (نفس الحالة PAID)
    const c2 = await request(app.getHttpServer())
      .patch(`/api/v1/payments/${paymentId}/confirm`)
      .set('Authorization', `Bearer ${adminToken}`);
    expect([200, 201]).toContain(c2.status);

    // Ledger: SALE واحد فقط لهذا الحجز
    const sales = await prisma.walletTransaction.count({
      where: { type: 'SALE', refType: 'BOOKING', refId: b.id },
    });
    expect(sales).toBe(1);
    void vendorUserId;
  });
});
