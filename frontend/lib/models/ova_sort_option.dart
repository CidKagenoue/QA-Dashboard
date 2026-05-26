// lib/models/ova_sort_option.dart

enum OvaSortField {
  date,
  status,
  type,
}

enum OvaSortDirection {
  ascending,
  descending,
}

class OvaSortOption {
  const OvaSortOption({
    required this.field,
    required this.direction,
  });

  final OvaSortField field;
  final OvaSortDirection direction;

  OvaSortOption toggle() {
    if (direction == OvaSortDirection.ascending) {
      return OvaSortOption(field: field, direction: OvaSortDirection.descending);
    }
    return OvaSortOption(field: field, direction: OvaSortDirection.ascending);
  }

  String get label {
    final fieldLabel = switch (field) {
      OvaSortField.date => 'Datum',
      OvaSortField.status => 'Status',
      OvaSortField.type => 'Type',
    };
    final directionLabel = direction == OvaSortDirection.ascending ? '↑' : '↓';
    return '$fieldLabel $directionLabel';
  }
}