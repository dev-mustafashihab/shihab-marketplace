import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';

type Actor = { id: string; role: string };

const AVAILABILITY_SELECT = {
  id: true,
  resourceId: true,
  weekday: true,
  startMin: true,
  endMin: true,
} satisfies Prisma.AvailabilitySelect;

@Injectable()
export class AvailabilityService {
  constructor(private readonly prisma: PrismaService) {}

  private async assertResourceOwnership(actor: Actor, resourceId: string): Promise<void> {
    const resource = await this.prisma.resource.findUnique({
      where: { id: resourceId },
      select: { vendor: { select: { ownerId: true } } },
    });
    if (!resource) throw new NotFoundException('Resource not found');
    if (actor.role !== 'ADMIN' && resource.vendor.ownerId !== actor.id) {
      throw new ForbiddenException('Not your resource');
    }
  }

  /** عام: نوافذ عمل مورد معين (لعرض Calendar على العميل) */
  listForResource(resourceId: string) {
    return this.prisma.availability.findMany({
      where: { resourceId },
      select: AVAILABILITY_SELECT,
      orderBy: [{ weekday: 'asc' }, { startMin: 'asc' }],
    });
  }

  /** استبدال كامل لقواعد أسبوع مورد — عملية واحدة ذرّية */
  async replaceForOwner(actor: Actor, resourceId: string, rules: {
    weekday: number;
    startMin: number;
    endMin: number;
  }[]): Promise<void> {
    await this.assertResourceOwnership(actor, resourceId);

    for (const r of rules) {
      if (r.weekday < 0 || r.weekday > 6) {
        throw new ForbiddenException('weekday must be 0..6 (Sunday=0)');
      }
      if (r.startMin < 0 || r.endMin > 24 * 60 || r.startMin >= r.endMin) {
        throw new ForbiddenException('startMin/endMin invalid (0..1440, start<end)');
      }
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.availability.deleteMany({ where: { resourceId } });
      if (rules.length > 0) {
        await tx.availability.createMany({
          data: rules.map((r) => ({
            resourceId,
            weekday: r.weekday,
            startMin: r.startMin,
            endMin: r.endMin,
          })),
        });
      }
    });
  }

  async remove(actor: Actor, availabilityId: string): Promise<{ deleted: boolean }> {
    const slot = await this.prisma.availability.findUnique({
      where: { id: availabilityId },
      select: { resource: { select: { vendor: { select: { ownerId: true } } } } },
    });
    if (!slot) throw new NotFoundException('Availability rule not found');
    if (actor.role !== 'ADMIN' && slot.resource.vendor.ownerId !== actor.id) {
      throw new ForbiddenException('Not your resource');
    }
    await this.prisma.availability.delete({ where: { id: availabilityId } });
    return { deleted: true };
  }
}
