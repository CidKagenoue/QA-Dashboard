import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qa_dashboard/screens/settings_screen_navigation.dart';
import '../../services/auth_service.dart';
import '../notifications_popup.dart';
import '../../services/notification_service.dart';
import '../../models/notification_setting.dart' show AppNotification;
import '../../screens/login_screen.dart';

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const MainAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final isSettingsRoute = ModalRoute.of(context)?.settings.name == '/settings';

    return AppBar(
      backgroundColor: const Color(0xFF8BC34A),
      foregroundColor: Colors.white,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      actions: [
        Consumer<NotificationService>(
          builder: (context, notificationService, child) {
            final unreadCount = notificationService.unreadCount;
            final recentNotifications = notificationService.notifications.take(5).toList();

            return PopupMenuButton<String>(
              tooltip: 'Notificaties',
              offset: const Offset(0, 12),
              onOpened: () async {
                // Always refresh notifications so new items appear immediately.
                final service = context.read<NotificationService>();
                debugPrint('[MainAppBar] Notification popup opened. hasLoaded=${service.hasLoaded}, count=${service.notifications.length}');

                try {
                  await service.loadNotifications(limit: 50);
                  await service.refreshUnreadCount();
                  debugPrint('[MainAppBar] Refreshed notifications after popup open');
                } catch (e) {
                  debugPrint('[MainAppBar] Failed to refresh notifications: $e');
                }
              },
              onSelected: (value) async {
                if (value == 'open-all') {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );

                  if (context.mounted) {
                    await context.read<NotificationService>().refreshUnreadCount();
                  }
                  return;
                }

                if (!value.startsWith('open-notification:')) {
                  return;
                }

                final id = int.tryParse(value.replaceFirst('open-notification:', ''));
                if (id == null) {
                  return;
                }

                final selected = recentNotifications.where((item) => item.id == id);
                if (selected.isEmpty) {
                  return;
                }

                final notification = selected.first;
                if (!notification.isRead) {
                  await context.read<NotificationService>().markAsRead([notification.id]);
                }

                if (!context.mounted) {
                  return;
                }

                final opened = await NotificationNavigationService.openContext(
                  context,
                  notification,
                );
                if (opened && context.mounted) {
                  await context.read<NotificationService>().refreshUnreadCount();
                }

                if (!opened && context.mounted) {
                  await _openNotificationDialog(context, notification);
                }
              },
              itemBuilder: (menuContext) {
                final items = <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    enabled: false,
                    child: SizedBox(
                      width: 320,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            unreadCount == 0
                                ? 'Geen nieuwe notificaties'
                                : '$unreadCount nieuwe notificatie${unreadCount == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Recente updates verschijnen hier kort onder het belletje.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const PopupMenuDivider(),
                ];

                if (recentNotifications.isEmpty) {
                  items.add(
                    const PopupMenuItem<String>(
                      enabled: false,
                      child: SizedBox(
                        width: 320,
                        child: Text('Nog geen meldingen om te tonen.'),
                      ),
                    ),
                  );
                } else {
                  for (final notification in recentNotifications) {
                    items.add(
                      PopupMenuItem<String>(
                        value: 'open-notification:${notification.id}',
                        child: SizedBox(
                          width: 320,
                          child: _NotificationPreviewTile(
                            title: notification.title,
                            body: notification.body,
                            timeLabel: _relativeTimeLabel(notification.createdAt),
                            unread: !notification.isRead,
                          ),
                        ),
                      ),
                    );
                  }
                }

                items.add(const PopupMenuDivider());
                items.add(
                  const PopupMenuItem<String>(
                    value: 'open-all',
                    child: Text('Alles openen'),
                  ),
                );

                return items;
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.notifications_outlined, color: Colors.white),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD83B01),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: isSettingsRoute
              ? null
              : () {
            Navigator.of(context).push(
              MaterialPageRoute(
                settings: const RouteSettings(name: '/settings'),
                builder: (context) => const SettingsScreen(),
              ),
            );
          },
        ),
        Consumer<AuthService>(
          builder: (context, authService, child) {
            return IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                await authService.logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                }
              },
            );
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

Future<void> _openNotificationDialog(
  BuildContext context,
  AppNotification notification,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(notification.title),
      content: Text(notification.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Sluiten'),
        ),
      ],
    ),
  );
}

String _relativeTimeLabel(DateTime value) {
  final now = DateTime.now();
  final difference = now.difference(value);

  if (difference.inMinutes < 1) {
    return 'Zojuist';
  }

  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} min geleden';
  }

  if (difference.inHours < 24) {
    return '${difference.inHours} u geleden';
  }

  return '${difference.inDays} d geleden';
}

class _NotificationPreviewTile extends StatelessWidget {
  const _NotificationPreviewTile({
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.unread,
  });

  final String title;
  final String body;
  final String timeLabel;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: unread ? const Color(0xFFF3F9E9) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (unread)
                const Icon(Icons.brightness_1, size: 9, color: Color(0xFF6B8F2A)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            timeLabel,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
