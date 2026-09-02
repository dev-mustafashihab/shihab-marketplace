import { BadRequestException, Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { OrderStatus } from '@prisma/client';
import { OrdersService } from './orders.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

class CheckoutDto {
  @IsString() @MinLength(5) @MaxLength(500) address!: string;
  @IsString() @MinLength(5) @MaxLength(30) phone!: string;
  @IsOptional() @IsString() @MaxLength(500) note?: string;
  @IsOptional() @IsString() @MaxLength(64) clientRequestId?: string;
}

class ListOrdersQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) limit?: number;
}

class TransitionDto {
  @IsOptional() @IsString() @MaxLength(255) reason?: string;
}

class VendorQueueQueryDto extends ListOrdersQueryDto {
  @IsOptional() status?: OrderStatus;
}

@ApiTags('orders')
@ApiBearerAuth()
@Controller('orders')
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  /** Checkout: السلة الحالية → طلب */
  @Post('checkout')
  checkout(@CurrentUser() user: { id: string; role: string }, @Body() dto: CheckoutDto) {
    return this.ordersService.checkout(user, dto);
  }

  @Get('mine')
  listMine(@CurrentUser() user: { id: string; role: string }, @Query() query: ListOrdersQueryDto) {
    return this.ordersService.listMine(user, query.page, query.limit);
  }

  /** طوابير البائع */
  @Get('vendor/queue')
  vendorQueue(
    @CurrentUser() user: { id: string; role: string },
    @Query() query: VendorQueueQueryDto,
  ) {
    return this.ordersService.listForVendor(user, query.status, query.page, query.limit);
  }

  @Get(':id')
  getOne(@CurrentUser() user: { id: string; role: string }, @Param('id', ParseUUIDPipe) id: string) {
    return this.ordersService.getOne(user, id);
  }

  @Patch(':id/cancel')
  cancel(@CurrentUser() user: { id: string; role: string }, @Param('id', ParseUUIDPipe) id: string, @Body() dto: TransitionDto) {
    return this.ordersService.transition(user, id, 'CANCELLED' as OrderStatus, dto.reason ?? 'CUSTOMER_CANCELLED');
  }

  /** مسار البائع: confirm → preparing → ready → out_for_delivery → delivered */
  @Patch(':id/status/:to')
  transition(
    @CurrentUser() user: { id: string; role: string },
    @Param('id', ParseUUIDPipe) id: string,
    @Param('to') to: string,
    @Body() dto: TransitionDto,
  ) {
    // PHASE 7 FIX: حالة غير معروفة = 400 — يُمنع أي fallback إلى CANCELLED
    const valid: Record<string, boolean> = {
      CONFIRMED: true, PREPARING: true, READY: true,
      OUT_FOR_DELIVERY: true, DELIVERED: true, REFUNDED: true,
    };
    if (!valid[to]) {
      throw new BadRequestException(`Invalid order status: ${to}`);
    }
    return this.ordersService.transition(user, id, to as OrderStatus, dto.reason);
  }
}
