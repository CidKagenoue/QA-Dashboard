import 'package:shared_preferences/shared_preferences.dart';

class DomainService {
  static const List<String> defaultDomains = [
    'Arbeidsveiligheid',
    'Welzijnsbeleid',
    'Arbeidshygiëne',
  ];

  static const String _customDomainsKey = 'custom_domain_options';

  static Future<List<String>> loadDomains() async {
    final prefs = await SharedPreferences.getInstance();
    final customDomains = prefs.getStringList(_customDomainsKey) ?? const <String>[];
    return _mergeDomains(defaultDomains, customDomains);
  }

  static Future<void> addDomain(String domain) async {
    final normalized = domain.trim();
    if (normalized.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_customDomainsKey) ?? const <String>[];
    final merged = _mergeDomains(defaultDomains, existing);

    if (merged.any((value) => value.toLowerCase() == normalized.toLowerCase())) {
      return;
    }

    final updated = List<String>.from(existing)..add(normalized);
    await prefs.setStringList(_customDomainsKey, updated);
  }

  static List<String> _mergeDomains(List<String> defaults, List<String> customDomains) {
    final merged = <String>[];
    final seen = <String>{};

    for (final domain in [...defaults, ...customDomains]) {
      final normalized = domain.trim();
      if (normalized.isEmpty) continue;
      final key = normalized.toLowerCase();
      if (seen.add(key)) {
        merged.add(normalized);
      }
    }

    return merged;
  }
}