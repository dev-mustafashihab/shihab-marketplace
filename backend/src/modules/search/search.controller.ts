import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { SearchService } from './search.service';
import { Public } from '../../common/decorators/public.decorator';

class SearchQueryDto {
  @IsOptional() @IsString() @MaxLength(100) q?: string;
  @IsOptional() @IsUUID() categoryId?: string;
  @IsOptional() @Type(() => Number) @IsNumber() minRating?: number;
  @IsOptional() @Type(() => Number) @IsNumber() maxPrice?: number;
  @IsOptional() @Type(() => Number) @IsNumber() lat?: number;
  @IsOptional() @Type(() => Number) @IsNumber() lng?: number;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0.1) @Max(100) radiusKm?: number;
  @IsOptional() @Type(() => Boolean) @IsBoolean() openNow?: boolean;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) capacity?: number;
  @IsOptional() @IsIn(['price', 'distance']) sort?: 'price' | 'distance';
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) limit?: number;
}

@ApiTags('search')
@Controller('search')
export class SearchController {
  constructor(private readonly searchService: SearchService) {}

  /** البحث العام — PostGIS radius عند توفر lat/lng/radiusKm */
  @Public()
  @Get()
  search(@Query() query: SearchQueryDto) {
    return this.searchService.searchVendors({
      q: query.q,
      categoryId: query.categoryId,
      maxPrice: query.maxPrice,
      lat: query.lat,
      lng: query.lng,
      radiusKm: query.radiusKm,
      capacity: query.capacity,
      minRating: query.minRating,
      openNow: query.openNow,
      sort: query.sort,
      page: query.page ?? 1,
      limit: query.limit ?? 20,
    });
  }

  /** Home feed مجمّع */
  @Public()
  @Get('home')
  home(@Query() query: SearchQueryDto) {
    return this.searchService.homeFeed(query.lat, query.lng);
  }
}
