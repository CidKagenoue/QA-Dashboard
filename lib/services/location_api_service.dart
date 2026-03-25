import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:qa_dashboard/models/branch.dart';

import '../models/location.dart';

class LocationApiService {
  static const String baseUrl = 'http://localhost:3001';

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
      throw Exception('Laden van branches mislukt');
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
      // Toon de echte fout van de backend
      throw Exception('Status ${response.statusCode}: ${response.body}');
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
      throw Exception('Verwijderen van branch mislukt');
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
      throw Exception('Opslaan van locatie mislukt');
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
      throw Exception('Verwijderen van locatie mislukt');
    }
  }
}