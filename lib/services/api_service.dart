
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';

class ApiService {
  static const String _webApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3001',
  );

  static Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmNewPassword': confirmNewPassword,
      }),
    );

    if (response.statusCode == 204 || response.statusCode == 200) {
      return;
    }

    final error = jsonDecode(response.body);
    throw Exception(error['message'] ?? 'Wachtwoord wijzigen mislukt');
  }

  static String get baseUrl {
    if (kIsWeb) {
      return _webApiBaseUrl;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3001';
      default:
        return 'http://localhost:3001';
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    return _requestObject(
      () => http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _headers(),
        body: jsonEncode({'email': email.trim(), 'password': password}),
      ),
    );
  }

  static Future<void> logout({required String refreshToken}) async {
    await _requestObject(
      () => http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: _headers(),
        body: jsonEncode({'refreshToken': refreshToken}),
      ),
    );
  }

  static Future<Map<String, dynamic>> refreshToken({
    required String refreshToken,
  }) async {
    return _requestObject(
      () => http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: _headers(),
        body: jsonEncode({'refreshToken': refreshToken}),
      ),
    );
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    return _requestObject(
      () => http.post(
        Uri.parse('$baseUrl/auth/forgot-password'),
        headers: _headers(),
        body: jsonEncode({'email': email.trim()}),
      ),
    );
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    return _requestObject(
      () => http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: _headers(),
        body: jsonEncode({
          'token': token,
          'password': password,
          'confirmPassword': confirmPassword,
        }),
      ),
    );
  }

  static Future<Map<String, dynamic>> verifyResetToken(String token) async {
    return _requestObject(
      () => http.post(
        Uri.parse('$baseUrl/auth/verify-reset-token'),
        headers: _headers(),
        body: jsonEncode({'token': token}),
      ),
    );
  }

  static Future<Map<String, dynamic>> updateProfile({
    required int userId,
    required String token,
    String? name,
    String? email,
    List<int>? departmentIds,
    String? profileImage,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) {
      payload['name'] = name;
    }
    if (email != null) {
      payload['email'] = email;
    }
    if (departmentIds != null) {
      payload['departmentIds'] = departmentIds;
    }
    if (profileImage != null) {
      payload['profileImage'] = profileImage;
    }

    return _requestObject(
      () => http.patch(
        Uri.parse('$baseUrl/users/$userId'),
        headers: _headers(token: token),
        body: jsonEncode(payload),
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> fetchAccounts({
    required String token,
    String? search,
  }) async {
    final queryParameters = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }

    final uri = Uri.parse('$baseUrl/accounts').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    final response = await _requestObject(
      () => http.get(uri, headers: _headers(token: token)),
    );

    final accounts = response['accounts'];
    if (accounts is! List) {
      throw Exception('Invalid account list received from the server');
    }

    return accounts
        .whereType<Map>()
        .map((account) => Map<String, dynamic>.from(account))
        .toList();
  }

  static Future<Map<String, dynamic>> createAccount({
    required String token,
    required String email,
    required String password,
    String? name,
    required List<int> departmentIds,
    required bool isAdmin,
    required AccountAccess access,
  }) async {
    return _requestObject(
      () => http.post(
        Uri.parse('$baseUrl/accounts'),
        headers: _headers(token: token),
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'name': name,
          'departmentIds': departmentIds,
          'isAdmin': isAdmin,
          'basisAccess': access.basis,
          'whsToursAccess': access.whsTours,
          'ovaAccess': access.ova,
          'japGppAccess': access.japGpp,
          'maintenanceInspectionsAccess': access.maintenanceInspections,
        }),
      ),
    );
  }

  static Future<Map<String, dynamic>> updateAccountAccess({
    required String token,
    required int accountId,
    required bool isAdmin,
    required AccountAccess access,
  }) async {
    return _requestObject(
      () => http.patch(
        Uri.parse('$baseUrl/accounts/$accountId/access'),
        headers: _headers(token: token),
        body: jsonEncode({
          'isAdmin': isAdmin,
          'basisAccess': access.basis,
          'whsToursAccess': access.whsTours,
          'ovaAccess': access.ova,
          'japGppAccess': access.japGpp,
          'maintenanceInspectionsAccess': access.maintenanceInspections,
        }),
      ),
    );
  }

  static Future<void> deleteAccount({
    required String token,
    required int accountId,
  }) async {
    await _requestObject(
      () => http.delete(
        Uri.parse('$baseUrl/accounts/$accountId'),
        headers: _headers(token: token),
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> fetchOvaTickets({
    required String token,
  }) async {
    final response = await _requestObject(
      () => http.get(
        Uri.parse('$baseUrl/ova/tickets'),
        headers: _headers(token: token),
      ),
    );

    final tickets = response['tickets'];
    if (tickets is! List) {
      throw Exception('Invalid OVA ticket list received from the server');
    }

    return tickets
        .whereType<Map>()
        .map((ticket) => Map<String, dynamic>.from(ticket))
        .toList();
  }

  static Future<Map<String, dynamic>> fetchOvaTicket({
    required String token,
    required int ticketId,
  }) async {
    final response = await _requestObject(
      () => http.get(
        Uri.parse('$baseUrl/ova/tickets/$ticketId'),
        headers: _headers(token: token),
      ),
    );

    final ticket = response['ticket'];
    if (ticket is! Map) {
      throw Exception('Invalid OVA ticket received from the server');
    }

    return Map<String, dynamic>.from(ticket);
  }

  static Future<List<Map<String, dynamic>>> fetchOvaAssignableUsers({
    required String token,
  }) async {
    final response = await _requestObject(
      () => http.get(
        Uri.parse('$baseUrl/ova/tickets/assignable-users'),
        headers: _headers(token: token),
      ),
    );

    final users = response['users'];
    if (users is! List) {
      throw Exception(
        'Invalid OVA assignable user list received from the server',
      );
    }

    return users
        .whereType<Map>()
        .map((user) => Map<String, dynamic>.from(user))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> fetchOvaExternalContacts({
    required String token,
    String? query,
  }) async {
    final uri = Uri.parse('$baseUrl/ova/tickets/external-contacts').replace(
      queryParameters: query != null && query.trim().isNotEmpty
          ? {'query': query.trim()}
          : null,
    );

    final response = await _requestObject(
      () => http.get(uri, headers: _headers(token: token)),
    );

    final contacts = response['contacts'];
    if (contacts is! List) {
      throw Exception(
        'Invalid OVA external contact list received from the server',
      );
    }

    return contacts
        .whereType<Map>()
        .map((contact) => Map<String, dynamic>.from(contact))
        .toList();
  }

  static Future<Map<String, dynamic>> createOvaTicket({
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _requestObject(
      () => http.post(
        Uri.parse('$baseUrl/ova/tickets'),
        headers: _headers(token: token),
        body: jsonEncode(payload),
      ),
    );

    final ticket = response['ticket'];
    if (ticket is! Map) {
      throw Exception('Invalid OVA ticket received from the server');
    }

    return Map<String, dynamic>.from(ticket);
  }

  static Future<Map<String, dynamic>> updateOvaTicket({
    required String token,
    required int ticketId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _requestObject(
      () => http.patch(
        Uri.parse('$baseUrl/ova/tickets/$ticketId'),
        headers: _headers(token: token),
        body: jsonEncode(payload),
      ),
    );

    final ticket = response['ticket'];
    if (ticket is! Map) {
      throw Exception('Invalid OVA ticket received from the server');
    }

    return Map<String, dynamic>.from(ticket);
  }

  static Future<List<Map<String, dynamic>>> fetchMyOvaActions({
    required String token,
  }) async {
    final response = await _requestObject(
      () => http.get(
        Uri.parse('$baseUrl/ova/actions/my'),
        headers: _headers(token: token),
      ),
    );

    final actions = response['actions'];
    if (actions is! List) {
      throw Exception('Invalid OVA action list received from the server');
    }

    return actions
        .whereType<Map>()
        .map((action) => Map<String, dynamic>.from(action))
        .toList();
  }

  static Future<Map<String, dynamic>> updateOvaAction({
    required String token,
    required int actionId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _requestObject(
      () => http.patch(
        Uri.parse('$baseUrl/ova/actions/$actionId'),
        headers: _headers(token: token),
        body: jsonEncode(payload),
      ),
    );

    final action = response['action'];
    if (action is! Map) {
      throw Exception('Invalid OVA action received from the server');
    }

    return Map<String, dynamic>.from(action);
  }

  static Future<List<Map<String, dynamic>>> fetchNotifications({
    required String token,
    int limit = 50,
  }) async {
    final response = await _requestObject(
      () => http.get(
        Uri.parse('$baseUrl/notifications?limit=$limit'),
        headers: _headers(token: token),
      ),
    );

    final notifications = response['notifications'];
    if (notifications is! List) {
      throw Exception('Invalid notification list received from the server');
    }

    return notifications
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<int> fetchUnreadNotificationCount({
    required String token,
  }) async {
    final response = await _requestObject(
      () => http.get(
        Uri.parse('$baseUrl/notifications/unread-count'),
        headers: _headers(token: token),
      ),
    );

    final unreadCount = response['unreadCount'];
    if (unreadCount is! num) {
      return 0;
    }

    return unreadCount.toInt();
  }

  static Future<void> markNotificationsRead({
    required String token,
    required List<int> notificationIds,
  }) async {
    await _requestObject(
      () => http.patch(
        Uri.parse('$baseUrl/notifications/mark-read'),
        headers: _headers(token: token),
        body: jsonEncode({'notificationIds': notificationIds}),
      ),
    );
  }

  static Future<void> markAllNotificationsRead({
    required String token,
  }) async {
    await _requestObject(
      () => http.patch(
        Uri.parse('$baseUrl/notifications/mark-all-read'),
        headers: _headers(token: token),
      ),
    );
  }

  static Map<String, String> _headers({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> _requestObject(
    Future<http.Response> Function() request,
  ) async {
    final response = await request();
    final payload = _decodePayload(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (payload is Map<String, dynamic>) {
        return payload;
      }

      if (payload is Map) {
        return Map<String, dynamic>.from(payload);
      }

      return <String, dynamic>{};
    }

    throw Exception(_extractMessage(payload, response.statusCode));
  }

  static dynamic _decodePayload(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  static String _extractMessage(dynamic payload, int statusCode) {
    if (payload is Map) {
      final message = payload['message'];
      if (message is List) {
        return message.join(', ');
      }
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }

    if (payload is String && payload.isNotEmpty) {
      return payload;
    }

    return 'Request failed with status code $statusCode';
  }
}
