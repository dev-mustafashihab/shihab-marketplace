import {
  Body,
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
        // PHASE 9: اسم من الخادم فقط + امتداد ثابت يُصحح لاحقاً حسب magic bytes
        filename: (_req, file, cb) => cb(null, randomUUID()),
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
    @Body() body: { vendorId?: string },
    @UploadedFile() file?: Express.Multer.File,
  ) {
    if (!file) throw new NotFoundException('file is required');
    if (file.size > MAX_BYTES) throw new PayloadTooLargeException('Max 5MB');

    // PHASE 9: تحقق magic bytes — لا نثق في mimetype القادم من العميل
    const kind = this.detectImageKind(file.buffer);
    if (!kind) throw new UnsupportedMediaTypeException('Only real jpeg/png/webp images are allowed');

    // PHASE 8: vendorId من multipart body (نص الحقل) — ليس من كائن الملف
    const vendorId = body?.vendorId && /^[0-9a-f-]{36}$/i.test(body.vendorId) ? body.vendorId : undefined;

    if (vendorId) {
      const vendor = await this.prisma.vendor.findUnique({ where: { id: vendorId }, select: { ownerId: true } });
      if (!vendor) throw new NotFoundException('Vendor not found');
      if (vendor.ownerId !== user.id && user.role !== 'ADMIN') throw new ForbiddenException();
    }

    // امتداد موثوق من المحتوى الموثّق — يمنع double-extension وملفات تنفيذية
    const safeName = `${file.filename}.${kind.ext}`;

    const media = await this.prisma.media.create({
      data: {
        ownerId: user.id,
        vendorId: vendorId ?? null,
        filePath: safeName,
        mimeType: kind.mime,
        sizeBytes: file.size,
      },
      select: { id: true, filePath: true, mimeType: true, sizeBytes: true, createdAt: true },
    });
    return { ...media, url: `/mp-media/${media.filePath}` };
  }

  private detectImageKind(buf: Buffer): { mime: string; ext: string } | null {
    if (!buf || buf.length < 12) return null;
    // JPEG: FF D8 FF
    if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return { mime: 'image/jpeg', ext: 'jpg' };
    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47) return { mime: 'image/png', ext: 'png' };
    // WEBP: RIFF....WEBP
    if (buf.toString('ascii', 0, 4) === 'RIFF' && buf.toString('ascii', 8, 12) === 'WEBP') return { mime: 'image/webp', ext: 'webp' };
    return null;
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
