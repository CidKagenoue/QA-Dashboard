import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/whs_tour.dart';
import 'api_client.dart';

class WhsApiService {
  static String get baseUrl => ApiClient.baseUrl;

  static Future<List<WhsTour>> fetchTours({required String token}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/rapport'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final records = data is List
          ? data
          : data is Map<String, dynamic>
              ? data['rapport'] ?? data['reports'] ?? data['items'] ?? data['entries']
              : null;

      if (records is! List) {
        throw Exception('Invalid WHS tour list received from the server');
      }

      return records
          .whereType<Map>()
          .map((e) => WhsTour.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    throw Exception('WHS tours ophalen mislukt: ${response.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> fetchRecentReports({required String token}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/rapport'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) throw Exception('Fout bij ophalen WHS rapporten');

    final data = jsonDecode(response.body);
    final records = data is List
        ? data
        : data is Map<String, dynamic>
            ? data['rapport'] ?? data['reports'] ?? data['items'] ?? data['entries']
            : null;

    if (records is! List) throw Exception('Invalid recent WHS reports');

    return records
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
