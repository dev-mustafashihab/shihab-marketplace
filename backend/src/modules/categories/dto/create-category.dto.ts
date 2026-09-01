import { IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';
import { IsBoolean } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class CreateCategoryDto {
  @ApiPropertyOptional({ example: 'Venues' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;

  @ApiPropertyOptional({ example: 'قاعات' })
  @IsString()
  @MaxLength(100)
  nameAr!: string;

  @ApiPropertyOptional({ example: 'venues' })
  @IsString()
  @MaxLength(120)
  slug!: string;

  @ApiPropertyOptional({ example: 'venue' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  iconKey?: string;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
