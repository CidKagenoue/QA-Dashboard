import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_service.dart';

class NotificationSettingsService {
  final String baseUrl;
  final AuthService authService;

  NotificationSettingsService({
    required this.baseUrl,
    required this.authService,
  });

  Future<Map<String, dynamic>> fetchSettings() async {
    final token = await authService.getValidAccessToken();
    final response = await http.get(
      Uri.parse('$baseUrl/notification-settings'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 404) {
      // Settings not found, return empty
      return {'settings': []};
    } else {
      throw Exception('Failed to fetch notification settings: ${response.statusCode}');
    }
  }

  Future<void> updateSettings(Map<String, dynamic> settings) async {
    final token = await authService.getValidAccessToken();
    final response = await http.patch(
      Uri.parse('$baseUrl/notification-settings'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(settings),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update notification settings: ${response.statusCode}');
    }
  }
}
