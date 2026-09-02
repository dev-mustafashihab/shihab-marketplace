import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PaymentStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';
import { WalletsService } from '../settlements/wallets.service';
import { SettingsService } from '../settings/settings.service';

type Actor = { id: string; role: string };

interface PaymentProviderResult {
  provider: string;
  providerEventId: string;
}

/**
 * Manual payment provider: تحويل/كاش يؤكده الأدمن.
 * أي مزود خارجي مستقبلاً = Implementation جديدة لنفس الواجهة.
 */
@Injectable()
export class PaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly wallets: WalletsService,
    private readonly settings: SettingsService,
  ) {}

  /** إنشاء دفعة manual على حجز أو طلب — XOR صارم (PHASE 1) */
  async createManualPayment(actor: Actor, ref: { bookingId?: string; orderId?: string }) {
    const hasBooking = Boolean(ref.bookingId);
    const hasOrder = Boolean(ref.orderId);
    if (hasBooking === hasOrder) {
      // PHASE 1: يجب استهداف واحد فقط — كلاهما أو ولا شيء مرفوض (تحقق مستقل عن DTO)
      throw new BadRequestException('Payment must reference exactly one target: bookingId XOR orderId');
    }
    const target = ref.bookingId
      ? await this.prisma.booking.findUnique({ where: { id: ref.bookingId }, select: { id: true, customerId: true, totalPrice: true, currency: true, status: true } })
      : await this.prisma.order.findUnique({ where: { id: ref.orderId! }, select: { id: true, customerId: true, total: true, currency: true, status: true } });
    if (!target) throw new NotFoundException('Target not found');
    if (target.customerId !== actor.id && actor.role !== 'ADMIN') {
      throw new ForbiddenException('Not your payment target');
    }
    const amount = 'totalPrice' in target ? target.totalPrice : target.total;

    const payment = await this.prisma.payment.create({
      data: {
        bookingId: ref.bookingId,
        orderId: ref.orderId,
        provider: 'MANUAL',
        status: PaymentStatus.PENDING,
        amount,
        currency: target.currency,
      },
    });
    return payment;
  }

  /**
   * تأكيد الدفع (أدمن) — PHASE 2: قفل ذري FOR UPDATE يمنع التأكيد المزدوج المتزامن.
   * PHASE 1: التحقق من حالة الهدف والمبلغ والعملة مستقل عن DTO.
   * PHASE 3: state machine صريح PENDING → PAID فقط.
   */
  async confirm(paymentId: string, adminActor: Actor) {
    return this.prisma.$transaction(async (tx) => {
      // قفل صف الدفعة ذرياً — الطلبات المتزامنة تنتظر ثم ترى الحالة الجديدة
      const locked = await tx.$queryRaw<Array<{ id: string; status: PaymentStatus; amount: number; currency: string; booking_id: string | null; order_id: string | null }>>`
        SELECT id, status, amount, currency, booking_id, order_id
        FROM payments WHERE id = ${paymentId}::uuid FOR UPDATE`;
      const payment = locked[0];
      if (!payment) throw new NotFoundException('Payment not found');

      // PHASE 3: PENDING → PAID فقط (idempotent-success لو PAID سابقاً)
      if (payment.status === PaymentStatus.PAID) {
        return this.prisma.payment.findUnique({ where: { id: payment.id } });
      }
      if (payment.status !== PaymentStatus.PENDING) {
        throw new ConflictException(`Cannot confirm payment in state ${payment.status}`);
      }

      // PHASE 1: XOR صارم على الهدف
      const targetCount = Number(Boolean(payment.booking_id)) + Number(Boolean(payment.order_id));
      if (targetCount !== 1) {
        throw new ConflictException('Payment must reference exactly one target');
      }

      if (payment.booking_id) {
        const booking = await tx.booking.findUnique({
          where: { id: payment.booking_id },
          select: { id: true, vendorId: true, status: true, totalPrice: true, currency: true },
        });
        if (!booking) throw new NotFoundException('Booking not found');
        // PHASE 1.4: لا تأكيد لحجز ملغي/مرفوض/منتهي
        if (!['PENDING', 'CONFIRMED'].includes(booking.status)) {
          throw new ConflictException(`Cannot confirm payment for booking in state ${booking.status}`);
        }
        // PHASE 1.2: المبلغ والعملة من الخادم فقط
        if (payment.amount !== booking.totalPrice || payment.currency !== booking.currency) {
          throw new ConflictException('Payment amount/currency mismatch with booking');
        }
        if (booking.status !== 'CONFIRMED') {
          await tx.booking.update({ where: { id: booking.id }, data: { status: 'CONFIRMED' } });
          await tx.bookingStatusHistory.create({
            data: { bookingId: booking.id, fromStatus: booking.status, toStatus: 'CONFIRMED', actorId: adminActor.id, reason: `PAYMENT_${payment.id}` },
          });
        }
        await this.creditVendor(tx, booking.vendorId, booking.totalPrice, 'BOOKING', booking.id, payment.currency);
      }

      if (payment.order_id) {
        const order = await tx.order.findUnique({
          where: { id: payment.order_id },
          select: { id: true, vendorId: true, status: true, total: true, currency: true },
        });
        if (!order) throw new NotFoundException('Order not found');
        // PHASE 1.5: لا إحياء طلب ملغي/مسترجع/مرفوض
        if (!['PENDING', 'CONFIRMED', 'PREPARING', 'READY', 'OUT_FOR_DELIVERY'].includes(order.status)) {
          throw new ConflictException(`Cannot confirm payment for order in state ${order.status}`);
        }
        if (payment.amount !== order.total || payment.currency !== order.currency) {
          throw new ConflictException('Payment amount/currency mismatch with order');
        }
        if (order.status !== 'CONFIRMED') {
          await tx.order.update({ where: { id: order.id }, data: { status: 'CONFIRMED' } });
          await tx.orderStatusHistory.create({
            data: { orderId: order.id, fromStatus: order.status, toStatus: 'CONFIRMED', actorId: adminActor.id, reason: `PAYMENT_${payment.id}` },
          });
        }
        await this.creditVendor(tx, order.vendorId, order.total, 'ORDER', order.id, payment.currency);
      }

      return tx.payment.update({
        where: { id: payment.id },
        data: { status: PaymentStatus.PAID, providerEventId: `MANUAL-${payment.id.slice(0, 8)}` },
      });
    });
  }

  /** SALE (إجمالي) ثم COMMISSION (العمولة) — صافي البائع = balance مشتق */
  private async creditVendor(tx: Prisma.TransactionClient, vendorId: string, gross: number, refType: string, refId: string, currency: string) {
    const fin = await this.settings.getFinancial();
    const commission = Math.round((gross * fin.commissionPercent) / 100);
    await this.wallets.postTransaction(tx, { vendorId, type: 'SALE', amount: gross, currency, refType, refId, note: 'GROSS' });
    if (commission > 0) {
      await this.wallets.postTransaction(tx, { vendorId, type: 'COMMISSION', amount: commission, currency, refType, refId, note: `COMMISSION_${fin.commissionPercent}%` });
    }
  }

  listAll(page = 1, limit = 20) {
    return this.prisma.$transaction([
      this.prisma.payment.count(),
      this.prisma.payment.findMany({
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
  }
}
