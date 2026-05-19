// lib/services/jap_api_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/jap_gpp_entry.dart';
import 'api_service.dart';

class JapApiService {
  static List<Map<String, dynamic>> _extractEntriesList(
    dynamic payload,
    String label,
  ) {
    final rawEntries = payload is List
        ? payload
        : payload is Map<String, dynamic>
            ? payload['entries'] ?? payload['items'] ?? payload[label]
            : null;

    if (rawEntries is! List) {
      throw Exception('Ongeldige $label lijst');
    }

    return rawEntries
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  // ── Domains ──────────────────────────────────────────────────────────────

  static Future<List<String>> fetchDomains({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/domain'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(response.body);
      final domains = payload['domains'];
      if (domains is! List) throw Exception('Ongeldige domein lijst');
      return domains
          .whereType<Map>()
          .map((e) => (e['name'] as String))
          .toList();
    }
    final error = jsonDecode(response.body);
    throw Exception(error['message'] ?? 'Domeinen ophalen mislukt');
  }

  static Future<String> createDomain({
    required String token,
    required String name,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/domain'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(response.body);
      final domain = payload['domain'];
      if (domain is! Map) throw Exception('Ongeldig domein ontvangen');
      return domain['name'] as String;
    }
    final error = jsonDecode(response.body);
    throw Exception(error['message'] ?? 'Domein aanmaken mislukt');
  }

  static Future<void> deleteDomain({
    required String token,
    required String domainName,
  }) async {
    // First fetch domains to get the ID
    final domains = await fetchDomains(token: token);
    final domainIndex = domains.indexOf(domainName);
    if (domainIndex == -1) throw Exception('Domein niet gevonden');

    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/domain/$domainIndex'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Domein verwijderen mislukt: ${response.statusCode}');
    }
  }

  // ── Executors ───────────────────────────────────────────────────────────

  static Future<List<String>> fetchExecutors({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/executor'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(response.body);
      final executors = payload['executors'];
      if (executors is! List) throw Exception('Ongeldige uitvoerders lijst');
      return executors.whereType<Map>().map((e) => (e['name'] as String)).toList();
    }
    final error = jsonDecode(response.body);
    throw Exception(error['message'] ?? 'Uitvoerders ophalen mislukt');
  }

  static Future<String> createExecutor({
    required String token,
    required String name,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/executor'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(response.body);
      final executor = payload['executor'];
      if (executor is! Map) throw Exception('Ongeldige uitvoerder ontvangen');
      return executor['name'] as String;
    }
    final error = jsonDecode(response.body);
    throw Exception(error['message'] ?? 'Uitvoerder aanmaken mislukt');
  }

  static Future<void> deleteExecutor({
    required String token,
    required String executorName,
  }) async {
    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/executor/${Uri.encodeComponent(executorName)}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Uitvoerder verwijderen mislukt: ${response.statusCode}');
    }
  }

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
      return _extractEntriesList(payload, 'gpp')
          .map(GppEntry.fromJson)
          .toList();
    }
    final error = jsonDecode(response.body);
    throw Exception(error['message'] ?? 'GPP ophalen mislukt');
  }

  static Future<List<Map<String, dynamic>>> fetchRecentComments({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/jap/recent-comments'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception('Fout bij ophalen commentaar');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['comments'] as List);
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

  static Future<GppEntry> updateGppEntry({
    required String token,
    required int id,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiService.baseUrl}/gpp/$id'),
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
    throw Exception(error['message'] ?? 'GPP opslaan mislukt');
  }

  static Future<void> deleteGppEntry({
    required String token,
    required int id,
  }) async {
    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/gpp/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('GPP verwijderen mislukt: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> importGppExcel({
    required String token,
    required String fileName,
    required Uint8List bytes,
    bool clearExisting = true,
  }) async {
    final uri = Uri.parse('${ApiService.baseUrl}/gpp/import-excel').replace(
      queryParameters: {'clearExisting': clearExisting ? 'true' : 'false'},
    );

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw Exception(body['message'] ?? 'GPP import mislukt');
  }


  // ── Comments ──────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchJapComments({
    required String token,
    required int id,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/jap/$id/comments'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) throw Exception('Ophalen mislukt');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['comments'] as List);
  }

  static Future<Map<String, dynamic>> addJapComment({
    required String token,
    required int id,
    required String author,
    required String text,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/jap/$id/comments'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'author': author, 'text': text}),
    );
    if (response.statusCode != 201) throw Exception('Toevoegen mislukt');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['comment'] as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> fetchGppComments({
    required String token,
    required int id,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/gpp/$id/comments'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) throw Exception('Ophalen mislukt');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['comments'] as List);
  }

  static Future<Map<String, dynamic>> addGppComment({
    required String token,
    required int id,
    required String author,
    required String text,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/gpp/$id/comments'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'author': author, 'text': text}),
    );
    if (response.statusCode != 201) throw Exception('Toevoegen mislukt');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['comment'] as Map<String, dynamic>;
  }

  // ── JAP ──────────────────────────────────────────────────────────────────

  static Future<JapEntry> updateJapEntry({
    required String token,
    required int id,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiService.baseUrl}/jap/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body);
      final entry = body['entry'];
      if (entry is! Map) throw Exception('Ongeldige JAP entry ontvangen');
      return JapEntry.fromJson(Map<String, dynamic>.from(entry));
    }

    throw Exception('Opslaan mislukt: ${response.statusCode}');
  }

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
      return _extractEntriesList(payload, 'jap')
          .map(JapEntry.fromJson)
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

  static Future<void> updateRemark({
    required String token,
    required int id,
    required String remark,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiService.baseUrl}/jap/$id'),  // ← dit was $baseUrl
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'opmerking': remark}),
    );

    if (response.statusCode != 200) {
      throw Exception('Opmerking opslaan mislukt: ${response.statusCode}');
    }
  }

  static Future<void> deleteJapEntry({
    required String token,
    required int id,
  }) async {
    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/jap/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('JAP verwijderen mislukt: ${response.statusCode}');
    }
  }
}
