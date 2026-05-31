import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

/// API-calls rond authenticatie en het eigen account
/// (login, tokens, wachtwoord-flows, profiel).
class AuthApiService {
  static Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiClient.baseUrl}/auth/change-password'),
      headers: ApiClient.headers(token: token),
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmNewPassword': confirmNewPassword,
      }),
    );

    if (response.statusCode == 204 || response.statusCode == 200) {
      return;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Wachtwoord wijzigen mislukt');
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    return ApiClient.requestObject(
      () => http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/login'),
        headers: ApiClient.headers(),
        body: jsonEncode({'email': email.trim(), 'password': password}),
      ),
    );
  }

  static Future<void> logout({required String refreshToken}) async {
    await ApiClient.requestObject(
      () => http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/logout'),
        headers: ApiClient.headers(),
        body: jsonEncode({'refreshToken': refreshToken}),
      ),
    );
  }

  static Future<Map<String, dynamic>> refreshToken({
    required String refreshToken,
  }) async {
    return ApiClient.requestObject(
      () => http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/refresh'),
        headers: ApiClient.headers(),
        body: jsonEncode({'refreshToken': refreshToken}),
      ),
    );
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    return ApiClient.requestObject(
      () => http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/forgot-password'),
        headers: ApiClient.headers(),
        body: jsonEncode({'email': email.trim()}),
      ),
    );
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    return ApiClient.requestObject(
      () => http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/reset-password'),
        headers: ApiClient.headers(),
        body: jsonEncode({
          'token': token,
          'password': password,
          'confirmPassword': confirmPassword,
        }),
      ),
    );
  }

  static Future<Map<String, dynamic>> verifyResetToken(String token) async {
    return ApiClient.requestObject(
      () => http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/verify-reset-token'),
        headers: ApiClient.headers(),
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
    bool includeProfileImage = false,
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
    if (includeProfileImage) {
      payload['profileImage'] = profileImage;
    }

    return ApiClient.requestObject(
      () => http.patch(
        Uri.parse('${ApiClient.baseUrl}/users/$userId'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode(payload),
      ),
    );
  }
}
