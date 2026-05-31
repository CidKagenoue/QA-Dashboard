import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

/// API-calls voor notificaties (ophalen, ongelezen-teller, lezen-markeren,
/// verwijderen).
class NotificationApiService {
  static Future<List<Map<String, dynamic>>> fetchNotifications({
    required String token,
    int? limit,
    int? offset,
    bool? unreadOnly,
  }) async {
    final queryParameters = <String, String>{};
    if (limit != null) queryParameters['limit'] = limit.toString();
    if (offset != null) queryParameters['offset'] = offset.toString();
    if (unreadOnly != null) {
      queryParameters['unreadOnly'] = unreadOnly.toString();
    }

    final uri = Uri.parse('${ApiClient.baseUrl}/notifications').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    final response = await ApiClient.requestObject(
      () => http.get(uri, headers: ApiClient.headers(token: token)),
    );

    final notifications = response['notifications'];
    if (notifications is! List) {
      throw Exception('Invalid notification list received from the server');
    }

    return notifications
        .whereType<Map>()
        .map((n) => Map<String, dynamic>.from(n))
        .toList();
  }

  static Future<int> fetchUnreadNotificationCount({
    required String token,
  }) async {
    final response = await ApiClient.requestObject(
      () => http.get(
        Uri.parse('${ApiClient.baseUrl}/notifications/unread-count'),
        headers: ApiClient.headers(token: token),
      ),
    );
    final count = response['count'];
    if (count is int) return count;
    if (count is String) return int.tryParse(count) ?? 0;
    return 0;
  }

  static Future<void> markNotificationAsRead({
    required String token,
    required int notificationId,
  }) async {
    await ApiClient.requestObject(
      () => http.patch(
        Uri.parse('${ApiClient.baseUrl}/notifications/$notificationId/read'),
        headers: ApiClient.headers(token: token),
      ),
    );
  }

  static Future<void> markNotificationsAsRead({
    required String token,
    required List<int> notificationIds,
  }) async {
    await ApiClient.requestObject(
      () => http.patch(
        Uri.parse('${ApiClient.baseUrl}/notifications/mark-read'),
        headers: ApiClient.headers(token: token),
        body: json.encode({'notificationIds': notificationIds}),
      ),
    );
  }

  static Future<void> markAllNotificationsAsRead({
    required String token,
  }) async {
    await ApiClient.requestObject(
      () => http.patch(
        Uri.parse('${ApiClient.baseUrl}/notifications/mark-all-read'),
        headers: ApiClient.headers(token: token),
      ),
    );
  }

  static Future<void> deleteNotification({
    required String token,
    required int notificationId,
  }) async {
    await ApiClient.requestObject(
      () => http.delete(
        Uri.parse('${ApiClient.baseUrl}/notifications/$notificationId'),
        headers: ApiClient.headers(token: token),
      ),
    );
  }

  static Future<void> deleteAllNotifications({required String token}) async {
    await ApiClient.requestObject(
      () => http.delete(
        Uri.parse('${ApiClient.baseUrl}/notifications'),
        headers: ApiClient.headers(token: token),
      ),
    );
  }
}
