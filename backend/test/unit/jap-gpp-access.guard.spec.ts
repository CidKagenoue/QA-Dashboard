import {
  ExecutionContext,
  ForbiddenException,
  UnauthorizedException,
} from '@nestjs/common';
import { JapGppAccessGuard } from '../../src/jap-gpp/jap-gpp-access.guard';

function createContext(user?: { sub: number | string }) {
  return {
    switchToHttp: () => ({
      getRequest: () => ({ user }),
    }),
  } as unknown as ExecutionContext;
}

describe('JapGppAccessGuard', () => {
  it('allows an administrator', async () => {
    const userService = {
      findById: jest.fn().mockResolvedValue({
        isAdmin: true,
        japGppAccess: false,
      }),
    };
    const guard = new JapGppAccessGuard(userService as any);

    await expect(guard.canActivate(createContext({ sub: 1 }))).resolves.toBe(
      true,
    );
  });

  it('allows a user with JAP/GPP access', async () => {
    const userService = {
      findById: jest.fn().mockResolvedValue({
        isAdmin: false,
        japGppAccess: true,
      }),
    };
    const guard = new JapGppAccessGuard(userService as any);

    await expect(guard.canActivate(createContext({ sub: '2' }))).resolves.toBe(
      true,
    );
  });

  it('rejects a user without JAP/GPP access', async () => {
    const userService = {
      findById: jest.fn().mockResolvedValue({
        isAdmin: false,
        japGppAccess: false,
      }),
    };
    const guard = new JapGppAccessGuard(userService as any);

    await expect(
      guard.canActivate(createContext({ sub: 2 })),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('rejects a request without an authenticated user', async () => {
    const guard = new JapGppAccessGuard({} as any);

    await expect(guard.canActivate(createContext())).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
});
