import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

/// API-calls voor OVA-tickets en hun opvolgingsacties.
class OvaApiService {
  static Future<List<Map<String, dynamic>>> fetchOvaTickets({
    required String token,
  }) async {
    final response = await ApiClient.requestObject(
      () => http.get(
        Uri.parse('${ApiClient.baseUrl}/ova/tickets'),
        headers: ApiClient.headers(token: token),
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
    final response = await ApiClient.requestObject(
      () => http.get(
        Uri.parse('${ApiClient.baseUrl}/ova/tickets/$ticketId'),
        headers: ApiClient.headers(token: token),
      ),
    );

    final ticket = response['ticket'];
    if (ticket is! Map) {
      throw Exception('Invalid OVA ticket received from the server');
    }

    return Map<String, dynamic>.from(ticket);
  }

  static Future<Map<String, dynamic>> fetchOvaFormData({
    required String token,
  }) async {
    return ApiClient.requestObject(
      () => http.get(
        Uri.parse('${ApiClient.baseUrl}/ova/form-data'),
        headers: ApiClient.headers(token: token),
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> fetchOvaAssignableUsers({
    required String token,
  }) async {
    final response = await ApiClient.requestObject(
      () => http.get(
        Uri.parse('${ApiClient.baseUrl}/ova/tickets/assignable-users'),
        headers: ApiClient.headers(token: token),
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
    final uri = Uri.parse('${ApiClient.baseUrl}/ova/tickets/external-contacts')
        .replace(
          queryParameters: query != null && query.trim().isNotEmpty
              ? {'query': query.trim()}
              : null,
        );

    final response = await ApiClient.requestObject(
      () => http.get(uri, headers: ApiClient.headers(token: token)),
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
    final response = await ApiClient.requestObject(
      () => http.post(
        Uri.parse('${ApiClient.baseUrl}/ova/tickets'),
        headers: ApiClient.headers(token: token),
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
    final response = await ApiClient.requestObject(
      () => http.patch(
        Uri.parse('${ApiClient.baseUrl}/ova/tickets/$ticketId'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode(payload),
      ),
    );

    final ticket = response['ticket'];
    if (ticket is! Map) {
      throw Exception('Invalid OVA ticket received from the server');
    }

    return Map<String, dynamic>.from(ticket);
  }

  static Future<void> deleteOvaTicket({
    required String token,
    required int ticketId,
  }) async {
    await ApiClient.requestObject(
      () => http.delete(
        Uri.parse('${ApiClient.baseUrl}/ova/tickets/$ticketId'),
        headers: ApiClient.headers(token: token),
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> fetchMyOvaActions({
    required String token,
  }) async {
    final response = await fetchOvaActions(token: token, scope: 'mine');
    final actions = response['actions'];
    if (actions is! List) {
      throw Exception('Invalid OVA action list received from the server');
    }

    return actions
        .whereType<Map>()
        .map((action) => Map<String, dynamic>.from(action))
        .toList();
  }

  static Future<Map<String, dynamic>> fetchOvaActions({
    required String token,
    String scope = 'mine',
  }) async {
    final response = await ApiClient.requestObject(
      () => http.get(
        Uri.parse(
          '${ApiClient.baseUrl}/ova/actions',
        ).replace(queryParameters: {'scope': scope}),
        headers: ApiClient.headers(token: token),
      ),
    );
    return response;
  }

  static Future<Map<String, dynamic>> updateOvaAction({
    required String token,
    required int actionId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await ApiClient.requestObject(
      () => http.patch(
        Uri.parse('${ApiClient.baseUrl}/ova/actions/$actionId'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode(payload),
      ),
    );

    final action = response['action'];
    if (action is! Map) {
      throw Exception('Invalid OVA action received from the server');
    }

    return Map<String, dynamic>.from(action);
  }

  static Future<void> deleteOvaAction({
    required String token,
    required int actionId,
  }) async {
    await ApiClient.requestObject(
      () => http.delete(
        Uri.parse('${ApiClient.baseUrl}/ova/actions/$actionId'),
        headers: ApiClient.headers(token: token),
      ),
    );
  }
}
