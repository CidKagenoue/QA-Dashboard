class Location {
  final int id;
  final String name;
  final int branchId;

  Location({
    required this.id,
    required this.name,
    required this.branchId,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'],
      name: json['name'],
      branchId: json['branchId'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'branchId': branchId,
      };
}