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
  final String riskField;
  final String resourcesBudget;
  final JapPriority priority;
  final JapRealisation realisation;
  final String executor;
  final DateTime? startDate;
  final DateTime? endDate;
  final String remark;

  const JapEntry({
    required this.id,
    required this.year,
    required this.goalMeasure,
    required this.domain,
    this.riskField = 'Algemeen',
    this.resourcesBudget = '',
    required this.priority,
    required this.realisation,
    this.executor = '',
    this.startDate,
    this.endDate,
    this.remark = '',
  });


  // JAP = single year
  String get yearLabel => year.toString();

  factory JapEntry.fromJson(Map<String, dynamic> json) {
    return JapEntry(
      id: int.tryParse(json['id'].toString()) ?? 0,
      year: int.tryParse(json['jaar'].toString()) ?? DateTime.now().year,
      goalMeasure: json['doelstellingMaatregel'] as String? ?? '',
      domain: json['domein'] as String? ?? '',
      riskField: json['risicoveld'] as String? ?? 'Algemeen',
      resourcesBudget: json['middelenBudgetWerkuren'] as String? ?? '',
      priority: _parsePriority(json['prioriteit'] as String? ?? 'laag'),
      realisation: _parseRealisation(json['realisatie'] as String? ?? 'uitgevoerd'),
      executor: json['uitvoerder'] as String? ?? '',
      startDate: _parseDate(json['startdatum']),
      endDate: _parseDate(json['einddatum']),
      remark: json['opmerking'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'jaar': year,
        'doelstellingMaatregel': goalMeasure,
        'domein': domain,
        'risicoveld': riskField,
        'middelenBudgetWerkuren': resourcesBudget,
        'prioriteit': _priorityToString(priority),
        'realisatie': _realisationToString(realisation),
        'uitvoerder': executor,
        'startdatum': _formatDate(startDate),
        'einddatum': _formatDate(endDate),
        'opmerking': remark,
      };

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;

    final direct = DateTime.tryParse(text);
    if (direct != null) return DateTime(direct.year, direct.month, direct.day);

    final normalised = text.replaceAll('/', '.').replaceAll('-', '.');
    final parts = normalised.split('.');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return '';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

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
  final String riskField;
  final String resourcesBudget;
  final String priority;
  final String realisation;
  final String executor;
  final DateTime? startDate;
  final DateTime? endDate;
  final String remark;

  const GppEntry({
    required this.id,
    required this.startYear,
    required this.endYear,
    required this.goalMeasure,
    required this.domain,
    this.riskField = 'Algemeen',
    this.resourcesBudget = '',
    this.priority = 'laag',
    this.realisation = 'vul_aan',
    this.executor = '',
    this.startDate,
    this.endDate,
    this.remark = '',
  });

  // GPP = year range "2021-2026"
  String get yearLabel => '$startYear-$endYear';

  factory GppEntry.fromJson(Map<String, dynamic> json) {
    return GppEntry(
      id: int.tryParse(json['id'].toString()) ?? 0,
      startYear: int.tryParse(json['startJaar'].toString()) ?? DateTime.now().year,
      endYear: int.tryParse(json['eindJaar'].toString()) ?? DateTime.now().year + 5,
      goalMeasure: json['doelstellingMaatregel'] as String? ?? '',
      domain: json['domein'] as String? ?? '',
      riskField: json['risicoveld'] as String? ?? 'Algemeen',
      resourcesBudget: json['middelenBudgetWerkuren'] as String? ?? '',
      priority: json['prioriteit'] as String? ?? 'laag',
      realisation: json['realisatie'] as String? ?? 'vul_aan',
      executor: json['uitvoerder'] as String? ?? '',
      startDate: JapEntry._parseDate(json['startdatum']),
      endDate: JapEntry._parseDate(json['einddatum']),
      remark: json['opmerking'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startJaar': startYear,
        'eindJaar': endYear,
        'doelstellingMaatregel': goalMeasure,
        'domein': domain,
        'risicoveld': riskField,
        'middelenBudgetWerkuren': resourcesBudget,
        'prioriteit': priority,
        'realisatie': realisation,
        'uitvoerder': executor,
        'startdatum': JapEntry._formatDate(startDate),
        'einddatum': JapEntry._formatDate(endDate),
        'opmerking': remark,
      };
}
