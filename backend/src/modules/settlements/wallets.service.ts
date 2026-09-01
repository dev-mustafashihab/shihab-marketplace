import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, WalletTxType } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';

type Tx = Prisma.TransactionClient;

/**
 * Ledger: كل حركة مالية سطر مستقل. الرصيد مشتق من مجموع الأسطر
 * ويُثبت كـ snapshot على المحفظة داخل نفس الـ transaction.
 */
@Injectable()
export class WalletsService {
  constructor(private readonly prisma: PrismaService) {}

  private async ensureWallet(tx: Tx, vendorId: string, currency = 'USD') {
    const existing = await tx.wallet.findUnique({ where: { vendorId } });
    if (existing) {
      if (existing.currency !== currency) {
        throw new ConflictException('Wallet currency mismatch');
      }
      return existing;
    }
    return tx.wallet.create({ data: { vendorId, currency } });
  }

  /** إضافة حركة وتحديث الرصيد الذري — يُستدعى داخل transaction فقط */
  async postTransaction(
    tx: Tx,
    data: {
      vendorId: string;
      type: WalletTxType;
      amount: number; // موجب دائماً؛ الاتجاه يحدده النوع
      currency?: string;
      refType?: string;
      refId?: string;
      note?: string;
    },
  ): Promise<{ newBalance: number }> {
    const sign = data.type === 'SALE' || data.type === 'ADJUSTMENT' ? 1 : -1;
    if (data.amount <= 0) throw new ConflictException('Amount must be positive');

    const wallet = await this.ensureWallet(tx, data.vendorId, data.currency ?? 'USD');

    const delta = sign * data.amount;
    // القفل يمنع تحديثين متزامنين لنفس الرصيد
    await tx.$queryRaw`SELECT id FROM "wallets" WHERE id = ${wallet.id}::uuid FOR UPDATE`;
    const updated = await tx.wallet.update({
      where: { id: wallet.id },
      data: { balance: { increment: delta } },
    });
    if (updated.balance < 0) {
      throw new ConflictException('Insufficient wallet balance');
    }

    await tx.walletTransaction.create({
      data: {
        walletId: wallet.id,
        type: data.type,
        amount: data.amount,
        currency: data.currency ?? 'USD',
        refType: data.refType,
        refId: data.refId,
        note: data.note,
      },
    });

    return { newBalance: updated.balance };
  }

  async getWalletWithTransactions(vendorId: string, page = 1, limit = 20) {
    const wallet = await this.prisma.wallet.findUnique({
      where: { vendorId },
      include: { vendor: { select: { id: true, name: true, slug: true } } },
    });
    if (!wallet) throw new NotFoundException('Wallet not found yet');
    const [total, transactions] = await this.prisma.$transaction([
      this.prisma.walletTransaction.count({ where: { walletId: wallet.id } }),
      this.prisma.walletTransaction.findMany({
        where: { walletId: wallet.id },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    return {
      success: true as const,
      data: { wallet: { id: wallet.id, balance: wallet.balance, currency: wallet.currency }, transactions },
      message: null,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  /** للبائع عبر owner_id → vendor_id */
  async getWalletForOwner(ownerUserId: string, page = 1, limit = 20) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { ownerId: ownerUserId },
      select: { id: true },
    });
    if (!vendor) throw new NotFoundException('You have no vendor profile');
    return this.getWalletWithTransactions(vendor.id, page, limit);
  }

  getBalance(vendorId: string) {
    return this.prisma.wallet.findUnique({ where: { vendorId }, select: { balance: true, currency: true } });
  }
}
