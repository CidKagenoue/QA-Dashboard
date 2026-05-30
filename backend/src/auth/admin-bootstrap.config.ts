import { getPasswordPolicyViolations } from '../common/password-policy';

/**
 * Configuratie voor het bootstrap-adminaccount.
 *
 * De credentials komen uit environment-variabelen (nooit uit de broncode),
 * net als `JWT_SECRET` in `jwt.config.ts`. Bij een ontbrekend of zwak
 * wachtwoord weigert de app te starten (fail-fast).
 */

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function readEnv(name: string): string | undefined {
  const value = process.env[name]?.trim();
  return value ? value : undefined;
}

export interface BootstrapAdminCredentials {
  email: string;
  password: string;
}

export function getBootstrapAdminCredentials(): BootstrapAdminCredentials {
  const email = readEnv('BOOTSTRAP_ADMIN_EMAIL');
  const password = readEnv('BOOTSTRAP_ADMIN_PASSWORD');

  if (!email) {
    throw new Error(
      'BOOTSTRAP_ADMIN_EMAIL is required to seed the default admin account',
    );
  }
  if (!EMAIL_REGEX.test(email)) {
    throw new Error('BOOTSTRAP_ADMIN_EMAIL must be a valid email address');
  }

  if (!password) {
    throw new Error(
      'BOOTSTRAP_ADMIN_PASSWORD is required to seed the default admin account',
    );
  }

  const violations = getPasswordPolicyViolations(password, { email });
  if (violations.length > 0) {
    throw new Error(`BOOTSTRAP_ADMIN_PASSWORD is too weak: ${violations[0]}`);
  }

  return { email: email.toLowerCase(), password };
}

export function assertBootstrapAdminConfiguration(): void {
  getBootstrapAdminCredentials();
}
