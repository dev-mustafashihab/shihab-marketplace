import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';

export interface FinancialSettings {
  commissionPercent: number;
  deliveryFeeDefault: number;
  currency: string;
}

const DEFAULTS: FinancialSettings = {
  commissionPercent: 10,
  deliveryFeeDefault: 0,
  currency: 'USD',
};

const KEY = 'financial';

@Injectable()
export class SettingsService {
  constructor(private readonly prisma: PrismaService) {}

  async getFinancial(): Promise<FinancialSettings> {
    const row = await this.prisma.setting.findUnique({ where: { key: KEY } });
    if (!row) return { ...DEFAULTS };
    const v = row.value as Partial<FinancialSettings>;
    return {
      commissionPercent: typeof v.commissionPercent === 'number' ? v.commissionPercent : DEFAULTS.commissionPercent,
      deliveryFeeDefault: typeof v.deliveryFeeDefault === 'number' ? v.deliveryFeeDefault : DEFAULTS.deliveryFeeDefault,
      currency: typeof v.currency === 'string' ? v.currency : DEFAULTS.currency,
    };
  }

  async setFinancial(patch: Partial<FinancialSettings>): Promise<FinancialSettings> {
    const current = await this.getFinancial();
    const next: FinancialSettings = { ...current, ...patch };
    await this.prisma.setting.upsert({
      where: { key: KEY },
      update: { value: next as unknown as Prisma.InputJsonValue },
      create: { key: KEY, value: next as unknown as Prisma.InputJsonValue },
    });
    return next;
  }
}
