import {
  IsEmail,
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';

export class RegisterDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail({}, { message: 'email must be a valid email address' })
  @MaxLength(255)
  email!: string;

  @ApiProperty({ example: 'Str0ng!Passw0rd', description: 'Min 8 chars incl. upper, lower, digit, symbol' })
  @IsString()
  @MinLength(8, { message: 'password must be at least 8 characters' })
  @MaxLength(72)
  password!: string;

  @ApiPropertyOptional({ enum: [UserRole.CUSTOMER, UserRole.VENDOR], default: UserRole.CUSTOMER })
  @IsOptional()
  @IsEnum(UserRole, { message: 'role must be CUSTOMER or VENDOR' })
  role?: UserRole;

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
}
