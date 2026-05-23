import 'location.dart';

class Branch {
  final int id;
  final String name;
  final List<Location> locations;
  final List<int> departmentIds;

  Branch({
    required this.id,
    required this.name,
    required this.locations,
    this.departmentIds = const [],
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    final locationsJson = json['locations'];
    final departmentIdsJson = json['departmentIds'];
    final departmentsJson = json['departments'];
    return Branch(
      id: json['id'] as int,
      name: json['name'] as String,
      locations: locationsJson is List
          ? locationsJson
                .whereType<Map>()
                .map((e) => Location.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
      departmentIds: departmentIdsJson is List
          ? departmentIdsJson
                .whereType<num>()
                .map((id) => id.toInt())
                .where((id) => id > 0)
                .toList()
          : departmentsJson is List
          ? departmentsJson
                .whereType<Map>()
                .map((item) => (item['id'] as num?)?.toInt() ?? 0)
                .where((id) => id > 0)
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'departmentIds': departmentIds,
  };
}
