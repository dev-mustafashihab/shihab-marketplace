import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PayoutStatus } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';
import { WalletsService } from './wallets.service';

type Actor = { id: string; role: string };

@Injectable()
export class PayoutsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly wallets: WalletsService,
  ) {}

  private async ownedVendorId(actor: Actor): Promise<string> {
    const vendor = await this.prisma.vendor.findUnique({
      where: { ownerId: actor.id },
      select: { id: true },
    });
    if (!vendor) throw new NotFoundException('You have no vendor profile');
    return vendor.id;
  }

  async requestPayout(actor: Actor, amount: number, note?: string) {
    const vendorId = await this.ownedVendorId(actor);
    const balance = (await this.wallets.getBalance(vendorId))?.balance ?? 0;
    if (amount > balance) {
      throw new ConflictException(`Requested amount exceeds balance (${balance})`);
    }
    // طلب واحد معلق في نفس الوقت
    const pending = await this.prisma.payout.findFirst({
      where: { vendorId, status: PayoutStatus.REQUESTED },
      select: { id: true },
    });
    if (pending) throw new ConflictException('You already have a pending payout request');
    return this.prisma.payout.create({ data: { vendorId, amount, note } });
  }

  async listForVendor(actor: Actor, page = 1, limit = 20) {
    const vendorId = await this.ownedVendorId(actor);
    const [total, data] = await this.prisma.$transaction([
      this.prisma.payout.count({ where: { vendorId } }),
      this.prisma.payout.findMany({
        where: { vendorId },
        orderBy: { requestedAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    return { success: true as const, data, message: null, meta: { page, limit, total, totalPages: Math.ceil(total / limit) } };
  }

  /** الأدمن: APPROVED → (تحويل فعلي خارج المنظومة) → PAID يخصم من المحفظة */
  async decide(actor: Actor, payoutId: string, decision: 'APPROVED' | 'PAID' | 'FAILED', note?: string) {
    const payout = await this.prisma.payout.findUnique({ where: { id: payoutId } });
    if (!payout) throw new NotFoundException('Payout not found');

    const allowed: Record<PayoutStatus, PayoutStatus[]> = {
      REQUESTED: [PayoutStatus.APPROVED, PayoutStatus.FAILED],
      APPROVED: [PayoutStatus.PAID, PayoutStatus.FAILED],
      PAID: [],
      FAILED: [],
    };
    if (!allowed[payout.status].includes(decision)) {
      throw new ConflictException(`Cannot move payout from ${payout.status} to ${decision}`);
    }

    await this.prisma.$transaction(async (tx) => {
      if (decision === 'PAID') {
        // خصم فعلي من الرصيد عبر الـ ledger
        await this.wallets.postTransaction(tx, {
          vendorId: payout.vendorId,
          type: 'PAYOUT',
          amount: payout.amount,
          currency: payout.currency,
          refType: 'PAYOUT',
          refId: payout.id,
          note: note ?? 'PAYOUT_TRANSFERRED',
        });
      }
      await tx.payout.update({
        where: { id: payout.id },
        data: { status: decision, note: note ?? payout.note, processedAt: new Date() },
      });
    });
    return this.prisma.payout.findUnique({ where: { id: payoutId } });
  }
}
