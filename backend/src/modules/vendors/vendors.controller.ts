import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { VendorsService } from './vendors.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { Permissions } from '../../common/decorators/permissions.decorator';
import { CreateVendorDto, ListVendorsQueryDto, UpdateVendorDto } from './dto/vendor.dto';

@ApiTags('vendors')
@Controller('vendors')
export class VendorsController {
  constructor(private readonly vendorsService: VendorsService) {}

  /** بحث عام: المعتمدون فقط */
  @Public()
  @Get()
  list(@Query() query: ListVendorsQueryDto) {
    return this.vendorsService.list(query);
  }

  @Public()
  @Get(':idOrSlug')
  getPublic(@Param('idOrSlug') idOrSlug: string) {
    return this.vendorsService.getPublicBySlugOrId(idOrSlug);
  }

  /** البائع الحالي: متجره هو (للداشبورد) */
  @ApiBearerAuth()
  @Get('me/profile')
  myVendor(@CurrentUser('id') userId: string) {
    return this.vendorsService.getOwnedVendor(userId);
  }

  @ApiBearerAuth()
  @Post()
  create(
    @CurrentUser() user: { id: string; role: string },
    @Body() dto: CreateVendorDto,
  ) {
    return this.vendorsService.createForUser(user.id, user.role, dto);
  }

  @ApiBearerAuth()
  @Patch(':id')
  update(
    @CurrentUser() user: { id: string; role: string },
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateVendorDto,
  ) {
    return this.vendorsService.update(user, id, dto);
  }

  /** أدمن: طوابير التوثيق */
  @ApiBearerAuth()
  @Get('admin/queue/:status')
  @Permissions('vendors:verify')
  queue(
    @Param('status') status: 'PENDING' | 'APPROVED' | 'REJECTED' | 'SUSPENDED',
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.vendorsService.listByStatus(status, page, limit);
  }
}
