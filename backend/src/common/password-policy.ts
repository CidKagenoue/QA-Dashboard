import { BadRequestException } from '@nestjs/common';

/**
 * Wachtwoordbeleid (één bron van waarheid voor de backend).
 *
 * De Flutter-frontend spiegelt deze regels in
 * `frontend/lib/utils/password_policy.dart` — houd beide bestanden in sync.
 */

export const PASSWORD_MIN_LENGTH = 10;
// bcrypt kapt af op 72 bytes; we begrenzen ruim daaronder.
export const PASSWORD_MAX_LENGTH = 64;

export interface PasswordPolicyContext {
  email?: string | null;
  name?: string | null;
}

// Veelvoorkomende / gokbare wachtwoorden (kleine letters, exacte match).
const COMMON_PASSWORDS = new Set<string>([
  'welkom123!',
  'wachtwoord1',
  'wachtwoord123',
  'password1',
  'password123',
  'qwerty123',
  'azerty123',
  'admin123',
  'welcome123',
  'root123',
  'changeme123',
  'letmein123',
]);

/**
 * Controleert een wachtwoord tegen het beleid en geeft alle overtredingen
 * terug (de eerste is de belangrijkste). Een lege array betekent geldig.
 */
export function getPasswordPolicyViolations(
  password: string,
  context: PasswordPolicyContext = {},
): string[] {
  const violations: string[] = [];
  const value = password ?? '';

  if (value.length < PASSWORD_MIN_LENGTH) {
    violations.push(
      `Wachtwoord moet minimaal ${PASSWORD_MIN_LENGTH} tekens lang zijn`,
    );
  }
  if (value.length > PASSWORD_MAX_LENGTH) {
    violations.push(
      `Wachtwoord mag maximaal ${PASSWORD_MAX_LENGTH} tekens lang zijn`,
    );
  }
  if (!/[A-Z]/.test(value)) {
    violations.push('Wachtwoord moet minstens één hoofdletter bevatten');
  }
  if (!/[a-z]/.test(value)) {
    violations.push('Wachtwoord moet minstens één kleine letter bevatten');
  }
  if (!/[0-9]/.test(value)) {
    violations.push('Wachtwoord moet minstens één cijfer bevatten');
  }
  if (!/[^A-Za-z0-9]/.test(value)) {
    violations.push('Wachtwoord moet minstens één speciaal teken bevatten');
  }

  const lower = value.toLowerCase();

  if (COMMON_PASSWORDS.has(lower)) {
    violations.push('Dit wachtwoord is te gangbaar, kies een unieker wachtwoord');
  }

  const emailLocal = context.email?.split('@')[0]?.trim().toLowerCase();
  if (emailLocal && emailLocal.length >= 3 && lower.includes(emailLocal)) {
    violations.push('Wachtwoord mag je e-mailadres niet bevatten');
  }

  const nameParts = (context.name ?? '')
    .toLowerCase()
    .split(/\s+/)
    .filter((part) => part.length >= 3);
  if (nameParts.some((part) => lower.includes(part))) {
    violations.push('Wachtwoord mag je naam niet bevatten');
  }

  return violations;
}

/**
 * Gooit een BadRequestException met de eerste overtreding wanneer het
 * wachtwoord niet aan het beleid voldoet.
 */
export function assertPasswordPolicy(
  password: string,
  context: PasswordPolicyContext = {},
): void {
  const violations = getPasswordPolicyViolations(password, context);
  if (violations.length > 0) {
    throw new BadRequestException(violations[0]);
  }
}
