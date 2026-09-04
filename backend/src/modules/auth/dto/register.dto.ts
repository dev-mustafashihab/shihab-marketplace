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

  // ── توثيق الزبون العادي (إجباري عند role=CUSTOMER — يُتحقق بالخدمة) ──
  @ApiPropertyOptional({ example: 'محمد أحمد الحسن' })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  fullName?: string;

  // ── النسب المفصل — شاشة تسجيل المحفظة (يُركّب منها fullName عند غيابه) ──
  @ApiPropertyOptional({ example: 'محمد' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  fatherName?: string;

  @ApiPropertyOptional({ example: 'فاطمة' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  motherName?: string;

  @ApiPropertyOptional({ example: 'عبد الله' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  motherFatherName?: string;

  @ApiPropertyOptional({ example: 'الحسن' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  motherMaidenName?: string;

  // ── حساب المحفظة: 16 رقماً (تُقبل مع شرطات/مسافات وتُطبّع) — يُولّد تلقائياً عند غيابه ──
  @ApiPropertyOptional({ example: '1234-5678-9012-3456' })
  @IsOptional()
  @IsString()
  @MaxLength(19)
  walletAccountId?: string;

  // ── رمز حماية المحفظة: 4 أو 6 أرقام (يُخزّن بصمة فقط) ──
  @ApiPropertyOptional({ example: '123456' })
  @IsOptional()
  @IsString()
  @MaxLength(6)
  walletPin?: string;

  @ApiPropertyOptional({ example: '01123456789' })
  @IsOptional()
  @IsString()
  @MaxLength(11)
  nationalId?: string;

  @ApiPropertyOptional({ example: '1995-06-14' })
  @IsOptional()
  @IsString()
  birthDate?: string;

  @ApiPropertyOptional({ example: 'دمشق' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  governorate?: string;

  @ApiPropertyOptional({ example: 'المزة' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  city?: string;

  @ApiPropertyOptional({ example: 'شارع الجلاء، بناء 12' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  address?: string;

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

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  consentAccepted?: boolean;
}
