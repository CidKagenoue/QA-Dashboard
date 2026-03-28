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

class OvaExternalResponsible {
  const OvaExternalResponsible({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String? email;

  String get displayName => '$firstName $lastName'.trim();

  factory OvaExternalResponsible.fromJson(Map<String, dynamic> json) {
    return OvaExternalResponsible(
      id: (json['id'] as num?)?.toInt() ?? 0,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
    };
  }
}

class OvaFollowUpAction {
  const OvaFollowUpAction({
    required this.id,
    required this.type,
    required this.description,
    required this.dueDate,
    required this.status,
    required this.assigneeType,
    required this.createdAt,
    required this.updatedAt,
    this.internalAssignee,
    this.externalResponsible,
  });

  final int id;
  final String type;
  final String description;
  final DateTime dueDate;
  final String status;
  final String assigneeType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final OvaTicketUser? internalAssignee;
  final OvaExternalResponsible? externalResponsible;

  bool get isOk => status.trim().toLowerCase() == 'ok';

  bool get isCorrective => type.trim().toLowerCase() == 'corrective';

  String get typeLabel => isCorrective ? 'Corrigerend' : 'Preventief';

  String get assigneeLabel {
    if (assigneeType.trim().toLowerCase() == 'internal') {
      return internalAssignee?.displayName ?? 'Interne gebruiker';
    }

    final external = externalResponsible;
    if (external == null) {
      return 'Externe persoon';
    }

    final emailLabel = external.email?.trim();
    if (emailLabel != null && emailLabel.isNotEmpty) {
      return '${external.displayName} ($emailLabel)';
    }

    return external.displayName;
  }

  factory OvaFollowUpAction.fromJson(Map<String, dynamic> json) {
    final internalAssigneeJson = json['internalAssignee'];
    final externalResponsibleJson = json['externalResponsible'];

    return OvaFollowUpAction(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? 'corrective',
      description: json['description'] as String? ?? '',
      dueDate: _readDate(json['dueDate']) ?? DateTime.now(),
      status: json['status'] as String? ?? 'nok',
      assigneeType: json['assigneeType'] as String? ?? 'internal',
      createdAt: _readDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: _readDate(json['updatedAt']) ?? DateTime.now(),
      internalAssignee: internalAssigneeJson is Map
          ? OvaTicketUser.fromJson(
              Map<String, dynamic>.from(internalAssigneeJson),
            )
          : null,
      externalResponsible: externalResponsibleJson is Map
          ? OvaExternalResponsible.fromJson(
              Map<String, dynamic>.from(externalResponsibleJson),
            )
          : null,
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
    this.causeAnalysisMethod,
    this.causeAnalysisNotes,
    this.followUpActions,
    this.actions = const [],
    this.effectivenessDate,
    this.effectivenessNotes,
    this.closureNotes,
    this.closedAt,
    this.closedBy,
  });

  final int id;
  final String status;
  final int currentStep;
  final DateTime? findingDate;
  final String? ovaType;
  final List<String> reasons;
  final String? otherReason;
  final String? incidentDescription;
  final String? causeAnalysisMethod;
  final String? causeAnalysisNotes;
  final String? followUpActions;
  final List<OvaFollowUpAction> actions;
  final DateTime? effectivenessDate;
  final String? effectivenessNotes;
  final String? closureNotes;
  final DateTime? closedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final OvaTicketUser createdBy;
  final OvaTicketUser lastEditedBy;
  final OvaTicketUser? closedBy;

  bool get isClosed {
    final normalizedStatus = status.trim().toLowerCase();
    return normalizedStatus == 'closed' || normalizedStatus == 'completed';
  }

  bool get isOpen => status.trim().toLowerCase() == 'open';

  bool get hasOpenActions => actions.any((action) => !action.isOk);

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

  factory OvaTicket.fromJson(Map<String, dynamic> json) {
    final createdByJson = json['createdBy'];
    final lastEditedByJson = json['lastEditedBy'];
    final closedByJson = json['closedBy'];
    final actionsJson = json['actions'];

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
      causeAnalysisMethod: json['causeAnalysisMethod'] as String?,
      causeAnalysisNotes: json['causeAnalysisNotes'] as String?,
      followUpActions: json['followUpActions'] as String?,
      actions: actionsJson is List
          ? actionsJson
                .whereType<Map>()
                .map(
                  (action) => OvaFollowUpAction.fromJson(
                    Map<String, dynamic>.from(action),
                  ),
                )
                .toList()
          : const [],
      effectivenessDate: _readDate(json['effectivenessDate']),
      effectivenessNotes: json['effectivenessNotes'] as String?,
      closureNotes: json['closureNotes'] as String?,
      closedAt: _readDate(json['closedAt']),
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
      closedBy: closedByJson is Map
          ? OvaTicketUser.fromJson(Map<String, dynamic>.from(closedByJson))
          : null,
    );
  }
}

DateTime? _readDate(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value)?.toLocal();
}
