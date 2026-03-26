import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:qa_dashboard/models/branch.dart';

import '../models/location.dart';
import 'api_service.dart';

class LocationApiService {
  static String get baseUrl => ApiService.baseUrl;

  // ── Branches ───────────────────────────────────────────────────────────────

  static Future<List<Branch>> getBranches(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/branches'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Branch.fromJson(e)).toList();
    } else {
      throw Exception(_extractErrorMessage(response));
    }
  }

  static Future<Branch> saveBranch({
    required String token,
    int? id,
    required String name,
  }) async {
    final body = jsonEncode({'name': name});
    final uri = id == null
        ? Uri.parse('$baseUrl/branches')
        : Uri.parse('$baseUrl/branches/$id');

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
      return Branch.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractErrorMessage(response));
    }
  }

  static Future<void> deleteBranch({
    required String token,
    required int id,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/branches/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractErrorMessage(response));
    }
  }

  // ── Locaties ───────────────────────────────────────────────────────────────

  static Future<Location> saveLocation({
    required String token,
    int? id,
    required String name,
    required int branchId,
  }) async {
    final body = jsonEncode({'name': name, 'branchId': branchId});
    final uri = id == null
        ? Uri.parse('$baseUrl/locations')
        : Uri.parse('$baseUrl/locations/$id');

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
      return Location.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractErrorMessage(response));
    }
  }

  static Future<void> deleteLocation({
    required String token,
    required int id,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/locations/$id'),
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
