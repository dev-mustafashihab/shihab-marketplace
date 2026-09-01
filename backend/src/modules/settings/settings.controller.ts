import { Body, Controller, Get, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, Min, MaxLength } from 'class-validator';
import { Permissions } from '../../common/decorators/permissions.decorator';
import { SettingsService } from './settings.service';

class UpdateFinancialDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(0) @Max(50) commissionPercent?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(0) deliveryFeeDefault?: number;
  @IsOptional() @IsString() @MaxLength(3) currency?: string;
}

@ApiTags('settings')
@ApiBearerAuth()
@Controller('settings')
export class SettingsController {
  constructor(private readonly settingsService: SettingsService) {}

  @Get('financial')
  @Permissions('settings:manage')
  getFinancial() {
    return this.settingsService.getFinancial();
  }

  @Patch('financial')
  @Permissions('settings:manage')
  updateFinancial(@Body() dto: UpdateFinancialDto) {
    return this.settingsService.setFinancial(dto);
  }
}
