import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';

const CATEGORY_SELECT = {
  id: true,
  name: true,
  nameAr: true,
  slug: true,
  iconKey: true,
  sortOrder: true,
  isActive: true,
} satisfies Prisma.CategorySelect;

@Injectable()
export class CategoriesService {
  constructor(private readonly prisma: PrismaService) {}

  list(includeInactive = false) {
    return this.prisma.category.findMany({
      where: includeInactive ? {} : { isActive: true },
      select: CATEGORY_SELECT,
      orderBy: [{ sortOrder: 'asc' }, { nameAr: 'asc' }],
    });
  }

  async create(dto: CreateCategoryDto) {
    try {
      return await this.prisma.category.create({
        data: {
          name: dto.name ?? dto.nameAr,
          nameAr: dto.nameAr,
          slug: dto.slug,
          iconKey: dto.iconKey,
          sortOrder: dto.sortOrder ?? 0,
          isActive: dto.isActive ?? true,
        },
        select: CATEGORY_SELECT,
      });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ConflictException('Category slug already exists');
      }
      throw e;
    }
  }

  async update(id: string, dto: UpdateCategoryDto) {
    await this.ensureExists(id);
    try {
      return await this.prisma.category.update({
        where: { id },
        data: { ...dto },
        select: CATEGORY_SELECT,
      });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ConflictException('Category slug already exists');
      }
      throw e;
    }
  }

  async remove(id: string) {
    await this.ensureExists(id);
    try {
      await this.prisma.category.delete({ where: { id } });
      return { deleted: true };
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2003') {
        throw new ConflictException('Category has vendors/services; deactivate instead');
      }
      throw e;
    }
  }

  private async ensureExists(id: string) {
    const found = await this.prisma.category.findUnique({ where: { id }, select: { id: true } });
    if (!found) throw new NotFoundException('Category not found');
  }
}
