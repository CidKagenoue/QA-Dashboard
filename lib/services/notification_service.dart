import 'package:qa_dashboard/services/auth_service.dart';
import 'api_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/notification_setting.dart';
import '../screens/account_management_screen.dart';
import '../screens/ova_ticket_wizard_screen.dart';

// Service for fetching notification data from backend (simple API helper)
class NotificationApiService {
  final String baseUrl;
  NotificationApiService(this.baseUrl);

  Future<int> getUnreadCount(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/notifications/user/$userId/unread-count'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['count'] ?? 0;
    }
    throw Exception('Failed to load unread count');
  }
}

// Notification data service (notifications, unread count, mark as read, etc)
class NotificationService extends ChangeNotifier {
  AuthService? _authService;
  List<AppNotification> _notifications = const [];
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _hasLoaded = false;

  List<AppNotification> get notifications =>
      List<AppNotification>.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;

  void bindAuth(AuthService authService) {
    final previousUserId = _authService?.user?.id;
    final previousToken = _authService?.token;

    _authService = authService;

    if (!authService.isAuthenticated) {
      _reset();
      return;
    }

    final authChanged =
        previousUserId != authService.user?.id ||
        previousToken != authService.token;

    if (authChanged) {
      _hasLoaded = false;
      _notifications = const [];
      _unreadCount = 0;
      notifyListeners();
      Future.microtask(() async {
        await Future.wait([
          refreshUnreadCount(),
          loadNotifications(limit: 5),
        ]);
      });
    }
  }

  Future<void> loadNotifications({int limit = 50}) async {
    final token = await _requireToken();
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.fetchNotifications(
        token: token,
        limit: limit,
      );

      _notifications = response.map(AppNotification.fromJson).toList();
      // DEBUG LOGGING
      debugPrint('[NOTIFICATIONS] Opgehaald: ${_notifications.length}');
      for (final n in _notifications) {
        debugPrint('[NOTIFICATIONS] ${n.id} | ${n.title} | ${n.body} | isRead: ${n.isRead}');
      }
      _unreadCount = _notifications.where((item) => !item.isRead).length;
      _hasLoaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUnreadCount() async {
    final authService = _authService;
    if (authService == null || !authService.isAuthenticated) {
      _unreadCount = 0;
      notifyListeners();
      return;
    }

    try {
      final token = await _requireToken();
      final count = await ApiService.fetchUnreadNotificationCount(token: token);
      _unreadCount = count;
      notifyListeners();
    } catch (_) {
      // Avoid surfacing badge refresh failures globally.
    }
  }

  Future<void> markAsRead(List<int> notificationIds) async {
    if (notificationIds.isEmpty) return;
    final token = await _requireToken();
    await ApiService.markNotificationsAsRead(
      token: token,
      notificationIds: notificationIds,
    );
    final ids = notificationIds.toSet();
    _notifications = _notifications
        .map(
          (item) => ids.contains(item.id)
              ? AppNotification(
                  id: item.id,
                  type: item.type,
                  title: item.title,
                  body: item.body,
                  isRead: true,
                  createdAt: item.createdAt,
                  readAt: DateTime.now(),
                  metadata: item.metadata,
                )
              : item,
        )
        .toList();
    _unreadCount = _notifications.where((item) => !item.isRead).length;
    notifyListeners();
  }

  Future<void> markAllRead() async {
    final token = await _requireToken();
    await ApiService.markAllNotificationsAsRead(token: token);
    _notifications = _notifications
        .map(
          (item) => item.isRead
              ? item
              : AppNotification(
                  id: item.id,
                  type: item.type,
                  title: item.title,
                  body: item.body,
                  isRead: true,
                  createdAt: item.createdAt,
                  readAt: DateTime.now(),
                  metadata: item.metadata,
                ),
        )
        .toList();
    _unreadCount = 0;
    notifyListeners();
  }

  Future<String> _requireToken() async {
    final authService = _authService;
    if (authService == null || !authService.isAuthenticated) {
      throw Exception('Not authenticated');
    }

    return authService.getValidAccessToken();
  }

  void _reset() {
    _notifications = const [];
    _unreadCount = 0;
    _isLoading = false;
    _hasLoaded = false;
    notifyListeners();
  }
}

// Service for handling navigation based on notification context
class NotificationNavigationService {
  static Future<bool> openContext(
    BuildContext context,
    AppNotification notification,
  ) async {
    if (notification.ticketId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OvaTicketWizardScreen(
            ticketId: notification.ticketId,
          ),
        ),
      );
      return true;
    }

    if (notification.accountId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const AccountManagementScreen(),
        ),
      );
      return true;
    }

    return false;
  }
}
