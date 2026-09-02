import {
  Controller,
  Post,
  Get,
  Delete,
  Param,
  ParseUUIDPipe,
  UseInterceptors,
  UploadedFile,
  NotFoundException,
  ForbiddenException,
  PayloadTooLargeException,
  UnsupportedMediaTypeException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { ApiBearerAuth, ApiTags, ApiConsumes, ApiBody } from '@nestjs/swagger';
import { randomUUID } from 'crypto';
import { extname } from 'path';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../common/prisma.service';

const ALLOWED = new Set(['image/jpeg', 'image/png', 'image/webp']);
const MAX_BYTES = 5 * 1024 * 1024; // 5MB
const UPLOAD_DIR = '/opt/shihab-marketplace/uploads/media';

@ApiTags('media')
@ApiBearerAuth()
@Controller('media')
export class MediaController {
  constructor(private readonly prisma: PrismaService) {}

  /** رفع صورة — المالك أو بائع يملك المتجر فقط. */
  @Post('upload')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: UPLOAD_DIR,
        filename: (_req, file, cb) => cb(null, `${randomUUID()}${extname(file.originalname)}`),
      }),
      limits: { fileSize: MAX_BYTES },
    }),
  )
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: { file: { type: 'string', format: 'binary' }, vendorId: { type: 'string', format: 'uuid' } },
      required: ['file'],
    },
  })
  async upload(
    @CurrentUser() user: { id: string; role: string },
    @UploadedFile() file?: Express.Multer.File,
  ) {
    if (!file) throw new NotFoundException('file is required');
    if (!ALLOWED.has(file.mimetype)) throw new UnsupportedMediaTypeException('Only jpeg/png/webp allowed');
    if (file.size > MAX_BYTES) throw new PayloadTooLargeException('Max 5MB');

    const vendorId = (file as unknown as { vendorId?: string }).vendorId;
    if (vendorId) {
      const vendor = await this.prisma.vendor.findUnique({ where: { id: vendorId }, select: { ownerId: true } });
      if (!vendor) throw new NotFoundException('Vendor not found');
      if (vendor.ownerId !== user.id && user.role !== 'ADMIN') throw new ForbiddenException();
    }

    const media = await this.prisma.media.create({
      data: {
        ownerId: user.id,
        vendorId: vendorId ?? null,
        filePath: file.filename,
        mimeType: file.mimetype,
        sizeBytes: file.size,
      },
      select: { id: true, filePath: true, mimeType: true, sizeBytes: true, createdAt: true },
    });
    return { ...media, url: `/mp-media/${media.filePath}` };
  }

  /** وسائط متجر — عام للمعتمدين. */
  @Get('vendor/:vendorId')
  async listForVendor(@Param('vendorId', ParseUUIDPipe) vendorId: string) {
    const rows = await this.prisma.media.findMany({
      where: { vendorId },
      orderBy: { createdAt: 'desc' },
      take: 50,
      select: { id: true, filePath: true, mimeType: true, createdAt: true },
    });
    return rows.map((m) => ({ ...m, url: `/mp-media/${m.filePath}` }));
  }

  /** حذف — المالك أو أدمن. */
  @Delete(':id')
  async remove(@CurrentUser() user: { id: string; role: string }, @Param('id', ParseUUIDPipe) id: string) {
    const media = await this.prisma.media.findUnique({ where: { id }, select: { ownerId: true, filePath: true } });
    if (!media) throw new NotFoundException();
    if (media.ownerId !== user.id && user.role !== 'ADMIN') throw new ForbiddenException();
    await this.prisma.media.delete({ where: { id } });
    return { deleted: true };
  }
}
