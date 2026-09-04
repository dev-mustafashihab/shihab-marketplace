import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { ListUsersQueryDto } from './dto/list-users.query.dto';

const USER_SELECT = {
  id: true,
  email: true,
  role: true,
  status: true,
  createdAt: true,
  lastLoginAt: true,
  profile: {
    select: {
      firstName: true, lastName: true, phone: true, locale: true,
      fullName: true, nationalId: true, governorate: true, city: true,
      kycStatus: true, kycNote: true, idFrontUrl: true, idBackUrl: true,
      fatherName: true, motherName: true, birthDate: true,
      walletAccountId: true,
    },
  },
} satisfies Prisma.UserSelect;

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async getProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: USER_SELECT,
    });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return user;
  }

  /** مراجعة توثيق زبون (قبول/رفض مع سبب) — إدارة فقط. */
  async reviewKyc(userId: string, status: 'APPROVED' | 'REJECTED', note?: string) {
    await this.getProfile(userId);
    if (status !== 'APPROVED' && status !== 'REJECTED') {
      throw new BadRequestException('status must be APPROVED or REJECTED');
    }
    await this.prisma.profile.upsert({
      where: { userId },
      create: { userId, kycStatus: status, kycNote: note ?? null },
      update: { kycStatus: status, kycNote: note ?? null },
    });
    return this.getProfile(userId);
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    await this.getProfile(userId);
    const resubmit =
      (dto.idFrontUrl || dto.idBackUrl) ? true : false;
    await this.prisma.profile.upsert({
      where: { userId },
      create: { userId, ...dto },
      update: {
        ...dto,
        // إعادة تقديم الهوية بعد الرفض تُعيد الملف لقيد المراجعة
        ...(resubmit
          ? { kycStatus: 'PENDING_DOCS' as const, kycNote: null }
          : {}),
      },
    });
    return this.getProfile(userId);
  }

  async list(query: ListUsersQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const where: Prisma.UserWhereInput = {
      ...(query.q ? { email: { contains: query.q, mode: 'insensitive' } } : {}),
      ...(query.role ? { role: query.role } : {}),
    };
    const [total, data] = await this.prisma.$transaction([
      this.prisma.user.count({ where }),
      this.prisma.user.findMany({
        where,
        select: {
          id: true,
          email: true,
          role: true,
          status: true,
          createdAt: true,
          profile: {
            select: { fullName: true, nationalId: true, kycStatus: true },
          },
        },
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
}
