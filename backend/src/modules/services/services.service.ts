import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';

type Actor = { id: string; role: string };

type ServiceCard = Prisma.ServiceGetPayload<{ select: typeof SERVICE_SELECT }>;


const SERVICE_SELECT = {
  id: true,
  vendorId: true,
  categoryId: true,
  name: true,
  description: true,
  price: true,
  currency: true,
  durationMin: true,
  isActive: true,
} satisfies Prisma.ServiceSelect;

@Injectable()
export class ServicesService {
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

  listPublicByVendor(vendorId: string): Promise<ServiceCard[]> {
    return this.prisma.service.findMany({
      where: { vendorId, isActive: true },
      select: SERVICE_SELECT,
      orderBy: { createdAt: 'asc' },
    });
  }

  async listMine(actor: Actor): Promise<ServiceCard[]> {
    const vendorId = await this.ownedVendorId(actor);
    return this.prisma.service.findMany({
      where: { vendorId },
      select: SERVICE_SELECT,
      orderBy: { createdAt: 'asc' },
    });
  }

  async create(actor: Actor, dto: {
    name: string;
    description?: string;
    price: number;
    currency?: string;
    durationMin?: number;
  }): Promise<ServiceCard> {
    const vendorId = await this.ownedVendorId(actor);
    const vendor = await this.prisma.vendor.findUnique({
      where: { id: vendorId },
      select: { categoryId: true },
    });
    return this.prisma.service.create({
      data: {
        vendorId,
        categoryId: vendor!.categoryId,
        name: dto.name,
        description: dto.description,
        price: dto.price,
        currency: dto.currency ?? 'USD',
        durationMin: dto.durationMin,
      },
      select: SERVICE_SELECT,
    });
  }

  async update(actor: Actor, serviceId: string, dto: {
    name?: string;
    description?: string;
    price?: number;
    isActive?: boolean;
    durationMin?: number;
  }): Promise<ServiceCard> {
    const service = await this.prisma.service.findUnique({
      where: { id: serviceId },
      select: { vendorId: true },
    });
    if (!service) throw new NotFoundException('Service not found');
    await this.assertOwnership(actor, service.vendorId);
    return this.prisma.service.update({
      where: { id: serviceId },
      data: { ...dto },
      select: SERVICE_SELECT,
    });
  }

  async remove(actor: Actor, serviceId: string): Promise<{ deleted: boolean }> {
    const service = await this.prisma.service.findUnique({
      where: { id: serviceId },
      select: { vendorId: true },
    });
    if (!service) throw new NotFoundException('Service not found');
    await this.assertOwnership(actor, service.vendorId);
    await this.prisma.service.delete({ where: { id: serviceId } });
    return { deleted: true };
  }
}
