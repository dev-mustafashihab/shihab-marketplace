import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';

type Actor = { id: string; role: string };

const REVIEW_SELECT = {
  id: true,
  customerId: true,
  vendorId: true,
  bookingId: true,
  orderId: true,
  rating: true,
  comment: true,
  createdAt: true,
  customer: { select: { profile: { select: { firstName: true, lastName: true } } } },
} satisfies Prisma.ReviewSelect;

@Injectable()
export class ReviewsService {
  constructor(private readonly prisma: PrismaService) {}

  /** تقييم بعد اكتمال حجز أو طلب — العميل نفسه فقط، مرة واحدة، ومصدر الشراء إلزامي */
  async create(actor: Actor, dto: {
    bookingId?: string;
    orderId?: string;
    rating: number;
    comment?: string;
  }) {
    if (!dto.bookingId && !dto.orderId) {
      throw new ConflictException('bookingId or orderId required as proof of purchase');
    }

    let vendorId: string;
    if (dto.bookingId) {
      const booking = await this.prisma.booking.findUnique({
        where: { id: dto.bookingId },
        select: { customerId: true, vendorId: true, status: true },
      });
      if (!booking) throw new NotFoundException('Booking not found');
      if (booking.customerId !== actor.id) throw new ForbiddenException('Not your booking');
      if (booking.status !== 'COMPLETED') {
        throw new ConflictException('You can review after the booking is completed');
      }
      vendorId = booking.vendorId;
      const dup = await this.prisma.review.findUnique({
        where: { customerId_bookingId: { customerId: actor.id, bookingId: dto.bookingId } },
        select: { id: true },
      });
      if (dup) throw new ConflictException('You already reviewed this booking');
    } else {
      const orderId = dto.orderId!;
      const order = await this.prisma.order.findUnique({
        where: { id: orderId },
        select: { customerId: true, vendorId: true, status: true },
      });
      if (!order) throw new NotFoundException('Order not found');
      if (order.customerId !== actor.id) throw new ForbiddenException('Not your order');
      if (order.status !== 'DELIVERED') {
        throw new ConflictException('You can review after the order is delivered');
      }
      vendorId = order.vendorId;
      const dup = await this.prisma.review.findUnique({
        where: { customerId_orderId: { customerId: actor.id, orderId } },
        select: { id: true },
      });
      if (dup) throw new ConflictException('You already reviewed this order');
    }

    return this.prisma.review.create({
      data: {
        customerId: actor.id,
        vendorId,
        bookingId: dto.bookingId,
        orderId: dto.orderId,
        rating: dto.rating,
        comment: dto.comment,
      },
      select: REVIEW_SELECT,
    });
  }

  /** تقييمات بائع — عام، مع المتوسط */
  async listForVendor(vendorId: string, page = 1, limit = 20) {
    const [total, data, agg] = await this.prisma.$transaction([
      this.prisma.review.count({ where: { vendorId } }),
      this.prisma.review.findMany({
        where: { vendorId },
        select: REVIEW_SELECT,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.review.aggregate({ where: { vendorId }, _avg: { rating: true } }),
    ]);
    return {
      success: true as const,
      data,
      message: null,
      meta: { page, limit, total, averageRating: agg._avg.rating ?? 0 },
    };
  }
}
