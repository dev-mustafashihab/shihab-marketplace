import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsUUID, Min } from 'class-validator';
import { CartsService } from './carts.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

class AddCartItemDto {
  @IsUUID() productId!: string;
  @Type(() => Number) @IsInt() @Min(1) quantity!: number;
}

class UpdateCartItemDto {
  @IsUUID() productId!: string;
  @Type(() => Number) @IsInt() @Min(0) quantity!: number;
}

@ApiTags('cart')
@ApiBearerAuth()
@Controller('cart')
export class CartsController {
  constructor(private readonly cartsService: CartsService) {}

  @Get()
  getMine(@CurrentUser('id') customerId: string) {
    return this.cartsService.getMine(customerId);
  }

  @Post('items')
  addItem(@CurrentUser('id') customerId: string, @Body() dto: AddCartItemDto) {
    return this.cartsService.addItem(customerId, dto.productId, dto.quantity);
  }

  @Patch('items')
  updateQuantity(@CurrentUser('id') customerId: string, @Body() dto: UpdateCartItemDto) {
    return this.cartsService.updateQuantity(customerId, dto.productId, dto.quantity);
  }

  @Delete()
  clear(@CurrentUser('id') customerId: string) {
    return this.cartsService.clear(customerId);
  }
}
