import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
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
    Future.microtask(() {
      if (!mounted) {
        return;
      }

      final notificationsService = context.read<NotificationService>();
      notificationsService.loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaties'),
        actions: [
          Consumer<NotificationService>(
            builder: (context, notificationsService, child) {
              final canMarkAllRead =
                  notificationsService.notifications.any((item) => !item.isRead);

              return TextButton(
                onPressed: canMarkAllRead
                    ? () => notificationsService.markAllRead()
                    : null,
                child: const Text('Alles gelezen'),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationService>(
        builder: (context, notificationsService, child) {
          if (notificationsService.isLoading &&
              !notificationsService.hasLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          if (notificationsService.notifications.isEmpty) {
            return const Center(
              child: Text('Nog geen notificaties.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () => notificationsService.loadNotifications(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notificationsService.notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = notificationsService.notifications[index];

                return _NotificationTile(
                  item: item,
                  onTap: () async {
                    if (!item.isRead) {
                      await notificationsService.markAsRead([item.id]);
                    }

                    if (!context.mounted) {
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
  const _NotificationTile({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

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
    final metadata = item.metadata;
    if (metadata == null || metadata.isEmpty) {
      return item.type.replaceAll('_', ' ');
    }

    final ticketId = metadata['ticketId'];
    if (ticketId is num) {
      return 'OVA ticket #${ticketId.toInt()}';
    }

    final accountId = metadata['accountId'];
    if (accountId is num) {
      return 'Account #${accountId.toInt()}';
    }

    final source = metadata['source'];
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
