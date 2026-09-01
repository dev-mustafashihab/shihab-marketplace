import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsDateString,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { BookingStatus } from '@prisma/client';
import { BookingsService } from './bookings.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

class CreateBookingDto {
  @IsUUID() vendorId!: string;

  @IsUUID() resourceId!: string;

  @IsOptional() @IsUUID() serviceId?: string;

  @IsDateString({}, { message: 'startsAt must be an ISO 8601 date' })
  startsAt!: string;

  @IsDateString({}, { message: 'endsAt must be an ISO 8601 date' })
  endsAt!: string;

  @IsOptional() @IsString() @MaxLength(500) customerNote?: string;

  /** Idempotency: يولده العميل ويُعاد استخدامه عند إعادة الإرسال */
  @IsOptional() @IsString() @MaxLength(64) clientRequestId?: string;
}

class ListBookingsQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) limit?: number;
}

class DecideDto {
  @IsOptional() @IsString() @MaxLength(255) reason?: string;
}

@ApiTags('bookings')
@ApiBearerAuth()
@Controller('bookings')
export class BookingsController {
  constructor(private readonly bookingsService: BookingsService) {}

  @Post()
  create(@CurrentUser() user: { id: string; role: string }, @Body() dto: CreateBookingDto) {
    return this.bookingsService.create(user, {
      ...dto,
      startsAt: new Date(dto.startsAt),
      endsAt: new Date(dto.endsAt),
    });
  }

  @Get('mine')
  listMine(
    @CurrentUser() user: { id: string; role: string },
    @Query() query: ListBookingsQueryDto,
  ) {
    return this.bookingsService.listMine(user, query.page, query.limit);
  }

  /** طوابير البائع: حجوزات متجره بفلتر الحالة */
  @Get('vendor/queue')
  vendorQueue(
    @CurrentUser() user: { id: string; role: string },
    @Query('status') status: BookingStatus | undefined,
    @Query() query: ListBookingsQueryDto,
  ) {
    const valid = status && ['PENDING','CONFIRMED','CANCELLED','REJECTED','COMPLETED','EXPIRED'].includes(status)
      ? (status as BookingStatus) : undefined;
    return this.bookingsService.listForVendor(user, valid, query.page, query.limit);
  }

  @Get(':id')
  getOne(@CurrentUser() user: { id: string; role: string }, @Param('id', ParseUUIDPipe) id: string) {
    return this.bookingsService.getOne(user, id);
  }

  @Patch(':id/cancel')
  cancel(
    @CurrentUser() user: { id: string; role: string },
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: DecideDto,
  ) {
    return this.bookingsService.cancel(user, id, dto.reason);
  }

  @Patch(':id/confirm')
  confirm(
    @CurrentUser() user: { id: string; role: string },
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: DecideDto,
  ) {
    return this.bookingsService.decide(user, id, 'CONFIRMED', dto.reason);
  }

  @Patch(':id/reject')
  reject(
    @CurrentUser() user: { id: string; role: string },
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: DecideDto,
  ) {
    return this.bookingsService.decide(user, id, 'REJECTED', dto.reason);
  }

  @Patch(':id/complete')
  complete(
    @CurrentUser() user: { id: string; role: string },
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.bookingsService.complete(user, id);
  }
}
