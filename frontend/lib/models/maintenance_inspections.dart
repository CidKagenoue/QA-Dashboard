class MaintenanceInspection {
  final int id;
  final String equipment;
  final String inspectionType;
  final String inspectionInstitution;
  final String? contactInfo;
  final List<String> locations;
  final String frequency;
  final bool selfContact;
  final DateTime? lastInspectionDate;
  final DateTime dueDate;
  final String? status;
  final String? notes;

  MaintenanceInspection({
    required this.id,
    required this.equipment,
    required this.inspectionType,
    required this.inspectionInstitution,
    required this.locations,
    required this.frequency,
    required this.dueDate,
    this.contactInfo,
    this.selfContact = false,
    this.lastInspectionDate,
    this.status,
    this.notes,
  });

  factory MaintenanceInspection.fromJson(Map<String, dynamic> json) {
    return MaintenanceInspection(
      id: json['id'] as int,
      equipment: json['equipment'] as String,
      inspectionType: json['inspectionType'] as String? ?? '',
      inspectionInstitution: json['inspectionInstitution'] as String,
      contactInfo: json['contactInfo'] as String?,
      locations: List<String>.from(json['locations'] as List),
      frequency: json['frequency'] as String,
      selfContact: json['selfContact'] as bool? ?? false,
      lastInspectionDate: json['lastInspectionDate'] != null
          ? DateTime.parse(json['lastInspectionDate'] as String)
          : null,
      dueDate: DateTime.parse(json['dueDate'] as String),
      status: json['status'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'equipment': equipment,
      'inspectionType': inspectionType,
      'inspectionInstitution': inspectionInstitution,
      'contactInfo': contactInfo,
      'locations': locations,
      'frequency': frequency,
      'selfContact': selfContact,
      'lastInspectionDate': lastInspectionDate?.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'status': status,
      'notes': notes,
    };
  }

  MaintenanceInspection copyWith({
    int? id,
    String? equipment,
    String? inspectionType,
    String? inspectionInstitution,
    String? contactInfo,
    List<String>? locations,
    String? frequency,
    bool? selfContact,
    DateTime? lastInspectionDate,
    DateTime? dueDate,
    String? status,
    String? notes,
  }) {
    return MaintenanceInspection(
      id: id ?? this.id,
      equipment: equipment ?? this.equipment,
      inspectionType: inspectionType ?? this.inspectionType,
      inspectionInstitution: inspectionInstitution ?? this.inspectionInstitution,
      contactInfo: contactInfo ?? this.contactInfo,
      locations: locations ?? this.locations,
      frequency: frequency ?? this.frequency,
      selfContact: selfContact ?? this.selfContact,
      lastInspectionDate: lastInspectionDate ?? this.lastInspectionDate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}
