import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';

type Actor = { id: string; role: string };

type ResourceCard = Prisma.ResourceGetPayload<{ select: typeof RESOURCE_SELECT }>;


const RESOURCE_SELECT = {
  id: true,
  vendorId: true,
  name: true,
  type: true,
  capacity: true,
  isActive: true,
} satisfies Prisma.ResourceSelect;

@Injectable()
export class ResourcesService {
  constructor(private readonly prisma: PrismaService) {}

  private async assertOwnership(actor: Actor, vendorId: string): Promise<void> {
    const vendor = await this.prisma.vendor.findUnique({
      where: { id: vendorId },
      select: { ownerId: true },
    });
    if (!vendor) throw new NotFoundException('Vendor not found');
    if (actor.role !== 'ADMIN' && vendor.ownerId !== actor.id) {
      throw new ForbiddenException('Not your vendor profile');
    }
  }

  private async ownedVendorId(actor: Actor): Promise<string> {
    const vendor = await this.prisma.vendor.findUnique({
      where: { ownerId: actor.id },
      select: { id: true },
    });
    if (!vendor) throw new NotFoundException('You have no vendor profile yet');
    return vendor.id;
  }

  listMine(actor: Actor): Promise<ResourceCard[]> {
    return this.prisma.$transaction(async (tx) => {
      const vendor = await tx.vendor.findUnique({
        where: { ownerId: actor.id },
        select: { id: true },
      });
      if (!vendor) throw new NotFoundException('You have no vendor profile yet');
      return tx.resource.findMany({
        where: { vendorId: vendor.id },
        select: RESOURCE_SELECT,
        orderBy: { createdAt: 'asc' },
      });
    });
  }

  async create(actor: Actor, dto: {
    name: string;
    type?: 'VENUE' | 'STAFF' | 'EQUIPMENT' | 'OTHER';
    capacity?: number;
  }): Promise<ResourceCard> {
    const vendorId = await this.ownedVendorId(actor);
    return this.prisma.resource.create({
      data: {
        vendorId,
        name: dto.name,
        type: dto.type ?? 'OTHER',
        capacity: dto.capacity,
      },
      select: RESOURCE_SELECT,
    });
  }

  async update(actor: Actor, resourceId: string, dto: {
    name?: string;
    type?: 'VENUE' | 'STAFF' | 'EQUIPMENT' | 'OTHER';
    capacity?: number;
    isActive?: boolean;
  }): Promise<ResourceCard> {
    const resource = await this.prisma.resource.findUnique({
      where: { id: resourceId },
      select: { vendorId: true },
    });
    if (!resource) throw new NotFoundException('Resource not found');
    await this.assertOwnership(actor, resource.vendorId);
    return this.prisma.resource.update({
      where: { id: resourceId },
      data: { ...dto },
      select: RESOURCE_SELECT,
    });
  }

  async remove(actor: Actor, resourceId: string): Promise<{ deleted: boolean }> {
    const resource = await this.prisma.resource.findUnique({
      where: { id: resourceId },
      select: { vendorId: true },
    });
    if (!resource) throw new NotFoundException('Resource not found');
    await this.assertOwnership(actor, resource.vendorId);
    await this.prisma.resource.delete({ where: { id: resourceId } });
    return { deleted: true };
  }
}
