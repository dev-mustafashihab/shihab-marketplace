// تعبئة بيانات واقعية للبائعين الفارغين — كل شاشة التطبيق تملك ما تعرضه
const { PrismaClient } = require('@prisma/client');
const p = new PrismaClient();

const DAY_MIN = (h: number, m = 0) => h * 60 + m;

async function main() {
  // ===== استوديو الضياء (تصوير): موارد مصورين + خدمات تصوير + توفر =====
  const studio = await p.vendor.findUnique({ where: { id: '464a1242-e696-4211-8720-13a3cad5ba98' } });
  if (studio) {
    const existingRes = await p.resource.count({ where: { vendorId: studio.id } });
    if (existingRes === 0) {
      const photog1 = await p.resource.create({ data: { vendorId: studio.id, name: 'مصور مناسبات 1', type: 'STAFF', capacity: 1, isActive: true } });
      const photog2 = await p.resource.create({ data: { vendorId: studio.id, name: 'مصور مناسبات 2', type: 'STAFF', capacity: 1, isActive: true } });
      await p.availability.createMany({
        data: [6, 0, 1, 2, 3, 4].flatMap((wd) => ([
          { resourceId: photog1.id, weekday: wd, startMin: DAY_MIN(9), endMin: DAY_MIN(21) },
          { resourceId: photog2.id, weekday: wd, startMin: DAY_MIN(9), endMin: DAY_MIN(21) },
        ])),
      });
    }
    const existingSvc = await p.service.count({ where: { vendorId: studio.id } });
    if (existingSvc === 0) {
      await p.service.createMany({
        data: [
          { vendorId: studio.id, categoryId: 'd017eac9-dd5d-43b8-bd7a-9735ab71e3be', name: 'جلسة تصوير خارجي', description: 'جلسة تصوير احترافية ساعتين مع 30 صورة معدلة', price: 50, currency: 'USD', durationMin: 120, isActive: true },
          { vendorId: studio.id, categoryId: 'd017eac9-dd5d-43b8-bd7a-9735ab71e3be', name: 'تصوير حفلة كاملة', description: 'تغطية كاملة 4 ساعات + ألبوم رقمي + فيديو قصير', price: 150, currency: 'USD', durationMin: 240, isActive: true },
        ],
      });
      console.log('studio: services OK');
    }
  }

  // ===== متجر الهدايا الذهبي (منتجات فقط — لا موارد حجز، لكن طلبات تعمل) =====
  const gifts = await p.vendor.findUnique({ where: { id: 'e9154971-4bcc-478d-b8be-f68c28fd3b0c' } });
  if (gifts) {
    const existing = await p.product.count({ where: { vendorId: gifts.id } });
    if (existing === 0) {
      await p.product.createMany({
        data: [
          { vendorId: gifts.id, name: 'بوكيه ورد أحمر فاخر', description: '24 وردة هولندية مع تغليف هدايا', price: 35, currency: 'USD', stock: 20, isActive: true },
          { vendorId: gifts.id, name: 'شوكولا سويسرية 500غ', description: 'علبة شوكولا فاخرة مع بطاقة إهداء', price: 18, currency: 'USD', stock: 30, isActive: true },
          { vendorId: gifts.id, name: 'عطر شرقي فاخر 100مل', description: 'عطر عود ملكي — هدية مناسبات', price: 60, currency: 'USD', stock: 15, isActive: true },
          { vendorId: gifts.id, name: 'سلة هدايا مناسبات', description: 'شوكولا + ورد + عطر بتغليف مميز', price: 85, currency: 'USD', stock: 10, isActive: true },
        ],
      });
      console.log('gifts: products OK');
    }
  }

  // ===== صالون النور: خدمات + توفر للكرسي =====
  const salon = await p.vendor.findUnique({ where: { id: '1399046a-4c45-4101-80a5-bb4f5e08ab1e' } });
  if (salon) {
    const existing = await p.service.count({ where: { vendorId: salon.id } });
    if (existing === 0) {
      await p.service.createMany({
        data: [
          { vendorId: salon.id, name: 'حلاقة رجالية كلاسيكية', description: 'قص + تهذيب لحية + غسيل', categoryId: '1f968b6d-11ac-4f9e-b1c7-086a5197dc1c', price: 8, currency: 'USD', durationMin: 45, isActive: true },
          { vendorId: salon.id, name: 'باكج العريس', description: 'حلاقة + عناية بالبشرة + مساج رأس', categoryId: '1f968b6d-11ac-4f9e-b1c7-086a5197dc1c', price: 25, currency: 'USD', durationMin: 120, isActive: true },
          { vendorId: salon.id, name: 'صبغة وتمويج', description: 'صبغة ألوان فاخرة', categoryId: '1f968b6d-11ac-4f9e-b1c7-086a5197dc1c', price: 15, currency: 'USD', durationMin: 90, isActive: true },
        ],
      });
      console.log('salon: services OK');
    }
    const chair = await p.resource.findFirst({ where: { vendorId: salon.id, name: 'كرسي حلاقة 1' } });
    if (chair) {
      const av = await p.availability.count({ where: { resourceId: chair.id } });
      if (av === 0) {
        await p.availability.createMany({
          data: [6, 0, 1, 2, 3, 4].map((wd) => ({ resourceId: chair.id, weekday: wd, startMin: DAY_MIN(10), endMin: DAY_MIN(20) })),
        });
        console.log('salon: availability OK');
      }
    }
  }

  // ===== قصر الأمل: خدمة إضافية + توفر الحديقة إن ناقص =====
  const hall = await p.vendor.findUnique({ where: { id: '420a7096-cf93-4c30-bd1c-8d9942cc430e' } });
  if (hall) {
    const svc = await p.service.count({ where: { vendorId: hall.id } });
    if (svc === 0) {
      await p.service.createMany({
        data: [
          { vendorId: hall.id, name: 'حجز قاعة رئيسية ليلة كاملة', description: 'قاعة تتسع 500 ضيف مع ضيافة', categoryId: 'db6f2078-5792-4126-81ba-6157e6e1a050', price: 450, currency: 'USD', durationMin: 360, isActive: true },
          { vendorId: hall.id, name: 'حجز الحديقة نهاراً', description: 'حديقة مفتوحة 4 ساعات مع إضاءة', categoryId: 'db6f2078-5792-4126-81ba-6157e6e1a050', price: 200, currency: 'USD', durationMin: 240, isActive: true },
        ],
      });
      console.log('hall: services OK');
    }
  }

  console.log('SEED FILL DONE');
}

main().catch((e) => { console.error(e); process.exit(1); }).finally(() => p.$disconnect());
