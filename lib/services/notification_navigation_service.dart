import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:qa_dashboard/services/auth_service.dart';


class NotificationNavigationService {
  final String baseUrl;
  final AuthService authService;

  NotificationNavigationService({
    required this.baseUrl,
    required this.authService,
  });

  Future<Map<String, dynamic>> fetchSettings() async {
    final token = await authService.getValidAccessToken();
    final response = await http.get(
      Uri.parse('$baseUrl/notification-settings'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load notification settings');
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
      throw Exception('Failed to update notification settings');
    }
  }
}


