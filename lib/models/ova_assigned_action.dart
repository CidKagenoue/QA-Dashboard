import 'ova_ticket.dart';

class OvaActionTicketSummary {
  const OvaActionTicketSummary({
    required this.id,
    required this.status,
    required this.currentStep,
    this.findingDate,
    this.ovaType,
  });

  final int id;
  final String status;
  final int currentStep;
  final DateTime? findingDate;
  final String? ovaType;

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
    return OvaActionTicketSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'incomplete',
      currentStep: (json['currentStep'] as num?)?.toInt() ?? 1,
      findingDate: _readDateValue(json['findingDate']),
      ovaType: json['ovaType'] as String?,
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
}

DateTime? _readDateValue(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value)?.toLocal();
}
