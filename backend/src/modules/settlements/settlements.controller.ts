import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';
import { IsUUID } from 'class-validator';
import { WalletsService } from './wallets.service';
import { PayoutsService } from './payouts.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Permissions } from '../../common/decorators/permissions.decorator';

class PayoutRequestDto {
  @Type(() => Number) @IsInt() @Min(1) amount!: number;
  @IsOptional() note?: string;
}

class PayoutDecisionDto {
  @IsOptional() note?: string;
}

class WalletTxQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) limit?: number;
}

@ApiTags('wallets')
@ApiBearerAuth()
@Controller('wallet')
export class SettlementsController {
  constructor(
    private readonly walletsService: WalletsService,
    private readonly payoutsService: PayoutsService,
  ) {}

  /** البائع: محفظته + سجل الحركات (Ledger) */
  @Get()
  myWallet(@CurrentUser() user: { id: string; role: string }, @Query() query: WalletTxQueryDto) {
    return this.walletsService.getWalletForOwner(user.id, query.page ?? 1, query.limit ?? 20);
  }

  /** البائع: طلب سحب */
  @Post('payouts')
  requestPayout(
    @CurrentUser() user: { id: string; role: string },
    @Body() dto: PayoutRequestDto,
  ) {
    return this.payoutsService.requestPayout(user, dto.amount, dto.note);
  }

  /** البائع: سحوباته */
  @Get('payouts')
  myPayouts(
    @CurrentUser() user: { id: string; role: string },
    @Query() query: WalletTxQueryDto,
  ) {
    return this.payoutsService.listForVendor(user, query.page ?? 1, query.limit ?? 20);
  }

  /** الأدمن: اعتماد/تنفيذ/رفض السحب */
  @Patch('payouts/:id/approve')
  @Permissions('payouts:manage')
  approve(@CurrentUser() user: { id: string; role: string }, @Param('id', ParseUUIDPipe) id: string, @Body() dto: PayoutDecisionDto) {
    return this.payoutsService.decide(user, id, 'APPROVED', dto.note);
  }

  @Patch('payouts/:id/mark-paid')
  @Permissions('payouts:manage')
  markPaid(@CurrentUser() user: { id: string; role: string }, @Param('id', ParseUUIDPipe) id: string, @Body() dto: PayoutDecisionDto) {
    return this.payoutsService.decide(user, id, 'PAID', dto.note);
  }

  @Patch('payouts/:id/reject')
  @Permissions('payouts:manage')
  reject(@CurrentUser() user: { id: string; role: string }, @Param('id', ParseUUIDPipe) id: string, @Body() dto: PayoutDecisionDto) {
    return this.payoutsService.decide(user, id, 'FAILED', dto.note);
  }
}
