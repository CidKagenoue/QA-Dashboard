// lib/models/jap_gpp_entry.dart

enum JapPriority { low, medium, high }

enum JapRealisation { inProgress, completed, notYetCompleted, fillIn }

// ---------------------------------------------------------------------------
// JAP — Annual Action Plan (1 year, with priority & realisation)
// ---------------------------------------------------------------------------
class JapEntry {
  final int id;
  final int year;
  final String goalMeasure;
  final String domain;
  final JapPriority priority;
  final JapRealisation realisation;
  final String executor;
  final String remark;

  const JapEntry({
    required this.id,
    required this.year,
    required this.goalMeasure,
    required this.domain,
    required this.priority,
    required this.realisation,
    this.executor = '',
    this.remark = '',
  });

  // JAP = single year
  String get yearLabel => year.toString();

  factory JapEntry.fromJson(Map<String, dynamic> json) {
    return JapEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      year: (json['jaar'] as num?)?.toInt() ?? DateTime.now().year,
      goalMeasure: json['doelstellingMaatregel'] as String? ?? '',
      domain: json['domein'] as String? ?? '',
      priority: _parsePriority(json['prioriteit'] as String? ?? 'laag'),
      realisation: _parseRealisation(json['realisatie'] as String? ?? 'uitgevoerd'),
      executor: json['uitvoerder'] as String? ?? '',
      remark: json['opmerking'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'jaar': year,
        'doelstellingMaatregel': goalMeasure,
        'domein': domain,
        'prioriteit': _priorityToString(priority),
        'realisatie': _realisationToString(realisation),
        'uitvoerder': executor,
        'opmerking': remark,
      };

  static JapPriority _parsePriority(String value) {
    switch (value.toLowerCase()) {
      case 'hoog':
        return JapPriority.high;
      case 'middel':
      case 'middelhoog':
      case 'middelmatig':
        return JapPriority.medium;
      case 'laag':
        return JapPriority.low;
      default:
        return JapPriority.low;
    }
  }

  static String _priorityToString(JapPriority priority) {
    switch (priority) {
      case JapPriority.high:
        return 'hoog';
      case JapPriority.medium:
        return 'middel';
      case JapPriority.low:
        return 'laag';
    }
  }

  static JapRealisation _parseRealisation(String value) {
    final normalised = value.toLowerCase().replaceAll(' ', '_');
    switch (normalised) {
      case 'in_uitvoering':
      case 'inuitvoering':
        return JapRealisation.inProgress;
      case 'uitgevoerd':
        return JapRealisation.completed;
      case 'nog_niet_uitgevoerd':
      case 'neg_niet_uitgevoerd':
        return JapRealisation.notYetCompleted;
      case 'vul_aan':
        return JapRealisation.fillIn;
      default:
        return JapRealisation.fillIn;
    }
  }

  static String _realisationToString(JapRealisation realisation) {
    switch (realisation) {
      case JapRealisation.inProgress:
        return 'in_uitvoering';
      case JapRealisation.completed:
        return 'uitgevoerd';
      case JapRealisation.notYetCompleted:
        return 'neg_niet_uitgevoerd';
      case JapRealisation.fillIn:
        return 'vul_aan';
    }
  }
}

// ---------------------------------------------------------------------------
// GPP — Global Prevention Plan (multiple years, goals only)
// ---------------------------------------------------------------------------
class GppEntry {
  final int id;
  final int startYear;
  final int endYear;
  final String goalMeasure;
  final String domain;

  const GppEntry({
    required this.id,
    required this.startYear,
    required this.endYear,
    required this.goalMeasure,
    required this.domain,
  });

  // GPP = year range "2021–2026"
  String get yearLabel => '$startYear–$endYear';

  factory GppEntry.fromJson(Map<String, dynamic> json) {
    return GppEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      startYear: (json['startJaar'] as num?)?.toInt() ?? DateTime.now().year,
      endYear: (json['eindJaar'] as num?)?.toInt() ?? DateTime.now().year + 5,
      goalMeasure: json['doelstellingMaatregel'] as String? ?? '',
      domain: json['domein'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startJaar': startYear,
        'eindJaar': endYear,
        'doelstellingMaatregel': goalMeasure,
        'domein': domain,
      };
}