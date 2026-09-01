import { PrismaClient, UserRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

const ROLE_NAMES: Record<string, { name: string; description: string }> = {
  CUSTOMER: {
    name: 'عميل',
    description: 'يحجز ويشتري ويقيّم الخدمات',
  },
  VENDOR: {
    name: 'مقدم خدمة',
    description: 'يدير خدماته وموارده وحجوزاته',
  },
  ADMIN: {
    name: 'مدير المنصة',
    description: 'صلاحيات كاملة على المنصة',
  },
};

const ROLE_PERMISSIONS: Record<string, string[]> = {
  CUSTOMER: [
    'profile:read',
    'profile:update',
    'bookings:read',
    'bookings:create',
    'bookings:cancel',
    'orders:read',
    'orders:create',
    'reviews:create',
    'favorites:manage',
    'chat:use',
  ],
  VENDOR: [
    'vendor:manage',
    'services:manage',
    'products:manage',
    'resources:manage',
    'availability:manage',
    'bookings:read',
    'bookings:decide',
    'orders:read',
    'orders:accept',
    'earnings:read',
    'reviews:read',
    'chat:use',
  ],
  ADMIN: [
    'users:read',
    'users:update',
    'users:suspend',
    'vendors:verify',
    'categories:manage',
    'roles:read',
    'bookings:read',
    'bookings:cancel',
    'orders:read',
    'refunds:manage',
    'commissions:manage',
    'payouts:manage',
    'reviews:moderate',
    'coupons:manage',
    'notifications:send',
    'settings:manage',
    'audit:read',
    'analytics:read',
  ],
};

function permName(key: string): string {
  const map: Record<string, string> = {
    'profile:read': 'قراءة الملف الشخصي',
    'profile:update': 'تحديث الملف الشخصي',
    'bookings:read': 'عرض الحجوزات',
    'bookings:create': 'إنشاء حجز',
    'bookings:cancel': 'إلغاء حجز',
    'bookings:decide': 'قبول/رفض الحجوزات',
    'orders:read': 'عرض الطلبات',
    'orders:create': 'إنشاء طلب',
    'orders:accept': 'قبول الطلبات',
    'reviews:create': 'إضافة تقييم',
    'reviews:read': 'عرض التقييمات',
    'reviews:moderate': 'إدارة التقييمات',
    'favorites:manage': 'إدارة المفضلة',
    'chat:use': 'المحادثة',
    'vendor:manage': 'إدارة المتجر',
    'services:manage': 'إدارة الخدمات',
    'products:manage': 'إدارة المنتجات',
    'resources:manage': 'إدارة الموارد',
    'availability:manage': 'إدارة التوفر',
    'earnings:read': 'عرض الأرباح',
    'users:read': 'عرض المستخدمين',
    'users:update': 'تعديل المستخدمين',
    'users:suspend': 'تعليق المستخدمين',
    'vendors:verify': 'توثيق مقدمي الخدمة',
    'categories:manage': 'إدارة التصنيفات',
    'roles:read': 'عرض الأدوار',
    'refunds:manage': 'إدارة الاسترجاعات',
    'commissions:manage': 'إدارة العمولات',
    'payouts:manage': 'إدارة الدفعات',
    'coupons:manage': 'إدارة الكوبونات',
    'notifications:send': 'إرسال الإشعارات',
    'settings:manage': 'إدارة الإعدادات',
    'audit:read': 'عرض سجل التدقيق',
    'analytics:read': 'عرض التحليلات',
  };
  return map[key] ?? key;
}

async function main(): Promise<void> {
  const rounds = Number(process.env.BCRYPT_ROUNDS ?? 12);

  for (const [roleKey, perms] of Object.entries(ROLE_PERMISSIONS)) {
    const role = await prisma.role.upsert({
      where: { key: roleKey },
      update: { isSystem: true, name: ROLE_NAMES[roleKey].name },
      create: {
        key: roleKey,
        name: ROLE_NAMES[roleKey].name,
        description: ROLE_NAMES[roleKey].description,
        isSystem: true,
      },
    });
    for (const key of perms) {
      await prisma.permission.upsert({
        where: { key },
        update: { roleId: role.id },
        create: { key, name: permName(key), roleId: role.id },
      });
    }
    console.log(`role ${roleKey}: ${perms.length} permissions ensured`);
  }

  const adminEmail = process.env.SEED_ADMIN_EMAIL;
  const adminPassword = process.env.SEED_ADMIN_PASSWORD;
  if (!adminEmail || !adminPassword) {
    throw new Error(
      'SEED_ADMIN_EMAIL and SEED_ADMIN_PASSWORD must be set (see .env.example). No insecure default.',
    );
  }
  await prisma.user.upsert({
    where: { email: adminEmail },
    update: {}, // never clobber an existing admin password
    create: {
      email: adminEmail,
      passwordHash: await bcrypt.hash(adminPassword, rounds),
      role: UserRole.ADMIN,
      profile: { create: { firstName: 'مدير', lastName: 'المنصة' } },
    },
  });
  console.log(`admin ensured: ${adminEmail}`);

  const demo = [
    {
      email: 'customer@marketplace.local',
      password: 'Customer@2026',
      role: UserRole.CUSTOMER,
      first: 'عميل',
      last: 'تجريبي',
    },
    {
      email: 'vendor@marketplace.local',
      password: 'Vendor@2026',
      role: UserRole.VENDOR,
      first: 'تاجر',
      last: 'تجريبي',
    },
  ];
  for (const d of demo) {
    await prisma.user.upsert({
      where: { email: d.email },
      update: {},
      create: {
        email: d.email,
        passwordHash: await bcrypt.hash(d.password, rounds),
        role: d.role,
        profile: { create: { firstName: d.first, lastName: d.last } },
      },
    });
    console.log(`demo user ensured: ${d.email}`);
  }

  // ===== Phase 2 seed: تصنيفات المنصة =====
  const categories = [
    { name: 'Venues', nameAr: 'قاعات ومناسبات', slug: 'venues', iconKey: 'venue', sortOrder: 1 },
    { name: 'Salons', nameAr: 'صالونات وتجميل', slug: 'salons', iconKey: 'salon', sortOrder: 2 },
    { name: 'Restaurants', nameAr: 'مطاعم', slug: 'restaurants', iconKey: 'restaurant', sortOrder: 3 },
    { name: 'Gifts', nameAr: 'هدايا وورد', slug: 'gifts', iconKey: 'gift', sortOrder: 4 },
    { name: 'Pools', nameAr: 'مسابح وشاليهات', slug: 'pools', iconKey: 'pool', sortOrder: 5 },
    { name: 'Photography', nameAr: 'تصوير', slug: 'photography', iconKey: 'camera', sortOrder: 6 },
  ];
  for (const c of categories) {
    await prisma.category.upsert({
      where: { slug: c.slug },
      update: {},
      create: c,
    });
  }
  console.log(`categories ensured: ${categories.length}`);

  // متجر تجريبي معتمد للتاجر التجريبي + مورد وجدول توفر
  const vendorUser = await prisma.user.findUnique({
    where: { email: 'vendor@marketplace.local' },
    select: { id: true },
  });
  const venues = await prisma.category.findUnique({ where: { slug: 'venues' }, select: { id: true } });
  if (vendorUser && venues) {
    const existing = await prisma.vendor.findUnique({
      where: { ownerId: vendorUser.id },
      select: { id: true },
    });
    if (!existing) {
      const vendor = await prisma.vendor.create({
        data: {
          ownerId: vendorUser.id,
          categoryId: venues.id,
          name: 'قصر الأمل للاحتفالات',
          slug: 'qasr-al-amal',
          description: 'قاعة أفراح فخمة تتسع لـ 500 ضيف مع خدمة ضيافة',
          status: 'APPROVED',
          address: 'دمشق - المزة',
          latitude: 33.5138,
          longitude: 36.2765,
          minPrice: 450,
        },
      });
      const hall = await prisma.resource.create({
        data: { vendorId: vendor.id, name: 'القاعة الرئيسية', type: 'VENUE', capacity: 500 },
      });
      await prisma.resource.create({
        data: { vendorId: vendor.id, name: 'الحديقة', type: 'VENUE', capacity: 200 },
      });
      // السبت والجمعة: 9:00-23:59 (بالدقائق)
      await prisma.availability.createMany({
        data: [
          { resourceId: hall.id, weekday: 5, startMin: 540, endMin: 1439 },
          { resourceId: hall.id, weekday: 6, startMin: 540, endMin: 1439 },
        ],
      });
      await prisma.service.create({
        data: {
          vendorId: vendor.id,
          categoryId: venues.id,
          name: 'حجز قاعة كاملة (أمسية)',
          description: 'من 9 صباحاً حتى منتصف الليل مع كراسي وتجهيزات',
          price: 450,
          durationMin: 900,
        },
      });
      console.log('demo vendor ensured: qasr-al-amal (APPROVED)');
    } else {
      console.log('demo vendor already present');
    }
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
