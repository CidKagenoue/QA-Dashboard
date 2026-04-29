// lib/models/jap_entry.dart

enum JapPriority { laag, middel, hoog }

enum JapRealisatie { inUitvoering, uitgevoerd, negNietUitgevoerd, vulAan }

class JapEntry {
  final int id;
  final int jaar; // e.g. 2024, or use startJaar/eindJaar for ranges
  final int? eindJaar; // null = single year, non-null = range (e.g. 2021–2026)
  final String doelstellingMaatregel;
  final String domein;
  final JapPriority prioriteit;
  final JapRealisatie realisatie;

  const JapEntry({
    required this.id,
    required this.jaar,
    this.eindJaar,
    required this.doelstellingMaatregel,
    required this.domein,
    required this.prioriteit,
    required this.realisatie,
  });

  String get jaarLabel =>
      eindJaar != null ? '$jaar–$eindJaar' : jaar.toString();

  factory JapEntry.fromJson(Map<String, dynamic> json) {
    return JapEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      jaar: (json['jaar'] as num?)?.toInt() ?? DateTime.now().year,
      eindJaar: (json['eindJaar'] as num?)?.toInt(),
      doelstellingMaatregel: json['doelstellingMaatregel'] as String? ?? '',
      domein: json['domein'] as String? ?? '',
      prioriteit: _parsePriority(json['prioriteit'] as String? ?? 'laag'),
      realisatie: _parseRealisatie(json['realisatie'] as String? ?? 'uitgevoerd'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'jaar': jaar,
        'eindJaar': eindJaar,
        'doelstellingMaatregel': doelstellingMaatregel,
        'domein': domein,
        'prioriteit': _priorityToString(prioriteit),
        'realisatie': _realisatieToString(realisatie),
      };

  static JapPriority _parsePriority(String value) {
    switch (value.toLowerCase()) {
      case 'hoog':
        return JapPriority.hoog;
      case 'middel':
      case 'middelhoog':
      case 'middelmatig':
        return JapPriority.middel;
      case 'laag':
        return JapPriority.laag;
      default:
        throw Exception('Unknown priority: $value');
    }
  }

  static String _priorityToString(JapPriority p) {
    switch (p) {
      case JapPriority.hoog:
        return 'hoog';
      case JapPriority.middel:
        return 'middel';
      case JapPriority.laag:
        return 'laag';
    }
  }

  static JapRealisatie _parseRealisatie(String value) {
    final v = value.toLowerCase().replaceAll(' ', '_');

    switch (v) {
      case 'in_uitvoering':
      case 'inuitvoering':
        return JapRealisatie.inUitvoering;

      case 'uitgevoerd':
        return JapRealisatie.uitgevoerd;

      case 'nog_niet_uitgevoerd':
      case 'neg_niet_uitgevoerd':
        return JapRealisatie.negNietUitgevoerd;

      case 'vul_aan':
        return JapRealisatie.vulAan;

      default:
        throw Exception('Unknown realisatie: $value');
    }
  }

  static String _realisatieToString(JapRealisatie r) {
    switch (r) {
      case JapRealisatie.inUitvoering:
        return 'in_uitvoering';
      case JapRealisatie.uitgevoerd:
        return 'uitgevoerd';
      case JapRealisatie.negNietUitgevoerd:
        return 'neg_niet_uitgevoerd';
      case JapRealisatie.vulAan:
        return 'vul_aan';
    }
  }
}