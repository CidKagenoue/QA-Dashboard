import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user.dart';
import 'api_client.dart';

/// API-calls voor accountbeheer (admin): accounts opvragen, aanmaken,
/// rechten/details wijzigen en verwijderen.
class AccountApiService {
  static Future<List<Map<String, dynamic>>> fetchAccounts({
    required String token,
    String? search,
  }) async {
    final queryParameters = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }

    final uri = Uri.parse('${ApiClient.baseUrl}/accounts').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    final response = await ApiClient.requestObject(
      () => http.get(uri, headers: ApiClient.headers(token: token)),
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
    return ApiClient.requestObject(
      () => http.post(
        Uri.parse('${ApiClient.baseUrl}/accounts'),
        headers: ApiClient.headers(token: token),
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
    return ApiClient.requestObject(
      () => http.patch(
        Uri.parse('${ApiClient.baseUrl}/accounts/$accountId/access'),
        headers: ApiClient.headers(token: token),
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

  static Future<Map<String, dynamic>> updateAccountDetails({
    required String token,
    required int accountId,
    required String email,
    required String name,
    String? password,
  }) async {
    final body = <String, dynamic>{'email': email.trim(), 'name': name.trim()};

    final trimmedPassword = password?.trim();
    if (trimmedPassword != null && trimmedPassword.isNotEmpty) {
      body['password'] = trimmedPassword;
    }

    return ApiClient.requestObject(
      () => http.patch(
        Uri.parse('${ApiClient.baseUrl}/accounts/$accountId'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode(body),
      ),
    );
  }

  static Future<void> deleteAccount({
    required String token,
    required int accountId,
  }) async {
    await ApiClient.requestObject(
      () => http.delete(
        Uri.parse('${ApiClient.baseUrl}/accounts/$accountId'),
        headers: ApiClient.headers(token: token),
      ),
    );
  }
}
