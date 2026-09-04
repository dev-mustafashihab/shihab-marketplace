import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsOptional,
  IsPositive,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { CustomerWalletsService } from './customer-wallets.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

class WalletTxQueryDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @IsOptional()
  page?: number;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  @IsOptional()
  limit?: number;
}

class TopupDto {
  @IsUUID()
  userId!: string;

  @Type(() => Number)
  @IsInt()
  @IsPositive()
  amount!: number;

  @IsOptional()
  note?: string;
}

class PayBookingDto {
  @IsUUID()
  bookingId!: string;
}

class ChangePinDto {
  @IsOptional()
  @IsString()
  @MaxLength(6)
  currentPin?: string;

  @IsString()
  @MaxLength(6)
  newPin!: string;
}

@ApiTags('customer-wallet')
@ApiBearerAuth()
@Controller('customer-wallet')
export class CustomerWalletController {
  constructor(private readonly wallets: CustomerWalletsService) {}

  @Get()
  mine(
    @CurrentUser() user: { id: string; role: string },
    @Query() query: WalletTxQueryDto,
  ) {
    return this.wallets.getMine(user.id, query.page ?? 1, query.limit ?? 20);
  }

  @Post('topup')
  topup(@CurrentUser() user: { id: string; role: string }, @Body() dto: TopupDto) {
    return this.wallets.topup(user, dto);
  }

  @Post('pay-booking')
  payBooking(
    @CurrentUser() user: { id: string; role: string },
    @Body() dto: PayBookingDto,
  ) {
    return this.wallets.payBooking(user, dto.bookingId);
  }

  @Post('pin')
  changePin(
    @CurrentUser() user: { id: string; role: string },
    @Body() dto: ChangePinDto,
  ) {
    return this.wallets.changePin(user.id, dto.currentPin, dto.newPin);
  }
}
