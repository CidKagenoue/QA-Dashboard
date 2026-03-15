import { SignOptions, VerifyOptions } from 'jsonwebtoken';

const DEFAULT_ISSUER = 'qa-login-backend';
const DEFAULT_AUDIENCE = 'qa-dashboard';
const DEFAULT_EXPIRES_IN = '15m';
const MIN_SECRET_LENGTH = 32;
const weakSecrets = new Set([
  'root',
  'secret',
  'changeme',
  'password',
  'jwt_secret',
  'change-this-to-a-random-32-char-minimum-secret',
]);

function readEnv(name: string): string | undefined {
  const value = process.env[name]?.trim();
  return value ? value : undefined;
}

export function getJwtSecret(): string {
  const secret = readEnv('JWT_SECRET');

  if (!secret) {
    throw new Error('JWT_SECRET is required');
  }

  if (secret.length < MIN_SECRET_LENGTH || weakSecrets.has(secret.toLowerCase())) {
    throw new Error('JWT_SECRET must be at least 32 characters long and not use a default value');
  }

  return secret;
}

export function getJwtSignOptions(): SignOptions {
  const issuer = readEnv('JWT_ISSUER') ?? DEFAULT_ISSUER;
  const audience = readEnv('JWT_AUDIENCE') ?? DEFAULT_AUDIENCE;
  const expiresIn = (readEnv('JWT_EXPIRES_IN') ?? DEFAULT_EXPIRES_IN) as SignOptions['expiresIn'];

  return {
    algorithm: 'HS256',
    issuer,
    audience,
    expiresIn,
  };
}

export function getJwtVerifyOptions(): VerifyOptions {
  const issuer = readEnv('JWT_ISSUER') ?? DEFAULT_ISSUER;
  const audience = readEnv('JWT_AUDIENCE') ?? DEFAULT_AUDIENCE;

  return {
    algorithms: ['HS256'],
    issuer,
    audience,
  };
}

export function assertJwtConfiguration(): void {
  getJwtSecret();
  getJwtSignOptions();
}