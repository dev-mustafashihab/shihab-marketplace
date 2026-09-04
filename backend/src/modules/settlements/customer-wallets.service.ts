import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PaymentStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';
import { WalletsService } from './wallets.service';
import { SettingsService } from '../settings/settings.service';

type Tx = Prisma.TransactionClient;
type Actor = { id: string; role: string };

/**
 * محافظ الزبائن (أساسية):
 * - الرصيد يُشحن من الأدمن الآن، ومن وكيل شحن لاحقاً (نفس الدالة مع دور AGENT).
 * - دفع الحجوزات من الرصيد ذرياً: خصم الزبون + دفعة PAID + قيد البائع + تأكيد الحجز.
 */
@Injectable()
export class CustomerWalletsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly wallets: WalletsService,
    private readonly settings: SettingsService,
  ) {}

  /** رصيدي + آخر الحركات — المحفظة تُنشأ عند أول استخدام برصيد 0. */
  async getMine(userId: string, page = 1, limit = 20) {
    const wallet = await this.prisma.customerWallet.upsert({
      where: { userId },
      update: {},
      create: { userId, currency: 'USD' },
    });
    const [total, txs] = await this.prisma.$transaction([
      this.prisma.customerWalletTx.count({ where: { walletId: wallet.id } }),
      this.prisma.customerWalletTx.findMany({
        where: { walletId: wallet.id },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    return {
      success: true as const,
      data: {
        wallet: { id: wallet.id, balance: wallet.balance, currency: wallet.currency },
        transactions: txs,
      },
      message: null,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  /** شحن رصيد زبون — أدمن فقط الآن (وكيل الشحن لاحقاً بنفس الدالة). */
  async topup(admin: Actor, dto: { userId: string; amount: number; note?: string }) {
    if (admin.role !== 'ADMIN') {
      throw new ForbiddenException('Topup is restricted to admins for now');
    }
    const amount = Math.trunc(Number(dto.amount));
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new BadRequestException('Amount must be a positive integer');
    }
    if (amount > 1000000000) {
      throw new BadRequestException('Amount too large');
    }
    const user = await this.prisma.user.findUnique({
      where: { id: dto.userId },
      select: { id: true },
    });
    if (!user) throw new NotFoundException('User not found');
    const wallet = await this.prisma.customerWallet.upsert({
      where: { userId: dto.userId },
      update: {},
      create: { userId: dto.userId, currency: 'USD' },
    });
    const updated = await this.prisma.$transaction(async (tx) => {
      const w = await tx.customerWallet.update({
        where: { id: wallet.id },
        data: { balance: { increment: amount } },
      });
      await tx.customerWalletTx.create({
        data: {
          walletId: wallet.id,
          type: 'TOPUP',
          amount,
          currency: w.currency,
          note: dto.note ?? `TOPUP_BY_ADMIN`,
        },
      });
      return w;
    });
    return {
      success: true as const,
      data: { balance: updated.balance, currency: updated.currency },
      message: null,
    };
  }

  /** دفع حجز من رصيد الزبون — عملية ذرية واحدة. */
  async payBooking(user: Actor, bookingId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      select: {
        id: true,
        customerId: true,
        vendorId: true,
        status: true,
        totalPrice: true,
        currency: true,
      },
    });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.customerId !== user.id && user.role !== 'ADMIN') {
      throw new ForbiddenException('Not your booking');
    }
    if (booking.status !== 'PENDING' && booking.status !== 'CONFIRMED') {
      throw new ConflictException(`Booking is ${booking.status} — cannot pay`);
    }
    if (booking.totalPrice <= 0) {
      throw new BadRequestException('Nothing to pay for this booking');
    }
    return this.prisma.$transaction(async (tx: Tx) => {
      // قفل صف المحفظة ضد الدفع المزدوج المتزامن
      let wallet = await tx.customerWallet.findUnique({
        where: { userId: booking.customerId },
      });
      if (!wallet) {
        wallet = await tx.customerWallet.create({
          data: { userId: booking.customerId, currency: booking.currency },
        });
      } else {
        const locked = await tx.$queryRaw<Array<{ balance: number; currency: string }>>`
          SELECT balance, currency FROM customer_wallets WHERE id = ${wallet.id}::uuid FOR UPDATE`;
        wallet = { ...wallet, balance: locked[0].balance, currency: locked[0].currency };
      }
      if (wallet.currency !== booking.currency) {
        throw new ConflictException('Wallet currency mismatch');
      }
      if (wallet.balance < booking.totalPrice) {
        throw new ConflictException('Insufficient wallet balance');
      }
      const w = await tx.customerWallet.update({
        where: { id: wallet.id },
        data: { balance: { decrement: booking.totalPrice } },
      });
      await tx.customerWalletTx.create({
        data: {
          walletId: wallet.id,
          type: 'PAYMENT',
          amount: -booking.totalPrice,
          currency: wallet.currency,
          refType: 'BOOKING',
          refId: booking.id,
        },
      });
      const payment = await tx.payment.create({
        data: {
          bookingId: booking.id,
          provider: 'WALLET',
          status: PaymentStatus.PAID,
          amount: booking.totalPrice,
          currency: booking.currency,
          providerEventId: `WALLET-${Date.now().toString(36).toUpperCase()}`,
        },
      });
      if (booking.status !== 'CONFIRMED') {
        await tx.booking.update({
          where: { id: booking.id },
          data: { status: 'CONFIRMED' },
        });
        await tx.bookingStatusHistory.create({
          data: {
            bookingId: booking.id,
            fromStatus: booking.status,
            toStatus: 'CONFIRMED',
            actorId: user.id,
            reason: `PAYMENT_${payment.id}`,
          },
        });
      }
      // قيد البائع: إجمالي + عمولة (نفس منطق تأكيد الدفع اليدوي)
      const fin = await this.settings.getFinancial();
      const commission = Math.round((booking.totalPrice * fin.commissionPercent) / 100);
      await this.wallets.postTransaction(tx, {
        vendorId: booking.vendorId,
        type: 'SALE',
        amount: booking.totalPrice,
        currency: booking.currency,
        refType: 'BOOKING',
        refId: booking.id,
        note: 'GROSS',
      });
      if (commission > 0) {
        await this.wallets.postTransaction(tx, {
          vendorId: booking.vendorId,
          type: 'COMMISSION',
          amount: commission,
          currency: booking.currency,
          refType: 'BOOKING',
          refId: booking.id,
          note: `COMMISSION_${fin.commissionPercent}%`,
        });
      }
      return {
        success: true as const,
        data: {
          paymentId: payment.id,
          paid: booking.totalPrice,
          balance: w.balance,
          currency: w.currency,
        },
        message: null,
      };
    });
  }
}
