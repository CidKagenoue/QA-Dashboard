class MaintenanceInspectionForm {
  String equipment = '';
  String inspectionType = 'Kalibratie';
  String inspectionInstitution = '';
  String contactInfo = '';
  int frequencyValue = 1;
  String frequencyUnit = 'Jaar';
  bool selfContact = false;
  List<int> selectedBranchIds = [];
  DateTime? lastInspectionDate;
  DateTime? nextInspectionDate;
  String? status;
  String? notes;

  Map<String, dynamic> toJson() {
    return {
      'equipment': equipment,
      'inspectionType': inspectionType,
      'inspectionInstitution': inspectionInstitution,
      'contactInfo': contactInfo,
      'frequency': 'Elke $frequencyValue $frequencyUnit',
      'selfContact': selfContact,
      'locationIds': selectedBranchIds,
      'lastInspectionDate': lastInspectionDate?.toIso8601String(),
      'dueDate': nextInspectionDate?.toIso8601String(),
      'status': status,
      'notes': notes,
    };
  }
}
