/*
Testtype: Unit test
Omschrijving: Unit tests voor `AuthService` (verifyToken, login, forgotPassword).
Doel: valideren van tokenverificatie, login- en wachtwoordresetlogica met mocks.
*/
import { AuthService } from '../../src/auth/auth.service';
import * as jwt from 'jsonwebtoken';
import { getJwtSignOptions, getJwtSecret } from '../../src/auth/jwt.config';
import { UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';

jest.mock('bcrypt', () => ({
  compare: jest.fn(),
}));

describe('AuthService (unit)', () => {
  const OLD_ENV = process.env;

  beforeEach(() => {
    process.env = { ...OLD_ENV };
    process.env.JWT_SECRET = 'a'.repeat(32);
  });

  afterAll(() => {
    process.env = OLD_ENV;
  });

  it('verifyToken returns payload for valid token', async () => {
    const stubs: any = {};
    const svc = new AuthService(stubs, stubs, stubs, stubs);

    const token = jwt.sign({ sub: 1, email: 't@e', type: 'access' }, getJwtSecret(), getJwtSignOptions());

    const payload = await svc.verifyToken(token);
    expect(payload).toHaveProperty('sub');
    expect((payload as any).sub).toBe(1);
  });

  it('verifyToken rejects invalid token', async () => {
    const stubs: any = {};
    const svc = new AuthService(stubs, stubs, stubs, stubs);

    await expect(svc.verifyToken('not-a-token')).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('login returns tokens on valid credentials', async () => {
    process.env.JWT_SECRET = 'a'.repeat(32);

    const user = { id: 42, email: 'me@test.local', password: 'hashed', name: 'Me' };
    const managedUser = {
      id: 42,
      email: 'me@test.local',
      name: 'Me',
      isAdmin: false,
      departments: [],
      basisAccess: false,
      whsToursAccess: false,
      ovaAccess: false,
      japGppAccess: false,
      maintenanceInspectionsAccess: false,
      profileImage: null,
    };

    const userService: any = {
      findByEmail: jest.fn().mockResolvedValue(user),
      findManagedById: jest.fn().mockResolvedValue(managedUser),
    };

    const prismaService: any = { refreshTokenSession: { create: jest.fn().mockResolvedValue({}) } };
    const emailService: any = {};
    const notificationsService: any = {};

    (bcrypt.compare as unknown as jest.Mock).mockResolvedValue(true);

    const svc = new AuthService(userService, prismaService, emailService, notificationsService);

    const result = await svc.login({ email: 'me@test.local', password: 'secret' } as any);

    expect(result).toHaveProperty('accessToken');
    expect(result).toHaveProperty('refreshToken');
    // access token should decode to our user id
    const decoded = jwt.decode(result.accessToken as string) as any;
    expect(decoded.sub).toBe(42);
  });

  it('login throws on invalid password', async () => {
    const user = { id: 1, email: 'x@test', password: 'hashed' };
    const userService: any = { findByEmail: jest.fn().mockResolvedValue(user) };
    const svc = new AuthService(userService, {} as any, {} as any, {} as any);

    (bcrypt.compare as unknown as jest.Mock).mockResolvedValue(false);

    await expect(svc.login({ email: 'x@test', password: 'bad' } as any)).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('forgotPassword creates token and sends email', async () => {
    const user = { id: 7, email: 'forgot@test' };
    const userService: any = { findByEmail: jest.fn().mockResolvedValue(user) };
    const createdRecord = { id: 11, userId: 7 };
    const prismaService: any = { passwordResetToken: { create: jest.fn().mockResolvedValue(createdRecord) } };
    const sendMailMock = jest.fn().mockResolvedValue({});
    const emailService: any = { sendPasswordResetEmail: sendMailMock };
    const notificationsService: any = {};

    const svc = new AuthService(userService, prismaService, emailService, notificationsService);

    const res = await svc.forgotPassword({ email: 'forgot@test' } as any, 'https://frontend.test');

    expect(prismaService.passwordResetToken.create).toHaveBeenCalled();
    expect(sendMailMock).toHaveBeenCalled();
    expect(res).toHaveProperty('message');
  });
});
