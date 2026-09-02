import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, BookingStatus } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';

type Actor = { id: string; role: string };

const BOOKING_SELECT = {
  id: true,
  bookingRef: true,
  customerId: true,
  vendorId: true,
  resourceId: true,
  serviceId: true,
  status: true,
  startsAt: true,
  endsAt: true,
  totalPrice: true,
  currency: true,
  customerNote: true,
  expiresAt: true,
  createdAt: true,
  vendor: { select: { id: true, name: true, slug: true, imageUrl: true } },
  service: { select: { id: true, name: true } },
  resource: { select: { id: true, name: true } },
} satisfies Prisma.BookingSelect;

const BOOKING_REF_PREFIX = 'BK';

function generateBookingRef(): string {
  // BK-YYMMDD-XXXX — قابل للقراءة وفريد عملياً (6 base32)
  const d = new Date();
  const ymd = `${String(d.getFullYear()).slice(2)}${String(d.getMonth() + 1).padStart(2, '0')}${String(d.getDate()).padStart(2, '0')}`;
  const alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  let rand = '';
  for (let i = 0; i < 6; i++) {
    rand += alphabet[Math.floor(Math.random() * alphabet.length)];
  }
  return `${BOOKING_REF_PREFIX}-${ymd}-${rand}`;
}

/** الانتقالات المسموحة في آلة الحالات */
const ALLOWED_TRANSITIONS: Record<BookingStatus, BookingStatus[]> = {
  PENDING: [BookingStatus.CONFIRMED, BookingStatus.CANCELLED, BookingStatus.EXPIRED, BookingStatus.REJECTED],
  CONFIRMED: [BookingStatus.COMPLETED, BookingStatus.CANCELLED, BookingStatus.REJECTED],
  CANCELLED: [],
  REJECTED: [],
  COMPLETED: [],
  EXPIRED: [],
};

