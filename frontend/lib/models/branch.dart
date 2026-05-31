class Branch {
  final int id;
  final String name;
  final List<int> departmentIds;

  Branch({required this.id, required this.name, this.departmentIds = const []});

  factory Branch.fromJson(Map<String, dynamic> json) {
    final departmentIdsJson = json['departmentIds'];
    final departmentsJson = json['departments'];
    return Branch(
      id: json['id'] as int,
      name: json['name'] as String,
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
