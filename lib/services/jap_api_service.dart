// lib/services/jap_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/jap_entry.dart';
import 'api_service.dart';

class JapApiService {
  static Future<List<JapEntry>> fetchJapEntries({
    required String token,
    String? search,
  }) async {
    final queryParameters = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }

    final uri = Uri.parse('${ApiService.baseUrl}/jap').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(response.body);
      final entries = payload['entries'];
      if (entries is! List) {
        throw Exception('Invalid JAP entry list received from the server');
      }
      return entries
          .whereType<Map>()
          .map((e) => JapEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final error = jsonDecode(response.body);
    throw Exception(error['message'] ?? 'JAP ophalen mislukt');
  }

  static Future<JapEntry> createJapEntry({
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/jap'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body);
      final entry = body['entry'];
      if (entry is! Map) throw Exception('Invalid JAP entry received');
      return JapEntry.fromJson(Map<String, dynamic>.from(entry));
    }

    final error = jsonDecode(response.body);
    throw Exception(error['message'] ?? 'JAP aanmaken mislukt');
  }

  static Future<JapEntry> updateJapEntry({
    required String token,
    required int entryId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiService.baseUrl}/jap/$entryId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body);
      final entry = body['entry'];
      if (entry is! Map) throw Exception('Invalid JAP entry received');
      return JapEntry.fromJson(Map<String, dynamic>.from(entry));
    }

    final error = jsonDecode(response.body);
    throw Exception(error['message'] ?? 'JAP bijwerken mislukt');
  }

  static Future<void> deleteJapEntry({
    required String token,
    required int entryId,
  }) async {
    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/jap/$entryId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'JAP verwijderen mislukt');
    }
  }

  static Future<void> createGppEntry({
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/gpp'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'GPP aanmaken mislukt');
    }
  }
}

