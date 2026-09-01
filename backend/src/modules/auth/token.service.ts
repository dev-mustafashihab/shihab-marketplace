import { ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService, JwtSignOptions } from '@nestjs/jwt';
import { createHash, randomUUID } from 'crypto';
import { Prisma, User } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

export interface JwtPayload {
  sub: string;
  email: string;
  role: string;
  typ?: string;
}

const REFRESH_TTL_DAYS = 7;

const ACCESS_SIGN_OPTS: JwtSignOptions = {
  secret: process.env.JWT_ACCESS_SECRET,
  expiresIn: (process.env.JWT_ACCESS_TTL ?? '15m') as JwtSignOptions['expiresIn'],
};

const REFRESH_SIGN_OPTS: JwtSignOptions = {
  secret: process.env.JWT_REFRESH_SECRET,
  expiresIn: (process.env.JWT_REFRESH_TTL ?? '7d') as JwtSignOptions['expiresIn'],
};

@Injectable()
export class TokenService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) {}

  private sha256(input: string): string {
    return createHash('sha256').update(input).digest('hex');
  }

  async permissionsForRole(role: string): Promise<string[]> {
    if (role === 'ADMIN') return ['*'];
    const perms = await this.prisma.permission.findMany({
      where: { role: { key: role } },
      select: { key: true },
    });
    return perms.map((p) => p.key);
  }

  async issueTokens(
    user: Pick<User, 'id' | 'email' | 'role'>,
    meta?: { ip?: string; userAgent?: string },
  ): Promise<TokenPair> {
    const payload: JwtPayload = { sub: user.id, email: user.email, role: user.role };

    const accessToken = await this.jwtService.signAsync(payload, ACCESS_SIGN_OPTS);

    const refreshToken = await this.jwtService.signAsync(
      { ...payload, typ: 'refresh', jti: randomUUID() },
      REFRESH_SIGN_OPTS,
    );

    await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash: this.sha256(refreshToken),
        familyId: randomUUID(),
        expiresAt: new Date(Date.now() + REFRESH_TTL_DAYS * 24 * 60 * 60 * 1000),
        ip: meta?.ip,
        userAgent: meta?.userAgent?.slice(0, 255),
      },
    });

    return { accessToken, refreshToken };
  }

  /**
   * Rotates a refresh token: the presented token must be active; it is revoked
   * and replaced (same family) within one transaction. Reuse of a revoked
   * token revokes the whole family (theft detection).
   * Returns the NEW tokens that belong to the same family chain.
   */
  async rotate(
    rawToken: string,
    meta?: { ip?: string; userAgent?: string },
  ): Promise<{ user: Pick<User, 'id' | 'email' | 'role'>; accessToken: string; refreshToken: string }> {
    let payload: JwtPayload;
    try {
      payload = await this.jwtService.verifyAsync(rawToken, {
        secret: process.env.JWT_REFRESH_SECRET,
      });
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }
    if (payload.typ !== 'refresh') {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const stored = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: this.sha256(rawToken) },
    });
    if (!stored) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    if (stored.revokedAt) {
      await this.prisma.refreshToken.updateMany({
        where: { familyId: stored.familyId, revokedAt: null },
        data: { revokedAt: new Date(), revokedReason: 'FAMILY_REVOKED_REUSE_DETECTED' },
      });
      throw new UnauthorizedException('Refresh token reuse detected. All sessions were revoked.');
    }

    if (stored.expiresAt <= new Date()) {
      throw new UnauthorizedException('Refresh token expired');
    }

    const accessToken = await this.jwtService.signAsync(
      { sub: payload.sub, email: payload.email, role: payload.role },
      ACCESS_SIGN_OPTS,
    );

    const newRefreshToken = await this.jwtService.signAsync(
      { sub: payload.sub, email: payload.email, role: payload.role, typ: 'refresh', jti: randomUUID() },
      REFRESH_SIGN_OPTS,
    );

    await this.prisma.$transaction([
      this.prisma.refreshToken.create({
        data: {
          userId: stored.userId,
          tokenHash: this.sha256(newRefreshToken),
          familyId: stored.familyId,
          expiresAt: new Date(Date.now() + REFRESH_TTL_DAYS * 24 * 60 * 60 * 1000),
          ip: meta?.ip,
          userAgent: meta?.userAgent?.slice(0, 255),
        },
      }),
      this.prisma.refreshToken.update({
        where: { id: stored.id },
        data: { revokedAt: new Date(), revokedReason: 'ROTATED' },
      }),
    ]);

    try {
      const user = await this.prisma.user.findUniqueOrThrow({
        where: { id: stored.userId },
        select: { id: true, email: true, role: true },
      });
      return { user, accessToken, refreshToken: newRefreshToken };
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2025') {
        throw new UnauthorizedException('User is no longer active');
      }
      throw e;
    }
  }

  async revokeByToken(userId: string, rawToken?: string): Promise<void> {
    if (!rawToken) {
      await this.prisma.refreshToken.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date(), revokedReason: 'LOGOUT_ALL' },
      });
      return;
    }
    await this.prisma.refreshToken.updateMany({
      where: { userId, tokenHash: this.sha256(rawToken), revokedAt: null },
      data: { revokedAt: new Date(), revokedReason: 'LOGOUT' },
    });
  }
}
