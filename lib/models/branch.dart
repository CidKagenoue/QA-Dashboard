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
    return Branch(
      id: json['id'],
      name: json['name'],
      locations: (json['locations'] as List<dynamic>? ?? [])
          .map((e) => Location.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}