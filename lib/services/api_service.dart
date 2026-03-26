import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3001';
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
  }) async {
    return _requestObject(
      () => http.patch(
        Uri.parse('$baseUrl/users/$userId'),
        headers: _headers(token: token),
        body: jsonEncode({
          if (name != null) 'name': name,
          if (email != null) 'email': email,
        }),
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
