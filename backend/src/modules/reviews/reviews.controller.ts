import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { ReviewsService } from './reviews.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';

class CreateReviewDto {
  @IsOptional() @IsUUID() bookingId?: string;
  @IsOptional() @IsUUID() orderId?: string;
  @Type(() => Number) @IsInt() @Min(1) @Max(5) rating!: number;
  @IsOptional() @IsString() @MaxLength(1000) comment?: string;
}

class ListReviewsQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) limit?: number;
}

@ApiTags('reviews')
@Controller('reviews')
export class ReviewsController {
  constructor(private readonly reviewsService: ReviewsService) {}

  @ApiBearerAuth()
  @Post()
  create(@CurrentUser() user: { id: string; role: string }, @Body() dto: CreateReviewDto) {
    return this.reviewsService.create(user, dto);
  }

  @Public()
  @Get('vendor/:vendorId')
  listForVendor(
    @Param('vendorId', ParseUUIDPipe) vendorId: string,
    @Query() query: ListReviewsQueryDto,
  ) {
    return this.reviewsService.listForVendor(vendorId, query.page ?? 1, query.limit ?? 20);
  }
}
