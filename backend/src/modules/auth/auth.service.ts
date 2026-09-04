import { BadRequestException, ConflictException, ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { createHash } from 'crypto';
import { PrismaService } from '../../common/prisma.service';
import { TokenService, TokenPair } from './token.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';

const MAX_FAILED_ATTEMPTS = 5;
const LOCK_MINUTES = 15;
// bcrypt hash of a random string — used to equalize timing when user not found
const DUMMY_HASH = '$2b$12$C6UzMDM.H6dfI/f/IKcEeO7ZUbE0f5bUYRXu8lqBGrRr8WiQFgoLu';
// نسخة نص الموافقة القانونية — أي تعديل على النص = نسخة جديدة
const CONSENT_VERSION = 'kyc-v1';

export interface AuthUser {
  id: string;
  email: string;
  role: string;
  status: string;
  permissions: string[];
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly tokenService: TokenService,
  ) {}

  async register(dto: RegisterDto, meta?: { ip?: string; userAgent?: string }): Promise<TokenPair> {
    const existing = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase() },
    });
    if (existing) {
      throw new ForbiddenException('Registration failed');
    }
    const role = dto.role ?? 'CUSTOMER';

    // ── توثيق الزبون العادي: حقول إجبارية + تحقق صيغ ──
    let kyc: Record<string, unknown> | undefined;
    if (role === 'CUSTOMER') {
      // الاسم: إما ثلاثي جاهز (عملاء قدامى) أو مفصل من شاشة المحفظة
      const first = dto.firstName?.trim() ?? '';
      const father = dto.fatherName?.trim() ?? '';
      const last = dto.lastName?.trim() ?? '';
      let fullName = dto.fullName?.trim() ?? '';
      if (!fullName && first && father && last) {
        fullName = `${first} ${father} ${last}`;
      }
      if (!fullName || fullName.length < 5) {
        throw new BadRequestException('الاسم الثلاثي مطلوب ومطابق للهوية');
      }
      // أسماء الأم — إجبارية من شاشة المحفظة الجديدة، اختيارية للعملاء القدامى
      for (const [v, label] of [
        [dto.motherName, 'اسم الأم'],
        [dto.motherFatherName, 'اسم والد الأم'],
        [dto.motherMaidenName, 'كنية الأم'],
      ] as const) {
        if (v !== undefined && v.trim().length < 2) {
          throw new BadRequestException(`${label} غير صالح`);
        }
      }
      if (!dto.nationalId || !/^\d{11}$/.test(dto.nationalId)) {
        throw new BadRequestException('الرقم الوطني يجب أن يكون 11 رقماً');
      }
      const dup = await this.prisma.profile.findUnique({
        where: { nationalId: dto.nationalId },
        select: { userId: true },
      });
      if (dup) throw new ConflictException('هذا الرقم الوطني مسجل مسبقاً');
      const birth = dto.birthDate ? new Date(dto.birthDate) : null;
      if (!birth || Number.isNaN(birth.getTime())) {
        throw new BadRequestException('تاريخ الميلاد غير صالح');
      }
      const age = (Date.now() - birth.getTime()) / (365.25 * 24 * 3600 * 1000);
      if (age < 18) throw new BadRequestException('التسجيل متاح لمن بلغ 18 سنة فأكثر');
      if (!dto.phone || !/^(?:\+963|00963|0)?9\d{8}$/.test(dto.phone.replace(/[\s-]/g, ''))) {
        throw new BadRequestException('رقم الموبايل غير صالح — مثال: 09XXXXXXXX أو +9639XXXXXXXX');
      }
      const phoneNorm = dto.phone.replace(/[\s-]/g, '').replace(/^(?:\+963|00963)/, '0');
      if (!dto.governorate?.trim() || !dto.city?.trim()) {
        throw new BadRequestException('المحافظة والمدينة مطلوبتان');
      }
      if (dto.consentAccepted !== true) {
        throw new ForbiddenException('يجب الموافقة على الشروط ومعالجة البيانات');
      }
      // رقم حساب المحفظة: تطبيع (إزالة شرطات/مسافات) + تحقق 16 رقماً + فرادة
      const bcrypt = await import('bcryptjs');
      let walletAccountId: string | undefined;
      if (dto.walletAccountId?.trim()) {
        const norm = dto.walletAccountId.replace(/[\s-]/g, '');
        if (!/^\d{16}$/.test(norm)) {
          throw new BadRequestException('رقم حساب المحفظة يجب أن يكون 16 رقماً');
        }
        const dupAcc = await this.prisma.profile.findUnique({
          where: { walletAccountId: norm },
          select: { userId: true },
        });
        if (dupAcc) throw new ConflictException('رقم حساب المحفظة مستخدم مسبقاً');
        walletAccountId = norm;
      } else {
        // توليد تلقائي فريد من 16 رقماً (لا يبدأ بصفر)
        for (let i = 0; i < 8; i++) {
          const gen =
            String(1 + Math.floor(Math.random() * 9)) +
            Array.from({ length: 15 }, () => Math.floor(Math.random() * 10)).join('');
          const exists = await this.prisma.profile.findUnique({
            where: { walletAccountId: gen },
            select: { userId: true },
          });
          if (!exists) { walletAccountId = gen; break; }
        }
        if (!walletAccountId) throw new BadRequestException('تعذر توليد رقم محفظة، أعد المحاولة');
      }
      // رمز الحماية: 4 أو 6 أرقام — يُخزّن بصمة bcrypt فقط (اختياري للعملاء القدامى)
      let walletPinHash: string | undefined;
      if (dto.walletPin !== undefined && dto.walletPin !== '') {
        if (!/^\d{4}$|^\d{6}$/.test(dto.walletPin)) {
          throw new BadRequestException('رمز حماية المحفظة يجب أن يكون 4 أو 6 أرقام');
        }
        walletPinHash = await bcrypt.hash(dto.walletPin, 10);
      }
      kyc = {
        fullName,
        firstName: first || dto.firstName || null,
        lastName: last || dto.lastName || null,
        fatherName: father || null,
        motherName: dto.motherName?.trim() || null,
        motherFatherName: dto.motherFatherName?.trim() || null,
        motherMaidenName: dto.motherMaidenName?.trim() || null,
        walletAccountId,
        walletPinHash: walletPinHash ?? null,
        nationalId: dto.nationalId,
        birthDate: birth,
        phone: phoneNorm,
        governorate: dto.governorate.trim(),
        city: dto.city.trim(),
        address: dto.address?.trim() || null,
        idFrontUrl: dto.idFrontUrl || null,
        idBackUrl: dto.idBackUrl || null,
        consentVersion: CONSENT_VERSION,
        consentedAt: new Date(),
      };
    }

    const bcrypt = await import('bcryptjs');
    const passwordHash = await bcrypt.hash(dto.password, Number(process.env.BCRYPT_ROUNDS ?? 12));

    let user: Parameters<TokenService['issueTokens']>[0];
    try {
      user = await this.prisma.user.create({
        data: {
          email: dto.email.toLowerCase(),
          passwordHash,
          role,
          profile:
            kyc ?? (dto.firstName || dto.lastName || dto.phone)
              ? {
                  create: {
                    firstName: dto.firstName,
                    lastName: dto.lastName,
                    phone: dto.phone,
                    ...(kyc ?? {}),
                  },
                }
              : undefined,
          consents:
            role === 'CUSTOMER'
              ? { create: { version: CONSENT_VERSION, ip: meta?.ip } }
              : undefined,
        },
      });
    } catch (e: unknown) {
      if (typeof e === 'object' && e !== null && 'code' in e && (e as { code: string }).code === 'P2002') {
        throw new ConflictException('هذا الرقم الوطني مسجل مسبقاً');
      }
      throw e;
    }

    return this.tokenService.issueTokens(user, meta);
  }

  /** يتحقق من بيانات الدخول ويرجع المستخدم (يُستخدم في login envelope) */
  async resolveLoginUser(dto: LoginDto) {
    const bcrypt = await import('bcryptjs');
    const genericError = new UnauthorizedException('Invalid credentials');
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase() },
    });
    if (!user || user.status !== 'ACTIVE') throw genericError;
    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) throw genericError;
    return user;
  }

  async login(dto: LoginDto, meta?: { ip?: string; userAgent?: string }): Promise<TokenPair> {
    const bcrypt = await import('bcryptjs');
    const genericError = new UnauthorizedException('Invalid credentials');

    const user = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase() },
    });

    if (user?.lockedUntil && user.lockedUntil > new Date()) {
      throw new ForbiddenException(
        'Account temporarily locked due to failed attempts. Try again later.',
      );
    }

    if (!user || user.status !== 'ACTIVE') {
      await bcrypt.compare(dto.password, DUMMY_HASH); // uniform timing
      throw genericError;
    }

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) {
      // PHASE 13: زيادة ذرية — فشلان متزامنان = +2 لا +1 (لا قراءة-ثم-كتابة)
      const willLock = user.failedAttempts + 1 >= MAX_FAILED_ATTEMPTS;
      const lockedUntil = willLock
          ? new Date(Date.now() + LOCK_MINUTES * 60 * 1000)
          : null;
      await this.prisma.user.update({
        where: { id: user.id },
        data: {
          failedAttempts: { increment: 1 },
          lockedUntil,
        },
      });
      throw genericError;
    }

    if (user.failedAttempts > 0 || user.lockedUntil) {
      await this.prisma.user.update({
        where: { id: user.id },
        data: { failedAttempts: 0, lockedUntil: null },
      });
    }

    return this.tokenService.issueTokens(user, meta);
  }

  async refresh(rawRefreshToken: string, meta?: { ip?: string; userAgent?: string }): Promise<TokenPair> {
    // rotate() returns the next tokens in the SAME family chain, so reuse
    // detection revokes the client's actual session.
    return this.tokenService.rotate(rawRefreshToken, meta);
  }

  async logout(userId: string, rawRefreshToken?: string) {
    await this.tokenService.revokeByToken(userId, rawRefreshToken);
    return { logout: true };
  }

  async me(userId: string): Promise<AuthUser> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user || user.status !== 'ACTIVE') {
      throw new UnauthorizedException('User is no longer active');
    }
    const permissions = await this.tokenService.permissionsForRole(user.role);
    return {
      id: user.id,
      email: user.email,
      role: user.role,
      status: user.status,
      permissions,
    };
  }
}
