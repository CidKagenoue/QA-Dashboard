// lib/services/jap_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/jap_gpp_entry.dart';
import 'api_service.dart';

class JapApiService {
  // ── GPP ──────────────────────────────────────────────────────────────────

  static Future<List<GppEntry>> fetchGppEntries({
    required String token,
    String? search,
  }) async {
    final queryParameters = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }

    final uri = Uri.parse('${ApiService.baseUrl}/gpp').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    final response = await http.get(uri, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(response.body);
      final entries = payload['entries'];
      if (entries is! List) throw Exception('Ongeldige GPP lijst');
      return entries
          .whereType<Map>()
          .map((e) => GppEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    final error = jsonDecode(response.body);
    throw Exception(error['message'] ?? 'GPP ophalen mislukt');
  }

  static Future<GppEntry> createGppEntry({
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

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body);
      final entry = body['entry'];
      if (entry is! Map) throw Exception('Ongeldige GPP entry ontvangen');
      return GppEntry.fromJson(Map<String, dynamic>.from(entry));
    }
    final error = jsonDecode(response.body);
    throw Exception(error['message'] ?? 'GPP aanmaken mislukt');
  }

  // ── JAP ──────────────────────────────────────────────────────────────────

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

    final response = await http.get(uri, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(response.body);
      final entries = payload['entries'];
      if (entries is! List) throw Exception('Ongeldige JAP lijst');
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
      if (entry is! Map) throw Exception('Ongeldige JAP entry ontvangen');
      return JapEntry.fromJson(Map<String, dynamic>.from(entry));
    }
    final error = jsonDecode(response.body);
    throw Exception(error['message'] ?? 'JAP aanmaken mislukt');
  }
}