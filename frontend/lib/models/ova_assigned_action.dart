import 'ova_ticket.dart';

class OvaActionTicketSummary {
  const OvaActionTicketSummary({
    required this.id,
    required this.status,
    required this.currentStep,
    this.findingDate,
    this.ovaType,
    this.departmentFallback,
    this.branchFallback,
    this.department,
    this.branch,
  });

  final int id;
  final String status;
  final int currentStep;
  final DateTime? findingDate;
  final String? ovaType;
  final String? departmentFallback;
  final String? branchFallback;
  final OvaTicketOption? department;
  final OvaTicketOption? branch;

  String? get branchLabel => branch?.name ?? _fallbackLabel(branchFallback);

  String? get departmentLabel =>
      department?.name ?? _fallbackLabel(departmentFallback);

  String get statusLabel {
    switch (status.trim().toLowerCase()) {
      case 'open':
        return 'Open';
      case 'closed':
      case 'completed':
        return 'Gesloten';
      case 'draft':
      case 'incomplete':
      default:
        return 'Incompleet';
    }
  }

  factory OvaActionTicketSummary.fromJson(Map<String, dynamic> json) {
    final departmentJson = json['department'];
    final branchJson = json['branch'];

    return OvaActionTicketSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'incomplete',
      currentStep: (json['currentStep'] as num?)?.toInt() ?? 1,
      findingDate: _readDateValue(json['findingDate']),
      ovaType: json['ovaType'] as String?,
      departmentFallback: json['departmentFallback'] as String?,
      branchFallback: json['branchFallback'] as String?,
      department: departmentJson is Map
          ? OvaTicketOption.fromJson(Map<String, dynamic>.from(departmentJson))
          : null,
      branch: branchJson is Map
          ? OvaTicketOption.fromJson(Map<String, dynamic>.from(branchJson))
          : null,
    );
  }
}

class OvaAssignedAction {
  const OvaAssignedAction({required this.action, required this.ticket});

  final OvaFollowUpAction action;
  final OvaActionTicketSummary ticket;

  factory OvaAssignedAction.fromJson(Map<String, dynamic> json) {
    return OvaAssignedAction(
      action: OvaFollowUpAction.fromJson(json),
      ticket: OvaActionTicketSummary.fromJson(
        Map<String, dynamic>.from(json['ticket'] as Map? ?? const {}),
      ),
    );
  }

  String? get actionTitle => null;

  String? get assignedBy => null;
}

DateTime? _readDateValue(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value)?.toLocal();
}

String? _fallbackLabel(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'unknown':
      return 'Onbekend';
    case 'not_applicable':
      return 'Niet van toepassing';
    default:
      return null;
  }
}
