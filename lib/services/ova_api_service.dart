import 'dart:convert';
import 'package:http/http.dart' as http;

class OvaApiService {
  static const String baseUrl = 'YOUR_API_BASE_URL'; // Vul je API URL in

  // PATCH ticket
  static Future<Map<String, dynamic>> updateOvaTicket({
    required String token,
    required int ticketId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/ova/tickets/$ticketId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }

    throw Exception(_extractErrorMessage(response));
  }

  // DELETE ticket
  static Future<void> deleteOvaTicket({
    required String token,
    required int ticketId,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/ova/tickets/$ticketId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractErrorMessage(response));
    }
  }

  // Helper method om error messages te extraheren
  static String _extractErrorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      return body['message'] ?? 'Unknown error occurred';
    } catch (e) {
      return 'Error: ${response.statusCode} - ${response.reasonPhrase}';
    }
  }
}