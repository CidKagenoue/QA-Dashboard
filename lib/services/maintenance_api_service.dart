import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/branch.dart';
import '../models/maintenance_inspection_form.dart';
import '../models/maintenance_inspections.dart';
import 'api_service.dart';

class MaintenanceApiService {
  static String get baseUrl => ApiService.baseUrl;

  static Future<List<MaintenanceInspection>> getInspections({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/maintenance-inspections'),
      headers: _headers(token),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) => MaintenanceInspection.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList();
      }
      throw Exception('Invalid maintenance list received from the server');
    }

    throw Exception(_extractErrorMessage(response));
  }

  static Future<List<Branch>> getAvailableBranches({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/maintenance-inspections/form-data'),
      headers: _headers(token),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final branches = data is Map<String, dynamic> ? data['branches'] : null;
      if (branches is List) {
        return branches
            .whereType<Map>()
            .map((item) => Branch.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
      throw Exception('Invalid branch list received from the server');
    }

    throw Exception(_extractErrorMessage(response));
  }

  static Future<MaintenanceInspection> createInspection({
    required String token,
    required MaintenanceInspectionForm form,
  }) async {
    return _writeInspection(
      token: token,
      form: form,
      method: 'POST',
    );
  }

  static Future<MaintenanceInspection> updateInspection({
    required String token,
    required int id,
    required MaintenanceInspectionForm form,
  }) async {
    return _writeInspection(
      token: token,
      form: form,
      method: 'PATCH',
      id: id,
    );
  }

  static Future<void> deleteInspection({
    required String token,
    required int id,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/maintenance-inspections/$id'),
      headers: _headers(token),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractErrorMessage(response));
    }
  }

  static Future<MaintenanceInspection> _writeInspection({
    required String token,
    required MaintenanceInspectionForm form,
    required String method,
    int? id,
  }) async {
    final uri = id == null
        ? Uri.parse('$baseUrl/maintenance-inspections')
        : Uri.parse('$baseUrl/maintenance-inspections/$id');

    late final http.Response response;
    if (method == 'POST') {
      response = await http.post(
        uri,
        headers: _headers(token),
        body: jsonEncode(form.toJson()),
      );
    } else if (method == 'PATCH') {
      response = await http.patch(
        uri,
        headers: _headers(token),
        body: jsonEncode(form.toJson()),
      );
    } else {
      throw UnsupportedError('Unsupported method: $method');
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return MaintenanceInspection.fromJson(
        Map<String, dynamic>.from(jsonDecode(response.body) as Map),
      );
    }

    throw Exception(_extractErrorMessage(response));
  }

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

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
