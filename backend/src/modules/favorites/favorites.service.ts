import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';

@Injectable()
export class FavoritesService {
  constructor(private readonly prisma: PrismaService) {}

  listMine(customerId: string) {
    return this.prisma.favorite.findMany({
      where: { customerId },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        vendor: {
          select: {
            id: true, name: true, slug: true, minPrice: true, currency: true,
            category: { select: { nameAr: true } },
          },
        },
        createdAt: true,
      },
    });
  }

  async toggle(customerId: string, vendorId: string) {
    const vendor = await this.prisma.vendor.findUnique({ where: { id: vendorId }, select: { id: true } });
    if (!vendor) throw new NotFoundException('Vendor not found');
    const existing = await this.prisma.favorite.findUnique({
      where: { customerId_vendorId: { customerId, vendorId } },
      select: { id: true },
    });
    if (existing) {
      await this.prisma.favorite.delete({ where: { id: existing.id } });
      return { favorited: false };
    }
    await this.prisma.favorite.create({ data: { customerId, vendorId } });
    return { favorited: true };
  }
}
