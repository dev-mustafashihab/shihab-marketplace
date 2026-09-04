import { IsOptional, IsString, MaxLength } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateProfileDto {
  @ApiPropertyOptional({ example: 'محمد' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  firstName?: string;

  @ApiPropertyOptional({ example: 'أحمد' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  lastName?: string;

  @ApiPropertyOptional({ example: '0938045496' })
  @IsOptional()
  @IsString()
  @MaxLength(30)
  phone?: string;

  @ApiPropertyOptional({ example: 'ar', maxLength: 10 })
  @IsOptional()
  @IsString()
  @MaxLength(10)
  locale?: string;

  // إعادة تقديم صور الهوية بعد الرفض — تُعيد الحالة لقيد المراجعة
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  idFrontUrl?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  idBackUrl?: string;
}
