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
      throw Exception(_extractErrorMessage(response));
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
      throw Exception(_extractErrorMessage(response));
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
      throw Exception(_extractErrorMessage(response));
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
      throw Exception(_extractErrorMessage(response));
    }
  }

  static String _extractErrorMessage(http.Response response) {
    final body = response.body.trim();
    if (body.isNotEmpty) {
      try {
        final payload = jsonDecode(body);
        if (payload is Map<String, dynamic>) {
          final message = payload['message'];
          if (message is List && message.isNotEmpty) {
            return message.join(', ');
          }
          if (message is String && message.isNotEmpty) {
            return message;
          }
        }
      } catch (_) {
        return 'Status ${response.statusCode}: $body';
      }
    }

    return 'Request failed with status code ${response.statusCode}';
  }
}
