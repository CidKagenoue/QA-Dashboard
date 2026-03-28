class OvaTicketUser {
  const OvaTicketUser({required this.id, required this.email, this.name});

  final int id;
  final String email;
  final String? name;

  String get displayName {
    final normalizedName = name?.trim();
    if (normalizedName != null && normalizedName.isNotEmpty) {
      return normalizedName;
    }

    return email;
  }

  factory OvaTicketUser.fromJson(Map<String, dynamic> json) {
    return OvaTicketUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
    );
  }
}

class OvaTicket {
  const OvaTicket({
    required this.id,
    required this.status,
    required this.currentStep,
    required this.reasons,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.lastEditedBy,
    this.findingDate,
    this.ovaType,
    this.otherReason,
    this.incidentDescription,
  });

  final int id;
  final String status;
  final int currentStep;
  final DateTime? findingDate;
  final String? ovaType;
  final List<String> reasons;
  final String? otherReason;
  final String? incidentDescription;
  final DateTime createdAt;
  final DateTime updatedAt;
  final OvaTicketUser createdBy;
  final OvaTicketUser lastEditedBy;

  bool get isOpen => status.trim().toLowerCase() == 'open';

  String get statusLabel {
    switch (status.trim().toLowerCase()) {
      case 'open':
        return 'Open';
      case 'draft':
      case 'incomplete':
      default:
        return 'Incompleet';
    }
  }

  factory OvaTicket.fromJson(Map<String, dynamic> json) {
    final createdByJson = json['createdBy'];
    final lastEditedByJson = json['lastEditedBy'];

    return OvaTicket(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'incomplete',
      currentStep: (json['currentStep'] as num?)?.toInt() ?? 1,
      findingDate: _readDate(json['findingDate']),
      ovaType: json['ovaType'] as String?,
      reasons: (json['reasons'] as List? ?? const [])
          .whereType<String>()
          .toList(),
      otherReason: json['otherReason'] as String?,
      incidentDescription: json['incidentDescription'] as String?,
      createdAt: _readDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: _readDate(json['updatedAt']) ?? DateTime.now(),
      createdBy: OvaTicketUser.fromJson(
        Map<String, dynamic>.from(
          createdByJson is Map ? createdByJson : const <String, dynamic>{},
        ),
      ),
      lastEditedBy: OvaTicketUser.fromJson(
        Map<String, dynamic>.from(
          lastEditedByJson is Map
              ? lastEditedByJson
              : const <String, dynamic>{},
        ),
      ),
    );
  }
}

DateTime? _readDate(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value)?.toLocal();
}
