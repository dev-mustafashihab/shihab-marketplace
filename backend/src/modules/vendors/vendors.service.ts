import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, VendorStatus } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';
import { CreateVendorDto } from './dto/vendor.dto';
import { UpdateVendorDto } from './dto/vendor.dto';
import { ListVendorsQueryDto } from './dto/vendor.dto';

const VENDOR_CARD_SELECT = {
  id: true,
  name: true,
  slug: true,
  description: true,
  status: true,
  address: true,
  latitude: true,
  longitude: true,
  minPrice: true,
  currency: true,
  isOpen: true,
  imageUrl: true,
  category: { select: { id: true, nameAr: true, slug: true } },
  reviews: { select: { rating: true } },
} satisfies Prisma.VendorSelect;

@Injectable()
export class VendorsService {
  constructor(private readonly prisma: PrismaService) {}

  /** البحث العام: APPROVED فقط + فلاتر + pagination (بروتوكول §8) */
  async list(query: ListVendorsQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const where: Prisma.VendorWhereInput = {
      status: VendorStatus.APPROVED,
      ...(query.categoryId ? { categoryId: query.categoryId } : {}),
      ...(query.q
        ? {
            OR: [
              { name: { contains: query.q, mode: 'insensitive' } },
              { description: { contains: query.q, mode: 'insensitive' } },
            ],
          }
        : {}),
    };
    const [total, data] = await this.prisma.$transaction([
      this.prisma.vendor.count({ where }),
      this.prisma.vendor.findMany({
        where,
        select: VENDOR_CARD_SELECT,
        orderBy: [{ isOpen: 'desc' }, { createdAt: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    return {
      success: true as const,
      data: data.map(({ reviews, ...v }) => ({
        ...v,
        averageRating: reviews.length ? Number((reviews.reduce((s, r) => s + r.rating, 0) / reviews.length).toFixed(1)) : 0,
        reviewCount: reviews.length,
      })),
      message: null,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  async getPublicBySlugOrId(idOrSlug: string) {
    // id عمود UUID — تمرير slug إليه يرمي P2023 في Postgres، لذا نفرّق أولاً
    const isUuid =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(idOrSlug);
    const vendor = await this.prisma.vendor.findFirst({
      where: {
        ...(isUuid ? { id: idOrSlug } : { slug: idOrSlug }),
        status: VendorStatus.APPROVED,
      },
      select: {
        ...VENDOR_CARD_SELECT,
        services: {
          where: { isActive: true },
          select: { id: true, name: true, description: true, price: true, currency: true, durationMin: true },
        },
        resources: {
          where: { isActive: true },
          select: { id: true, name: true, type: true, capacity: true },
        },
      },
    });
    if (!vendor) throw new NotFoundException('Vendor not found');
    const reviews = (vendor as { reviews?: { rating: number }[] }).reviews ?? [];
    return {
      ...vendor,
      averageRating: reviews.length ? Number((reviews.reduce((s, r) => s + r.rating, 0) / reviews.length).toFixed(1)) : 0,
      reviewCount: reviews.length,
    };
  }

  /** البائع ينشئ متجره — واحد فقط لكل مالك، ويبدأ PENDING للتحقق */
  async createForUser(userId: string, userRole: string, dto: CreateVendorDto) {
    if (userRole !== 'VENDOR' && userRole !== 'ADMIN') {
      throw new ForbiddenException('Only vendor accounts can create a vendor profile');
    }
    const exists = await this.prisma.vendor.findUnique({ where: { ownerId: userId }, select: { id: true } });
    if (exists) throw new ConflictException('You already have a vendor profile');

    const categoryExists = await this.prisma.category.findUnique({
      where: { id: dto.categoryId },
      select: { id: true },
    });
    if (!categoryExists) throw new NotFoundException('Category not found');

    return this.prisma.vendor.create({
      data: {
        ownerId: userId,
        categoryId: dto.categoryId,
        name: dto.name,
        slug: dto.slug,
        description: dto.description,
        phone: dto.phone,
        address: dto.address,
        latitude: dto.latitude,
        longitude: dto.longitude,
        status: userRole === 'ADMIN' ? VendorStatus.APPROVED : VendorStatus.PENDING,
      },
      select: VENDOR_CARD_SELECT,
    });
  }

  /** تحديث: البائع لبيانه فقط (بدون status)، والأدمن يدير الحالة */
  async update(actor: { id: string; role: string }, vendorId: string, dto: UpdateVendorDto) {
    const vendor = await this.prisma.vendor.findUnique({ where: { id: vendorId }, select: { ownerId: true } });
    if (!vendor) throw new NotFoundException('Vendor not found');

    const isOwner = vendor.ownerId === actor.id;
    const isAdmin = actor.role === 'ADMIN';
    if (!isOwner && !isAdmin) throw new ForbiddenException('Not your vendor profile');

    // البائع لا يستطيع تغيير حالة التوثيق — الأدمن فقط (Security Gate §9)
    const data: Prisma.VendorUpdateInput = { ...dto };
    if (!isAdmin) {
      delete (data as Record<string, unknown>).status;
      delete (data as Record<string, unknown>).rejectionReason;
    }
    // إذا اعتمد الأدمن، صفّر سبب الرفض
    if (isAdmin && dto.status === VendorStatus.APPROVED) {
      (data as Record<string, unknown>).rejectionReason = null;
    }

    return this.prisma.vendor.update({
      where: { id: vendorId },
      data,
      select: VENDOR_CARD_SELECT,
    });
  }

  /** أدمن: قائمة الانتظار للتحقق */
  listByStatus(status: VendorStatus, page = 1, limit = 20) {
    return this.prisma.$transaction([
      this.prisma.vendor.count({ where: { status } }),
      this.prisma.vendor.findMany({
        where: { status },
        select: { ...VENDOR_CARD_SELECT, owner: { select: { email: true } }, rejectionReason: true },
        orderBy: { createdAt: 'asc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
  }

  async getOwnedVendor(userId: string) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { ownerId: userId },
      select: VENDOR_CARD_SELECT,
    });
    if (!vendor) throw new NotFoundException('You have no vendor profile yet');
    return vendor;
  }
}
