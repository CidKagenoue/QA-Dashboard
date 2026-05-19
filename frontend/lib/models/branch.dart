import 'location.dart';

class Branch {
  final int id;
  final String name;
  final List<Location> locations;

  Branch({
    required this.id,
    required this.name,
    required this.locations,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    final locationsJson = json['locations'];
    return Branch(
      id: json['id'] as int,
      name: json['name'] as String,
      locations: locationsJson is List
          ? locationsJson
              .whereType<Map>()
              .map((e) => Location.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}