@Injectable()
export class BookingsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * إنشاء حجز — منع double booking بثلاث طبقات:
   *  1) transaction + SELECT ... FOR UPDATE على صف المورد (تصفيف المحاولات المتزامنة)
   *  2) فحص نوافذ التوفر + التداخل داخل نفس الـ tx
   *  3) قيد EXCLUDE gist في PostgreSQL (الشبكة الأخيرة حتى مع خطأ بالكود)
   * + Idempotency عبر (customerId, clientRequestId) الفريد.
   */
  async create(actor: Actor, dto: {
    vendorId: string;
    resourceId: string;
    serviceId?: string;
    startsAt: Date;
    endsAt: Date;
    customerNote?: string;
    clientRequestId?: string;
  }) {
    if (dto.startsAt >= dto.endsAt) {
      throw new ConflictException('Start time must be before end time');
    }
    if (dto.startsAt.getTime() < Date.now() - 60_000) {
      throw new ConflictException('Cannot book in the past');
    }

    // Idempotency: نفس الطلب من نفس العميل يعيد نفس الحجز
    if (dto.clientRequestId) {
      const existing = await this.prisma.booking.findUnique({
        where: { customerId_clientRequestId: { customerId: actor.id, clientRequestId: dto.clientRequestId } },
        select: BOOKING_SELECT,
      });
      if (existing) return existing;
    }

    const vendor = await this.prisma.vendor.findUnique({
      where: { id: dto.vendorId },
      select: { id: true, status: true },
    });
    if (!vendor || vendor.status !== 'APPROVED') {
      throw new NotFoundException('Vendor not found or not accepting bookings');
    }

    const resource = await this.prisma.resource.findUnique({
      where: { id: dto.resourceId },
      select: { id: true, vendorId: true, isActive: true },
    });
    if (!resource || !resource.isActive) throw new NotFoundException('Resource not available');
    if (resource.vendorId !== dto.vendorId) {
      throw new ConflictException('Resource does not belong to this vendor');
    }

    let servicePrice = 0;
    let currency = 'USD';
    if (dto.serviceId) {
      const service = await this.prisma.service.findUnique({
        where: { id: dto.serviceId },
        select: { vendorId: true, price: true, currency: true, isActive: true },
      });
      if (!service || !service.isActive || service.vendorId !== dto.vendorId) {
        throw new NotFoundException('Service not available');
      }
      servicePrice = service.price;
      currency = service.currency;
    }

    try {
      return await this.prisma.$transaction(
        async (tx) => {
          // (1) قفل صف المورد — كل المحاولات المتزامنة على نفس المورد تتصفّف هنا
          await tx.$queryRaw`SELECT id FROM "resources" WHERE id = ${dto.resourceId}::uuid FOR UPDATE`;

          // (2) فحص توفر اليوم/الوقت — بتوقيت البائع المحلي (PHASE 10) وليس UTC
          const vendor = await tx.vendor.findUnique({
            where: { id: dto.vendorId },
            select: { timezone: true },
          });
          const tz = vendor?.timezone ?? 'UTC';
          const fmt = (d: Date) => {
            const p = new Intl.DateTimeFormat('en-US', { timeZone: tz, hour12: false, weekday: 'short', hour: '2-digit', minute: '2-digit' });
            const parts = Object.fromEntries(p.formatToParts(d).map((x) => [x.type, x.value]));
            const wd = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(parts.weekday);
            let h = parseInt(parts.hour, 10);
            if (h === 24) h = 0;
            return { weekday: wd, minutes: h * 60 + parseInt(parts.minute, 10) };
          };
          const start = dto.startsAt;
          const sLocal = fmt(start);
          const end = dto.endsAt;
          const eLocal = fmt(end);
          const weekday = sLocal.weekday;
          const startMin = sLocal.minutes;
          const endMin = eLocal.minutes;
          // منتصف الليل بتوقيت البائع: تغيّر اليوم المحلي بين البداية والنهاية
          const dayIndex = (d: Date) => {
            // رقم اليوم بتوقيت البائع: نزع الإزاحة ثم قسّم
            const off = new Date(d.toLocaleString('en-US', { timeZone: tz })).getTime() - new Date(d.toLocaleString('en-US', { timeZone: 'UTC' })).getTime();
            return Math.floor((d.getTime() + off) / 86400000);
          };
          if (dayIndex(start) !== dayIndex(end)) {
            throw new ConflictException('Booking must not cross midnight');
          }
          const windowCount = await tx.availability.count({
            where: {
              resourceId: dto.resourceId,
              weekday,
              startMin: { lte: startMin },
              endMin: { gte: endMin },
            },
          });
          if (windowCount === 0) {
            throw new ConflictException('Requested time is outside working hours');
          }

          // (2b) فحص التداخل مع حجوزات نشطة (PENDING/CONFIRMED)
          const overlap = await tx.booking.count({
            where: {
              resourceId: dto.resourceId,
              status: { in: [BookingStatus.PENDING, BookingStatus.CONFIRMED] },
              startsAt: { lt: dto.endsAt },
              endsAt: { gt: dto.startsAt },
            },
          });
          if (overlap > 0) {
            throw new ConflictException('Time slot already booked');
          }

          const now = new Date();
          const booking = await tx.booking.create({
            data: {
              bookingRef: generateBookingRef(),
              customerId: actor.id,
              vendorId: dto.vendorId,
              resourceId: dto.resourceId,
              serviceId: dto.serviceId,
              status: BookingStatus.PENDING,
              startsAt: dto.startsAt,
              endsAt: dto.endsAt,
              totalPrice: servicePrice,
              currency,
              customerNote: dto.customerNote,
              clientRequestId: dto.clientRequestId,
              expiresAt: new Date(now.getTime() + 15 * 60 * 1000),
            },
            select: BOOKING_SELECT,
          });

          if (servicePrice > 0) {
            await tx.bookingItem.create({
              data: {
                bookingId: booking.id,
                kind: 'SERVICE',
                refId: dto.serviceId,
                name: 'حجز خدمة',
                price: servicePrice,
                quantity: 1,
              },
            });
          }

          await tx.bookingStatusHistory.create({
            data: {
              bookingId: booking.id,
              fromStatus: null,
              toStatus: BookingStatus.PENDING,
              actorId: actor.id,
              reason: 'CREATED',
            },
          });

          return booking;
        },
        { isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted },
      );
    } catch (e) {
      // (3) قيد EXCLUDE في PostgreSQL = 23P01
      if (
        e instanceof Prisma.PrismaClientKnownRequestError ||
        (e as { code?: string })?.code === 'P2010' ||
        (e as { code?: string })?.code === '23P01'
      ) {
        const msg = String((e as { message?: string }).message ?? '');
        if (msg.includes('no_double_booking') || msg.includes('23P01')) {
          throw new ConflictException('Time slot already booked');
        }
      }
      throw e;
    }
  }

  async listMine(actor: Actor, page = 1, limit = 20) {
    const [total, data] = await this.prisma.$transaction([
      this.prisma.booking.count({ where: { customerId: actor.id } }),
      this.prisma.booking.findMany({
        where: { customerId: actor.id },
        select: BOOKING_SELECT,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    return {
      success: true as const,
      data,
      message: null,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  /** قائمة حجوزات متجر البائع (مع فلتر الحالة) */
  async listForVendor(actor: Actor, status: BookingStatus | undefined, page = 1, limit = 20) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { ownerId: actor.id },
      select: { id: true },
    });
    if (!vendor && actor.role !== 'ADMIN') {
      throw new NotFoundException('You have no vendor profile');
    }
    const where: Prisma.BookingWhereInput = {
      ...(vendor && actor.role !== 'ADMIN' ? { vendorId: vendor.id } : {}),
      ...(status ? { status } : {}),
    };
    const [total, data] = await this.prisma.$transaction([
      this.prisma.booking.count({ where }),
      this.prisma.booking.findMany({
        where,
        select: {
          ...BOOKING_SELECT,
          customer: { select: { profile: { select: { firstName: true, lastName: true } } } },
        },
        orderBy: { startsAt: 'asc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    return {
      success: true as const,
      data,
      message: null,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  async getOne(actor: Actor, bookingId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      select: {
        ...BOOKING_SELECT,
        items: true,
        statusHistory: { orderBy: { createdAt: 'asc' } },
        vendor: { select: { id: true, name: true, slug: true } },
        resource: { select: { id: true, name: true } },
      },
    });
    if (!booking) throw new NotFoundException('Booking not found');

    const isCustomer = booking.customerId === actor.id;
    const isVendorOwner =
      actor.role === 'VENDOR' &&
      (await this.prisma.vendor.findUnique({ where: { id: booking.vendorId }, select: { ownerId: true } }))
        ?.ownerId === actor.id;
    if (!isCustomer && !isVendorOwner && actor.role !== 'ADMIN') {
      throw new ForbiddenException('Not your booking');
    }
    return this.expireIfNeeded(booking);
  }

  /** إلغاء من العميل — مسموح فقط قبل البد ولما تكون الحالة تسمح */
  async cancel(actor: Actor, bookingId: string, reason?: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      select: { customerId: true, status: true, startsAt: true },
    });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.customerId !== actor.id && actor.role !== 'ADMIN') {
      throw new ForbiddenException('Not your booking');
    }
    await this.transition(bookingId, booking.status, BookingStatus.CANCELLED, actor.id, reason ?? 'CUSTOMER_CANCELLED');
    return this.getOne(actor, bookingId);
  }

  /** قبول/رفض من البائع */
  async decide(actor: Actor, bookingId: string, decision: 'CONFIRMED' | 'REJECTED', reason?: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      select: { status: true, vendorId: true },
    });
    if (!booking) throw new NotFoundException('Booking not found');
    const vendor = await this.prisma.vendor.findUnique({
      where: { id: booking.vendorId },
      select: { ownerId: true },
    });
    if (vendor?.ownerId !== actor.id && actor.role !== 'ADMIN') {
      throw new ForbiddenException('Not your vendor booking');
    }
    await this.transition(bookingId, booking.status, decision, actor.id, reason);
    // إشعار للعميل عند تغيير حالة حجزه (لا يعطل العملية إن فشل)
    const bookingFull = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      select: { customerId: true, bookingRef: true },
    });
    if (bookingFull) {
      const titles: Record<string, string> = {
        CONFIRMED: 'تم تأكيد حجزك',
        REJECTED: 'تم رفض حجزك',
      };
      await this.prisma.notification.create({
        data: {
          userId: bookingFull.customerId,
          type: `BOOKING_${decision}`,
          title: titles[decision],
          body: `الحجز ${bookingFull.bookingRef}`,
          refType: 'BOOKING',
          refId: bookingId,
        },
      }).catch(() => undefined);
    }
    return this.prisma.booking.findUnique({ where: { id: bookingId }, select: BOOKING_SELECT });
  }

  /** إنهاء الخدمة من البائع بعد التنفيذ */
  async complete(actor: Actor, bookingId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      select: { status: true, vendorId: true },
    });
    if (!booking) throw new NotFoundException('Booking not found');
    const vendor = await this.prisma.vendor.findUnique({
      where: { id: booking.vendorId },
      select: { ownerId: true },
    });
    if (vendor?.ownerId !== actor.id && actor.role !== 'ADMIN') {
      throw new ForbiddenException('Not your vendor booking');
    }
    await this.transition(bookingId, booking.status, BookingStatus.COMPLETED, actor.id, 'SERVICE_COMPLETED');
    return this.prisma.booking.findUnique({ where: { id: bookingId }, select: BOOKING_SELECT });
  }

  private async transition(
    bookingId: string,
    from: BookingStatus,
    to: BookingStatus,
    actorId: string,
    reason?: string,
  ) {
    if (!ALLOWED_TRANSITIONS[from].includes(to)) {
      throw new ConflictException(`Cannot transition from ${from} to ${to}`);
    }
    // القفل هنا يمنع سباق التغيير المتوازي لنفس الحجز
    await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM "bookings" WHERE id = ${bookingId}::uuid FOR UPDATE`;
      const updated = await tx.booking.updateMany({
        where: { id: bookingId, status: from },
        data: { status: to },
      });
      if (updated.count === 0) {
        throw new ConflictException('Booking status changed concurrently');
      }
      await tx.bookingStatusHistory.create({
        data: { bookingId, fromStatus: from, toStatus: to, actorId, reason },
      });
    });
  }

  /** EXPIRE عند القراءة: PENDING تجاوز وقت الانتهاء الصحي */
  private expireIfNeeded<T extends { status: BookingStatus; expiresAt: Date | null }>(booking: T): T {
    if (
      booking.status === BookingStatus.PENDING &&
      booking.expiresAt &&
      booking.expiresAt.getTime() <= Date.now()
    ) {
      void this.prisma.booking
        .updateMany({
          where: { id: (booking as unknown as { id: string }).id, status: BookingStatus.PENDING },
          data: { status: BookingStatus.EXPIRED },
        })
        .catch(() => undefined);
      return { ...booking, status: BookingStatus.EXPIRED };
    }
    return booking;
  }
}
