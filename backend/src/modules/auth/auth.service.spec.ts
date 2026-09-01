import { ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Test } from '@nestjs/testing';
import { AuthService } from './auth.service';
import { TokenService } from './token.service';
import { PrismaService } from '../../common/prisma.service';

describe('AuthService (unit)', () => {
  let service: AuthService;
  let prisma: { user: { findUnique: jest.Mock; update: jest.Mock; create: jest.Mock } };
  let jwt: { signAsync: jest.Mock };
  let tokens: { issueTokens: jest.Mock; permissionsForRole: jest.Mock; rotate: jest.Mock };

  const activeUser = {
    id: 'u-1',
    email: 'user@test.local',
    passwordHash: '$2a$04$yOvCdTwuDPSWIVCY8e7WOejpDoh09DIUWos.bIKwB7lNDs1znrAS6',
    role: 'CUSTOMER',
    status: 'ACTIVE',
    failedAttempts: 0,
    lockedUntil: null as Date | null,
  };

  beforeEach(async () => {
    process.env.BCRYPT_ROUNDS = '4';

    prisma = {
      user: {
        findUnique: jest.fn(),
        update: jest.fn().mockResolvedValue(activeUser),
        create: jest.fn().mockResolvedValue(activeUser),
      },
    };
    jwt = { signAsync: jest.fn().mockResolvedValue('jwt-token') };
    tokens = {
      issueTokens: jest.fn().mockResolvedValue({ accessToken: 'at', refreshToken: 'rt' }),
      permissionsForRole: jest.fn().mockResolvedValue([]),
      rotate: jest.fn(),
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prisma },
        { provide: JwtService, useValue: jwt },
        { provide: TokenService, useValue: tokens },
      ],
    }).compile();

    service = moduleRef.get(AuthService);
  });

  describe('register', () => {
    it('rejects duplicate email without leaking existence details', async () => {
      prisma.user.findUnique.mockResolvedValueOnce(activeUser);
      await expect(
        service.register({ email: 'user@test.local', password: 'Str0ng!Pass' }),
      ).rejects.toThrow(ForbiddenException);
      expect(prisma.user.create).not.toHaveBeenCalled();
    });

    it('creates user with hashed password and issues tokens', async () => {
      prisma.user.findUnique.mockResolvedValueOnce(null);
      const result = await service.register({
        email: 'New@Test.local',
        password: 'Str0ng!Pass',
        firstName: 'first',
      });
      expect(result).toEqual({ accessToken: 'at', refreshToken: 'rt' });
      const created = prisma.user.create.mock.calls[0][0].data;
      expect(created.email).toBe('new@test.local');
      expect(created.passwordHash).toMatch(/^\$2[aby]\$/);
      expect(created.passwordHash).not.toContain('Str0ng');
    });
  });

  describe('login', () => {
    it('returns uniform 401 for unknown user', async () => {
      prisma.user.findUnique.mockResolvedValueOnce(null);
      await expect(
        service.login({ email: 'ghost@test.local', password: 'Whatever!1' }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('locks the account after 5 failed attempts', async () => {
      prisma.user.findUnique
        .mockResolvedValueOnce({ ...activeUser, failedAttempts: 4 })
        .mockResolvedValueOnce({ ...activeUser, failedAttempts: 5, lockedUntil: new Date(Date.now() + 60000) });

      await expect(
        service.login({ email: 'user@test.local', password: 'wrong' }),
      ).rejects.toThrow(UnauthorizedException);
      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: 'u-1' },
        data: { failedAttempts: 5, lockedUntil: expect.any(Date) },
      });

      await expect(
        service.login({ email: 'user@test.local', password: 'Str0ng!Pass' }),
      ).rejects.toThrow(ForbiddenException); // locked even with correct password
    });

    it('resets failure counters on successful login', async () => {
      prisma.user.findUnique.mockResolvedValueOnce({ ...activeUser, failedAttempts: 2 });
      await service.login({ email: 'user@test.local', password: 'Str0ng!Pass' });
      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: 'u-1' },
        data: { failedAttempts: 0, lockedUntil: null },
      });
      expect(tokens.issueTokens).toHaveBeenCalled();
    });
  });

  describe('me', () => {
    it('rejects suspended users', async () => {
      prisma.user.findUnique.mockResolvedValueOnce({ ...activeUser, status: 'SUSPENDED' });
      await expect(service.me('u-1')).rejects.toThrow(UnauthorizedException);
    });
  });
});
