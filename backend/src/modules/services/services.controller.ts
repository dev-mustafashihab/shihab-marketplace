import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { ServicesService } from './services.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';

class CreateServiceDto {
  @IsString() @MinLength(2) @MaxLength(150) name!: string;
  @IsOptional() @IsString() description?: string;
  @Type(() => Number) @IsInt() @Min(0) price!: number;
  @IsOptional() @IsString() @MaxLength(3) currency?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(15) durationMin?: number;
}

class UpdateServiceDto {
  @IsOptional() @IsString() @MinLength(2) @MaxLength(150) name?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(0) price?: number;
  @IsOptional() @IsBoolean() isActive?: boolean;
  @IsOptional() @Type(() => Number) @IsInt() @Min(15) durationMin?: number;
}

@ApiTags('services')
@Controller('services')
export class ServicesController {
  constructor(private readonly servicesService: ServicesService) {}

  /** عام: خدمات بائع (لصفحة Vendor Details) */
  @Public()
  @Get('public/vendor/:vendorId')
  listPublic(@Param('vendorId', ParseUUIDPipe) vendorId: string) {
    return this.servicesService.listPublicByVendor(vendorId);
  }

  /** البائع: خدمات متجره هو */
  @ApiBearerAuth()
  @Get('mine')
  listMine(@CurrentUser() user: { id: string; role: string }) {
    return this.servicesService.listMine(user);
  }

  @ApiBearerAuth()
  @Post()
  create(
    @CurrentUser() user: { id: string; role: string },
    @Body() dto: CreateServiceDto,
  ) {
    return this.servicesService.create(user, dto);
  }

  @ApiBearerAuth()
  @Patch(':id')
  update(
    @CurrentUser() user: { id: string; role: string },
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateServiceDto,
  ) {
    return this.servicesService.update(user, id, dto);
  }

  @ApiBearerAuth()
  @Delete(':id')
  remove(
    @CurrentUser() user: { id: string; role: string },
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.servicesService.remove(user, id);
  }
}
