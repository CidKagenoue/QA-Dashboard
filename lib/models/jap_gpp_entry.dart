// lib/models/jap_gpp_entry.dart

enum JapPriority { laag, middel, hoog }

enum JapRealisatie { inUitvoering, uitgevoerd, negNietUitgevoerd, vulAan }

// ---------------------------------------------------------------------------
// JAP — Jaaractieplan (1 jaar, met prioriteit & realisatie)
// ---------------------------------------------------------------------------
class JapEntry {
  final int id;
  final int jaar;
  final String doelstellingMaatregel;
  final String domein;
  final JapPriority prioriteit;
  final JapRealisatie realisatie;

  const JapEntry({
    required this.id,
    required this.jaar,
    required this.doelstellingMaatregel,
    required this.domein,
    required this.prioriteit,
    required this.realisatie,
  });

  // JAP = 1 enkel jaar
  String get jaarLabel => jaar.toString();

  factory JapEntry.fromJson(Map<String, dynamic> json) {
    return JapEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      jaar: (json['jaar'] as num?)?.toInt() ?? DateTime.now().year,
      doelstellingMaatregel: json['doelstellingMaatregel'] as String? ?? '',
      domein: json['domein'] as String? ?? '',
      prioriteit: _parsePriority(json['prioriteit'] as String? ?? 'laag'),
      realisatie: _parseRealisatie(json['realisatie'] as String? ?? 'uitgevoerd'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'jaar': jaar,
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
        return JapPriority.laag;
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
        return JapRealisatie.vulAan;
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

// ---------------------------------------------------------------------------
// GPP — Globaal Preventieplan (meerdere jaren, enkel doelstellingen)
// ---------------------------------------------------------------------------
class GppEntry {
  final int id;
  final int startJaar;  // bv. 2021
  final int eindJaar;   // bv. 2026
  final String doelstellingMaatregel;
  final String domein;

  const GppEntry({
    required this.id,
    required this.startJaar,
    required this.eindJaar,
    required this.doelstellingMaatregel,
    required this.domein,
  });

  // GPP = jaarbereik "2021–2026"
  String get jaarLabel => '$startJaar–$eindJaar';

  factory GppEntry.fromJson(Map<String, dynamic> json) {
    return GppEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      startJaar: (json['startJaar'] as num?)?.toInt() ?? DateTime.now().year,
      eindJaar: (json['eindJaar'] as num?)?.toInt() ?? DateTime.now().year + 5,
      doelstellingMaatregel: json['doelstellingMaatregel'] as String? ?? '',
      domein: json['domein'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startJaar': startJaar,
        'eindJaar': eindJaar,
        'doelstellingMaatregel': doelstellingMaatregel,
        'domein': domein,
      };
}