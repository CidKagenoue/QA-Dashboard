import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/department.dart';
import '../models/user.dart';

class DepartmentApiService {
  static const String baseUrl = 'http://localhost:3001';

  static Future<List<Department>> getDepartments(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/departments'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Department.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load departments');
    }
  }

  static Future<List<User>> getAllUsers(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => User.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load users');
    }
  }

  static Future<Department> saveDepartment({
    required String token,
    int? id,
    required String name,
    required List<int> leaderIds,
  }) async {
    final body = jsonEncode({
      'name': name,
      'leaderIds': leaderIds,
    });

    final uri = id == null
        ? Uri.parse('$baseUrl/departments')
        : Uri.parse('$baseUrl/departments/$id');

    final response = await (id == null
        ? http.post(uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: body)
        : http.put(uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: body));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Department.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to save department');
    }
  }

  static Future<void> deleteDepartment({
    required String token,
    required int id,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/departments/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete department');
    }
  }
}
