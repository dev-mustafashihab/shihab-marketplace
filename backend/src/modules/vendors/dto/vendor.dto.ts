import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { VendorStatus } from '@prisma/client';

export class CreateVendorDto {
  @ApiPropertyOptional({ example: 'قصر الأمل للاحتفالات' })
  @IsString()
  @MinLength(3)
  @MaxLength(150)
  name!: string;

  @ApiPropertyOptional({ example: 'qasr-alam' })
  @IsString()
  @MaxLength(170)
  slug!: string;

  @ApiPropertyOptional()
  @IsString()
  @MaxLength(36)
  categoryId!: string;

  @ApiPropertyOptional({ example: 'قاعة أفراح فخمة وسط المدينة' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ example: '0938045496' })
  @IsOptional()
  @IsString()
  @MaxLength(30)
  phone?: string;

  @ApiPropertyOptional({ example: 'دمشق - المزة' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  address?: string;

  @ApiPropertyOptional({ example: 33.5138 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  latitude?: number;

  @ApiPropertyOptional({ example: 36.2765 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  longitude?: number;
}

export class UpdateVendorDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  imageUrl?: string;

  @IsOptional() @IsString() @MinLength(3) @MaxLength(150) name?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() @MaxLength(30) phone?: string;
  @IsOptional() @IsString() @MaxLength(255) address?: string;
  @IsOptional() @Type(() => Number) @IsNumber() latitude?: number;
  @IsOptional() @Type(() => Number) @IsNumber() longitude?: number;
  @IsOptional() @Type(() => Boolean) @IsBoolean() isOpen?: boolean;
  @IsOptional() @Type(() => Number) @IsInt() @Min(0) minPrice?: number;
  // Admin-only fields — service يجب أن يتحقق من الدور قبل تطبيقها
  @IsOptional() @IsEnum(VendorStatus) status?: VendorStatus;
  @IsOptional() @IsString() @MaxLength(255) rejectionReason?: string;
}

export class ListVendorsQueryDto {
  @ApiPropertyOptional({ example: 1 })
  @IsOptional() @Type(() => Number) @IsInt() @Min(1)
  page?: number;

  @ApiPropertyOptional({ example: 20 })
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100)
  limit?: number;

  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(36)
  categoryId?: string;

  @ApiPropertyOptional({ example: 'قاعة' })
  @IsOptional() @IsString() @MaxLength(100)
  q?: string;

  @ApiPropertyOptional({ example: 4, description: 'حد أدنى للتقييم (احتياطي للتقييمات لاحقاً)' })
  @IsOptional() @Type(() => Number) @IsNumber()
  minRating?: number;

  @ApiPropertyOptional({ enum: VendorStatus, description: 'أدمن فقط' })
  @IsOptional() @IsEnum(VendorStatus)
  status?: VendorStatus;
}
