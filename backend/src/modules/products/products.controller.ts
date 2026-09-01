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
import { ProductsService } from './products.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';

class CreateProductDto {
  @IsString() @MinLength(2) @MaxLength(150) name!: string;
  @IsOptional() @IsString() description?: string;
  @Type(() => Number) @IsInt() @Min(0) price!: number;
  @IsOptional() @IsString() @MaxLength(3) currency?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(0) stock?: number;
}

class UpdateProductDto {
  @IsOptional() @IsString() @MinLength(2) @MaxLength(150) name?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(0) price?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(0) stock?: number;
  @IsOptional() @IsBoolean() isActive?: boolean;
}

@ApiTags('products')
@Controller('products')
export class ProductsController {
  constructor(private readonly productsService: ProductsService) {}

  @Public()
  @Get('vendor/:vendorId')
  listPublic(@Param('vendorId', ParseUUIDPipe) vendorId: string) {
    return this.productsService.listPublicByVendor(vendorId);
  }

  @ApiBearerAuth()
  @Get('mine')
  listMine(@CurrentUser() user: { id: string; role: string }) {
    return this.productsService.listMine(user);
  }

  @ApiBearerAuth()
  @Post()
  create(
    @CurrentUser() user: { id: string; role: string },
    @Body() dto: CreateProductDto,
  ) {
    return this.productsService.create(user, dto);
  }

  @ApiBearerAuth()
  @Patch(':id')
  update(
    @CurrentUser() user: { id: string; role: string },
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateProductDto,
  ) {
    return this.productsService.update(user, id, dto);
  }

  @ApiBearerAuth()
  @Delete(':id')
  remove(
    @CurrentUser() user: { id: string; role: string },
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.productsService.remove(user, id);
  }
}
