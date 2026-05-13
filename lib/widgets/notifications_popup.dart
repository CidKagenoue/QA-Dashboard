import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/notification_setting.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) {
        return;
      }

      final notificationService = context.read<NotificationService>();
      await notificationService.loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaties'),
        actions: [
          Consumer<NotificationService>(
            builder: (context, notificationService, child) {
              final hasNotifications = notificationService.notifications.isNotEmpty;

              return TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD32F2F),
                  disabledForegroundColor: const Color(0xFFD32F2F).withOpacity(0.38),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: hasNotifications
                    ? () async {
                        final confirmed = await _confirmDelete(
                          context,
                          title: 'Alle notificaties verwijderen?',
                          message:
                              'Weet je zeker dat je alle notificaties wilt verwijderen? Deze actie kan niet ongedaan worden gemaakt.',
                        );

                        if (!confirmed || !context.mounted) {
                          return;
                        }

                        await notificationService.deleteAllNotifications();
                      }
                    : null,
                
                label: const Text('Alles verwijderen'),
              );
            },
          ),
          Consumer<NotificationService>(
            builder: (context, notificationService, child) {
              final canMarkAllRead =
                  notificationService.notifications.any((item) => !item.isRead);

              return TextButton(
                onPressed: canMarkAllRead
                    ? () => notificationService.markAllRead()
                    : null,
                child: const Text('Alles gelezen'),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationService>(
        builder: (context, notificationService, child) {
          if (notificationService.isLoading &&
              !notificationService.hasLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          if (notificationService.notifications.isEmpty) {
            return const Center(
              child: Text('Nog geen notificaties.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () => notificationService.loadNotifications(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notificationService.notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = notificationService.notifications[index];

                return _NotificationTile(
                  item: item,
                  onDelete: () async {
                    final confirmed = await _confirmDelete(
                      context,
                      title: 'Notificatie verwijderen?',
                      message:
                          'Weet je zeker dat je deze notificatie wilt verwijderen? Deze actie kan niet ongedaan worden gemaakt.',
                    );

                    if (!confirmed || !context.mounted) {
                      return;
                    }

                    await notificationService.deleteNotification(item.id);
                  },
                  onTap: () async {
                    if (!item.isRead) {
                      await notificationService.markAsRead([item.id]);
                    }

                    if (!context.mounted) {
                      return;
                    }

                    final opened = await NotificationNavigationService.openContext(
                      context,
                      item,
                    );
                    if (opened || !context.mounted) {
                      return;
                    }

                    showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: Text(item.title),
                        content: Text(item.body),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Sluiten'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final AppNotification item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final timeLabel = _relativeTimeLabel(item.createdAt);

    return Material(
      color: item.isRead ? Colors.white : const Color(0xFFEFF7E7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (!item.isRead)
                    const Icon(
                      Icons.brightness_1,
                      size: 10,
                      color: Color(0xFF6B8F2A),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Verwijder notificatie',
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(item.body),
              const SizedBox(height: 4),
              Text(
                _contextLabel(item),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF66705E),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                timeLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF66705E),
                ),
              ),
            ],
          ),
        ),
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

  String _contextLabel(AppNotification item) {
    if (item.metadata == null || item.metadata!.isEmpty) {
      return item.type.replaceAll('_', ' ');
    }

    if (item.ticketId != null) {
      return 'OVA ticket #${item.ticketId}';
    }

    if (item.accountId != null) {
      return 'Account #${item.accountId}';
    }

    final source = item.source;
    if (source is String && source.isNotEmpty) {
      if (source == 'reset-password') {
        return 'Wachtwoord reset';
      }

      if (source == 'change-password') {
        return 'Wachtwoord gewijzigd';
      }
    }

    return item.type.replaceAll('_', ' ');
  }
}

Future<bool> _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Annuleren'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Verwijderen'),
        ),
      ],
    ),
  );

  return result ?? false;
}
