import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsUUID, Min } from 'class-validator';
import { PaymentsService } from './payments.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Permissions } from '../../common/decorators/permissions.decorator';

class CreatePaymentDto {
  @IsOptional() @IsUUID() bookingId?: string;
  @IsOptional() @IsUUID() orderId?: string;
}

class ListPaymentsQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page_size?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) limit?: number;
}

@ApiTags('payments')
@ApiBearerAuth()
@Controller('payments')
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  /** العميل ينشئ دفعة manual (تحويل بنكي) على حجز أو طلب */
  @Post()
  create(@CurrentUser() user: { id: string; role: string }, @Body() dto: CreatePaymentDto) {
    return this.paymentsService.createManualPayment(user, { bookingId: dto.bookingId, orderId: dto.orderId });
  }

  /** الأدمن يؤكد استلام التحويل → يظهر أثره على الحجز/الطلب والمحفظة */
  @Patch(':id/confirm')
  @Permissions('refunds:manage')
  confirm(@CurrentUser() user: { id: string; role: string }, @Param('id', ParseUUIDPipe) id: string) {
    return this.paymentsService.confirm(id, user);
  }

  @Get()
  @Permissions('refunds:manage')
  list(@Query() query: ListPaymentsQueryDto) {
    return this.paymentsService.listAll(query.page ?? 1, query.limit ?? 20);
  }
}
