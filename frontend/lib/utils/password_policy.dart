/// Wachtwoordbeleid voor de QA Dashboard frontend.
///
/// Dit spiegelt de backend-regels in
/// `backend/src/common/password-policy.ts` — houd beide bestanden in sync.
class PasswordPolicy {
  PasswordPolicy._();

  static const int minLength = 10;

  /// bcrypt kapt af op 72 bytes; we begrenzen ruim daaronder.
  static const int maxLength = 64;

  /// Veelvoorkomende / gokbare wachtwoorden (kleine letters, exacte match).
  static const Set<String> _commonPasswords = {
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
  };

  /// Korte, voor mensen leesbare samenvatting van de eisen (voor helpteksten).
  static const String requirementsHint =
      'Minimaal $minLength tekens, met een hoofdletter, kleine letter, '
      'cijfer en speciaal teken.';

  /// Valideert [password] tegen het beleid.
  ///
  /// Geeft de eerste overtreding terug als foutmelding, of `null` wanneer het
  /// wachtwoord geldig is. Geschikt voor gebruik als `TextFormField.validator`.
  static String? validate(
    String? password, {
    String? email,
    String? name,
  }) {
    final value = password ?? '';

    if (value.isEmpty) {
      return 'Wachtwoord is verplicht';
    }
    if (value.length < minLength) {
      return 'Wachtwoord moet minimaal $minLength tekens lang zijn';
    }
    if (value.length > maxLength) {
      return 'Wachtwoord mag maximaal $maxLength tekens lang zijn';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Wachtwoord moet minstens één hoofdletter bevatten';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Wachtwoord moet minstens één kleine letter bevatten';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Wachtwoord moet minstens één cijfer bevatten';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return 'Wachtwoord moet minstens één speciaal teken bevatten';
    }

    final lower = value.toLowerCase();

    if (_commonPasswords.contains(lower)) {
      return 'Dit wachtwoord is te gangbaar, kies een unieker wachtwoord';
    }

    final emailLocal = (email ?? '').split('@').first.trim().toLowerCase();
    if (emailLocal.length >= 3 && lower.contains(emailLocal)) {
      return 'Wachtwoord mag je e-mailadres niet bevatten';
    }

    final nameParts = (name ?? '')
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((part) => part.length >= 3);
    for (final part in nameParts) {
      if (lower.contains(part)) {
        return 'Wachtwoord mag je naam niet bevatten';
      }
    }

    return null;
  }
}
