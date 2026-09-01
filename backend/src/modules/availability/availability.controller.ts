import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Post, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsInt,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';
import { AvailabilityService } from './availability.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';

class AvailabilityRuleDto {
  @Type(() => Number) @IsInt() @Min(0) @Max(6) weekday!: number;
  @Type(() => Number) @IsInt() @Min(0) @Max(1440) startMin!: number;
  @Type(() => Number) @IsInt() @Min(0) @Max(1440) endMin!: number;
}

class ReplaceRulesDto {
  @IsArray() @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => AvailabilityRuleDto)
  rules!: AvailabilityRuleDto[];
}

@ApiTags('availability')
@Controller('availability')
export class AvailabilityController {
  constructor(private readonly availabilityService: AvailabilityService) {}

  /** عام: جدول أسبوع المورد */
  @Public()
  @Get('resource/:resourceId')
  listForResource(@Param('resourceId', ParseUUIDPipe) resourceId: string) {
    return this.availabilityService.listForResource(resourceId);
  }

  /** البائع: استبدال جدول موجه كاملاً */
  @ApiBearerAuth()
  @Put('resource/:resourceId')
  replace(
    @CurrentUser() user: { id: string; role: string },
    @Param('resourceId', ParseUUIDPipe) resourceId: string,
    @Body() dto: ReplaceRulesDto,
  ) {
    return this.availabilityService.replaceForOwner(
      user,
      resourceId,
      dto.rules.map((r) => ({
        weekday: r.weekday,
        startMin: r.startMin,
        endMin: r.endMin,
      })),
    );
  }
}
