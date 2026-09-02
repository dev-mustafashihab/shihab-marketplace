import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, OrderStatus } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';

type Actor = { id: string; role: string };

const ORDER_SELECT = {
  id: true,
  orderRef: true,
  customerId: true,
  vendorId: true,
  status: true,
  subtotal: true,
  deliveryFee: true,
  discount: true,
  total: true,
  currency: true,
  addressSnapshot: true,
  phoneSnapshot: true,
  note: true,
  createdAt: true,
  vendor: { select: { id: true, name: true, slug: true } },
} satisfies Prisma.OrderSelect;

/** انتقالات مسموحة في آلة حالة الطلب */
const ORDER_TRANSITIONS: Record<OrderStatus, OrderStatus[]> = {
  PENDING: [OrderStatus.CONFIRMED, OrderStatus.CANCELLED],
  CONFIRMED: [OrderStatus.PREPARING, OrderStatus.CANCELLED],
  PREPARING: [OrderStatus.READY, OrderStatus.CANCELLED],
  READY: [OrderStatus.OUT_FOR_DELIVERY],
  OUT_FOR_DELIVERY: [OrderStatus.DELIVERED],
  DELIVERED: [],
  CANCELLED: [],
  REFUNDED: [],
};

function generateOrderRef(): string {
  const d = new Date();
  const ymd = `${String(d.getFullYear()).slice(2)}${String(d.getMonth() + 1).padStart(2, '0')}${String(d.getDate()).padStart(2, '0')}`;
  const alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  let rand = '';
  for (let i = 0; i < 6; i++) rand += alphabet[Math.floor(Math.random() * alphabet.length)];
  return `ORD-${ymd}-${rand}`;
}

