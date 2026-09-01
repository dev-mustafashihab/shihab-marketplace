import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';

type Actor = { id: string; role: string };

type ProductCard = Prisma.ProductGetPayload<{ select: typeof PRODUCT_SELECT }>;


const PRODUCT_SELECT = {
  id: true,
  vendorId: true,
  name: true,
  description: true,
  price: true,
  currency: true,
  stock: true,
  isActive: true,
} satisfies Prisma.ProductSelect;

@Injectable()
export class ProductsService {
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

  listPublicByVendor(vendorId: string): Promise<ProductCard[]> {
    return this.prisma.product.findMany({
      where: { vendorId, isActive: true },
      select: PRODUCT_SELECT,
      orderBy: { createdAt: 'asc' },
    });
  }

  async listMine(actor: Actor): Promise<ProductCard[]> {
    const vendorId = await this.ownedVendorId(actor);
    return this.prisma.product.findMany({
      where: { vendorId },
      select: PRODUCT_SELECT,
      orderBy: { createdAt: 'asc' },
    });
  }

  async create(actor: Actor, dto: {
    name: string;
    description?: string;
    price: number;
    currency?: string;
    stock?: number;
  }): Promise<ProductCard> {
    const vendorId = await this.ownedVendorId(actor);
    return this.prisma.product.create({
      data: {
        vendorId,
        name: dto.name,
        description: dto.description,
        price: dto.price,
        currency: dto.currency ?? 'USD',
        stock: dto.stock,
      },
      select: PRODUCT_SELECT,
    });
  }

  async update(actor: Actor, productId: string, dto: {
    name?: string;
    description?: string;
    price?: number;
    stock?: number;
    isActive?: boolean;
  }): Promise<ProductCard> {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      select: { vendorId: true },
    });
    if (!product) throw new NotFoundException('Product not found');
    await this.assertOwnership(actor, product.vendorId);
    return this.prisma.product.update({
      where: { id: productId },
      data: { ...dto },
      select: PRODUCT_SELECT,
    });
  }

  async remove(actor: Actor, productId: string): Promise<{ deleted: boolean }> {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      select: { vendorId: true },
    });
    if (!product) throw new NotFoundException('Product not found');
    await this.assertOwnership(actor, product.vendorId);
    await this.prisma.product.delete({ where: { id: productId } });
    return { deleted: true };
  }
}
