import 'package:qa_dashboard/models/user.dart';

class Department {
  final int id;
  final String name;
  final List<User> leaders;

  Department({
    required this.id,
    required this.name,
    required this.leaders,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'],
      name: json['name'],
      leaders: (json['leaders'] as List<dynamic>? ?? [])
          .map((e) => User.fromJson(e['user'] as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'leaderIds': leaders.map((u) => u.id).toList(),
    };
  }
}