@Injectable()
export class OrdersService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Checkout: يحوّل السلة إلى طلب داخل معاملة واحدة.
   * يعيد حساب كل الأسعار من DB (لا ثقة بالعميل) ويخصم المخزون بشروط.
   */
  async checkout(actor: Actor, dto: {
    address: string;
    phone: string;
    note?: string;
    clientRequestId?: string;
  }) {
    if (dto.clientRequestId) {
      const existing = await this.prisma.order.findUnique({
        where: { customerId_clientRequestId: { customerId: actor.id, clientRequestId: dto.clientRequestId } },
        select: ORDER_SELECT,
      });
      if (existing) return existing;
    }

    return this.prisma.$transaction(async (tx) => {
      const cart = await tx.cart.findUnique({
        where: { customerId: actor.id },
        include: { items: { include: { product: true } } },
      });
      if (!cart || cart.items.length === 0) throw new ConflictException('Cart is empty');

      let subtotal = 0;
      const currency = cart.items[0].product.currency;
      for (const item of cart.items) {
        const p = item.product;
        if (!p.isActive) throw new ConflictException(`Product no longer available: ${p.name}`);
        subtotal += p.price * item.quantity;
      }
      const total = subtotal; // deliveryFee/discount تُحسب هنا لاحقاً حسب سياسات البائع

      // PHASE 4 FIX: خصم مخزون ذري (يمنع البيع الزائد والسالب) — قبل إنشاء الطلب
      for (const item of cart.items) {
        if (item.product.stock !== null) {
          const res = await tx.$executeRaw`
            UPDATE products SET stock = stock - ${item.quantity}
            WHERE id = ${item.productId}::uuid AND stock >= ${item.quantity}`;
          if (res === 0) {
            throw new ConflictException(`Insufficient stock for: ${item.product.name}`);
          }
        }
      }

      const order = await tx.order.create({
        data: {
          orderRef: generateOrderRef(),
          customerId: actor.id,
          vendorId: cart.vendorId,
          status: OrderStatus.PENDING,
          subtotal,
          total,
          currency,
          addressSnapshot: dto.address,
          phoneSnapshot: dto.phone,
          note: dto.note,
          clientRequestId: dto.clientRequestId,
          items: {
            create: cart.items.map((i) => ({
              productId: i.productId,
              nameSnapshot: i.product.name,
              unitPrice: i.product.price,
              quantity: i.quantity,
              lineTotal: i.product.price * i.quantity,
            })),
          },
        },
        select: ORDER_SELECT,
      });

      await tx.orderStatusHistory.create({
        data: { orderId: order.id, fromStatus: null, toStatus: OrderStatus.PENDING, actorId: actor.id, reason: 'CHECKOUT' },
      });

      await tx.cartItem.deleteMany({ where: { cartId: cart.id } });
      await tx.cart.delete({ where: { id: cart.id } });

      return order;
    }).catch((e) => {
      // PHASE 5: تكرار clientRequestId متزامن → أعِد الطلب الموجود بدل 500
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        return this.prisma.order.findUnique({
          where: { customerId_clientRequestId: { customerId: actor.id, clientRequestId: dto.clientRequestId! } },
          select: ORDER_SELECT,
        });
      }
      throw e;
    });
  }

  async listMine(actor: Actor, page = 1, limit = 20) {
    const [total, data] = await this.prisma.$transaction([
      this.prisma.order.count({ where: { customerId: actor.id } }),
      this.prisma.order.findMany({
        where: { customerId: actor.id },
        select: { ...ORDER_SELECT, items: true },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    return {
      success: true as const,
      data,
      message: null,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  async getOne(actor: Actor, orderId: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      select: {
        ...ORDER_SELECT,
        items: true,
        statusHistory: { orderBy: { createdAt: 'asc' } },
      },
    });
    if (!order) throw new NotFoundException('Order not found');
    const vendorOwner = await this.prisma.vendor.findUnique({
      where: { id: order.vendorId },
      select: { ownerId: true },
    });
    const allowed = order.customerId === actor.id || actor.role === 'ADMIN' || vendorOwner?.ownerId === actor.id;
    if (!allowed) throw new NotFoundException('Order not found');
    return order;
  }

  /** تغيير حالة — العميل يلغي فقط، البائع يدير التدفق، الأدمن الكل */
  async transition(actor: Actor, orderId: string, to: OrderStatus, reason?: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      select: { status: true, customerId: true, vendorId: true },
    });
    if (!order) throw new NotFoundException('Order not found');

    const vendorOwner = await this.prisma.vendor.findUnique({
      where: { id: order.vendorId },
      select: { ownerId: true },
    });
    const isCustomer = order.customerId === actor.id;
    const isVendor = vendorOwner?.ownerId === actor.id;
    const isAdmin = actor.role === 'ADMIN';

    if (to === OrderStatus.CANCELLED) {
      if (!isCustomer && !isAdmin && !isVendor) throw new NotFoundException('Order not found');
      if (isCustomer && !isAdmin && order.status !== OrderStatus.PENDING) {
        throw new ConflictException('Can only cancel before confirmation');
      }
    } else {
      if (!isVendor && !isAdmin) throw new ForbiddenException('Vendor only');
    }

    if (!ORDER_TRANSITIONS[order.status].includes(to)) {
      throw new ConflictException(`Cannot move order from ${order.status} to ${to}`);
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM "orders" WHERE id = ${orderId}::uuid FOR UPDATE`;
      const updated = await tx.order.updateMany({
        where: { id: orderId, status: order.status },
        data: { status: to },
      });
      if (updated.count === 0) throw new ConflictException('Order status changed concurrently');
      await tx.orderStatusHistory.create({
        data: { orderId, fromStatus: order.status, toStatus: to, actorId: actor.id, reason },
      });
    });

    return this.prisma.order.findUnique({ where: { id: orderId }, select: ORDER_SELECT });
  }

  /** طوابير البائع */
  async listForVendor(actor: Actor, status: OrderStatus | undefined, page = 1, limit = 20) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { ownerId: actor.id },
      select: { id: true },
    });
    if (!vendor && actor.role !== 'ADMIN') throw new NotFoundException('You have no vendor profile');
    const where = { ...(vendor && actor.role !== 'ADMIN' ? { vendorId: vendor.id } : {}), ...(status ? { status } : {}) };
    const [total, data] = await this.prisma.$transaction([
      this.prisma.order.count({ where }),
      this.prisma.order.findMany({
        where,
        select: { ...ORDER_SELECT, items: true },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    return { success: true as const, data, message: null, meta: { page, limit, total, totalPages: Math.ceil(total / limit) } };
  }
}
