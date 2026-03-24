import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/department.dart';
import '../models/user.dart';
import 'api_service.dart';

class DepartmentApiService {
  static Future<List<Department>> getDepartments(String token) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/departments'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Department.fromJson(e)).toList();
    } else {
      throw Exception('Laden van afdelingen mislukt');
    }
  }

  static Future<List<User>> getAllUsers(String token) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/users'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => User.fromJson(e)).toList();
    } else {
      throw Exception('Laden van gebruikers mislukt');
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
        ? Uri.parse('${ApiService.baseUrl}/departments')
        : Uri.parse('${ApiService.baseUrl}/departments/$id');

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
      throw Exception('Opslaan van afdeling mislukt');
    }
  }

  static Future<void> deleteDepartment({
    required String token,
    required int id,
  }) async {
    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/departments/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Verwijderen van afdeling mislukt');
    }
  }
}
