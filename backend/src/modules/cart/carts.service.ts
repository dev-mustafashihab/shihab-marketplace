import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';

/** سلة واحدة نشطة لكل عميل — بائع واحد لكل سلة (قاعدة Marketplace قياسية) */
@Injectable()
export class CartsService {
  constructor(private readonly prisma: PrismaService) {}

  /** سلة بدون بائع حتى أول منتج — أول إضافة تحدد البائع */
  async getMine(customerId: string) {
    const cart = await this.prisma.cart.findUnique({
      where: { customerId },
      include: {
        vendor: { select: { id: true, name: true, slug: true } },
        items: {
          include: { product: { select: { id: true, name: true, price: true, currency: true, isActive: true } } },
          orderBy: { productId: 'asc' },
        },
      },
    });
    if (!cart) return { cart: null, items: [], subtotal: 0 };
    let subtotal = 0;
    const items = cart.items.map((i) => {
      const lineTotal = i.product.price * i.quantity;
      subtotal += lineTotal;
      return {
        id: i.id,
        productId: i.productId,
        name: i.product.name,
        unitPrice: i.product.price,
        currency: i.product.currency,
        quantity: i.quantity,
        lineTotal,
        productActive: i.product.isActive,
      };
    });
    return { cart: { id: cart.id, vendor: cart.vendor }, items, subtotal };
  }

  async addItem(customerId: string, productId: string, quantity: number) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      select: { id: true, vendorId: true, isActive: true, stock: true },
    });
    if (!product || !product.isActive) throw new NotFoundException('Product not available');
    if (product.stock !== null && product.stock < quantity) {
      throw new ConflictException('Insufficient stock');
    }

    return this.prisma.$transaction(async (tx) => {
      let cart = await tx.cart.findUnique({ where: { customerId } });
      if (!cart) {
        // أول منتج يحدد بائع السلة
        cart = await tx.cart.create({ data: { customerId, vendorId: product.vendorId } });
      } else if (cart.vendorId !== product.vendorId) {
        throw new ConflictException('Cart already contains items from another vendor');
      }
      const existing = await tx.cartItem.findUnique({
        where: { cartId_productId: { cartId: cart.id, productId } },
      });
      const newQty = (existing?.quantity ?? 0) + quantity;
      await tx.cartItem.upsert({
        where: { cartId_productId: { cartId: cart.id, productId } },
        update: { quantity: newQty },
        create: { cartId: cart.id, productId, quantity },
      });
      return { added: true, quantity: newQty };
    });
  }

  async updateQuantity(customerId: string, productId: string, quantity: number) {
    const cart = await this.prisma.cart.findUnique({ where: { customerId } });
    if (!cart) throw new NotFoundException('Cart is empty');
    if (quantity <= 0) {
      await this.prisma.cartItem.deleteMany({ where: { cartId: cart.id, productId } });
      const remaining = await this.prisma.cartItem.count({ where: { cartId: cart.id } });
      if (remaining === 0) await this.prisma.cart.delete({ where: { id: cart.id } });
      return { removed: true };
    }
    await this.prisma.cartItem.updateMany({
      where: { cartId: cart.id, productId },
      data: { quantity },
    });
    return { updated: true, quantity };
  }

  async clear(customerId: string) {
    await this.prisma.cart.deleteMany({ where: { customerId } });
    return { cleared: true };
  }
}
