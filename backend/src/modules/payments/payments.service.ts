import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
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

  /** إنشاء دفعة manual على حجز أو طلب */
  async createManualPayment(actor: Actor, ref: { bookingId?: string; orderId?: string }) {
    if (!ref.bookingId && !ref.orderId) {
      throw new ConflictException('bookingId or orderId required');
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

  /** تأكيد الدفع (أدمن) — يضفي الحجز/الطلب ويؤثر على الـ Ledger */
  async confirm(paymentId: string, adminActor: Actor) {
    const payment = await this.prisma.payment.findUnique({
      where: { id: paymentId },
      select: { id: true, status: true, amount: true, currency: true, bookingId: true, orderId: true },
    });
    if (!payment) throw new NotFoundException('Payment not found');
    if (payment.status === PaymentStatus.PAID) return payment;

    return this.prisma.$transaction(async (tx) => {
      // خصم عمولة وتسجيل حصة البائع لكل من booking و order
      if (payment.bookingId) {
        const booking = await tx.booking.findUnique({
          where: { id: payment.bookingId },
          select: { id: true, vendorId: true, status: true, totalPrice: true },
        });
        if (!booking) throw new NotFoundException('Booking not found');
        await tx.booking.update({ where: { id: booking.id }, data: { status: 'CONFIRMED' } });
        await tx.bookingStatusHistory.create({
          data: { bookingId: booking.id, fromStatus: booking.status, toStatus: 'CONFIRMED', actorId: adminActor.id, reason: `PAYMENT_${payment.id}` },
        });
        await this.creditVendor(tx, booking.vendorId, booking.totalPrice, 'BOOKING', booking.id, payment.currency);
      }

      if (payment.orderId) {
        const order = await tx.order.findUnique({
          where: { id: payment.orderId },
          select: { id: true, vendorId: true, status: true, total: true },
        });
        if (!order) throw new NotFoundException('Order not found');
        await tx.order.update({ where: { id: order.id }, data: { status: 'CONFIRMED' } });
        await tx.orderStatusHistory.create({
          data: { orderId: order.id, fromStatus: order.status, toStatus: 'CONFIRMED', actorId: adminActor.id, reason: `PAYMENT_${payment.id}` },
        });
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
