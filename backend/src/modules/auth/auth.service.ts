import { ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
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

    const bcrypt = await import('bcryptjs');
    const passwordHash = await bcrypt.hash(dto.password, Number(process.env.BCRYPT_ROUNDS ?? 12));

    const user = await this.prisma.user.create({
      data: {
        email: dto.email.toLowerCase(),
        passwordHash,
        role: dto.role ?? 'CUSTOMER',
        profile:
          dto.firstName || dto.lastName || dto.phone
            ? {
                create: {
                  firstName: dto.firstName,
                  lastName: dto.lastName,
                  phone: dto.phone,
                },
              }
            : undefined,
      },
    });

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
