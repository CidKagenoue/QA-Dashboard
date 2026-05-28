/*
Testtype: Unit test
Omschrijving: Tests voor JWT-configuratiehelpers (`getJwtSecret`, `getJwtSignOptions`).
Doel: valideren dat JWT secret en sign-opties correct worden gehanteerd.
*/
import { getJwtSecret, getJwtSignOptions } from '../../src/auth/jwt.config';

describe('JWT config', () => {
  const OLD_ENV = process.env;

  beforeEach(() => {
    process.env = { ...OLD_ENV };
  });

  afterAll(() => {
    process.env = OLD_ENV;
  });

  it('throws when JWT_SECRET is missing', () => {
    delete process.env.JWT_SECRET;
    expect(() => getJwtSecret()).toThrow();
  });

  it('accepts a valid JWT_SECRET and returns sign options', () => {
    process.env.JWT_SECRET = 'a'.repeat(32);
    const secret = getJwtSecret();
    expect(typeof secret).toBe('string');

    const opts = getJwtSignOptions();
    expect(opts).toHaveProperty('algorithm');
    expect(opts).toHaveProperty('expiresIn');
  });
});
