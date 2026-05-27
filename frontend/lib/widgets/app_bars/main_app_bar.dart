import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qa_dashboard/screens/settings_screen_navigation.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../notifications_popup.dart';
import '../../services/notification_service.dart';
import '../../models/notification_setting.dart' show AppNotification;
import '../../screens/login_screen.dart';
import '../vlotter_logo.dart';

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const MainAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final isSettingsRoute =
        ModalRoute.of(context)?.settings.name == '/settings';
    final isLogo = title.trim().toLowerCase() == 'vlotter';

    return AppBar(
      backgroundColor: kSurface,
      foregroundColor: kTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: const Border(bottom: BorderSide(color: kBorder, width: 1)),
      titleSpacing: 24,
      title: isLogo
          ? const VlotterLogo(color: VlotterLogoColor.green, height: 28)
          : Text(
              title,
              style: const TextStyle(
                color: kTextPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
      actions: [
        Consumer<NotificationService>(
          builder: (context, notificationService, child) {
            final unreadCount = notificationService.unreadCount;
            final recentNotifications = notificationService.notifications
                .take(5)
                .toList();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: PopupMenuButton<String>(
                tooltip: 'Notificaties',
                offset: const Offset(0, 12),
                position: PopupMenuPosition.under,
                color: kSurface,
                surfaceTintColor: Colors.transparent,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kRadiusLg),
                  side: const BorderSide(color: kBorder),
                ),
                onOpened: () async {
                  final service = context.read<NotificationService>();
                  debugPrint(
                    '[MainAppBar] Notification popup opened. hasLoaded=${service.hasLoaded}, count=${service.notifications.length}',
                  );

                  try {
                    await service.loadNotifications(limit: 50);
                    await service.refreshUnreadCount();
                    debugPrint(
                      '[MainAppBar] Refreshed notifications after popup open',
                    );
                  } catch (e) {
                    debugPrint(
                      '[MainAppBar] Failed to refresh notifications: $e',
                    );
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
                      await context
                          .read<NotificationService>()
                          .refreshUnreadCount();
                    }
                    return;
                  }

                  if (!value.startsWith('open-notification:')) {
                    return;
                  }

                  final id = int.tryParse(
                    value.replaceFirst('open-notification:', ''),
                  );
                  if (id == null) {
                    return;
                  }

                  final selected = recentNotifications.where(
                    (item) => item.id == id,
                  );
                  if (selected.isEmpty) {
                    return;
                  }

                  final notification = selected.first;
                  if (!notification.isRead) {
                    await context.read<NotificationService>().markAsRead([
                      notification.id,
                    ]);
                  }

                  if (!context.mounted) {
                    return;
                  }

                  final opened =
                      await NotificationNavigationService.openContext(
                        context,
                        notification,
                      );
                  if (opened && context.mounted) {
                    await context
                        .read<NotificationService>()
                        .refreshUnreadCount();
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
                        width: 340,
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
                                fontSize: 14.5,
                                color: kTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Recente updates verschijnen hier kort onder het belletje.',
                              style: TextStyle(
                                color: kTextTertiary,
                                fontSize: 12.5,
                                height: 1.4,
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
                          width: 340,
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Nog geen meldingen om te tonen.',
                              style: TextStyle(color: kTextTertiary),
                            ),
                          ),
                        ),
                      ),
                    );
                  } else {
                    for (final notification in recentNotifications) {
                      items.add(
                        PopupMenuItem<String>(
                          value: 'open-notification:${notification.id}',
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: SizedBox(
                            width: 340,
                            child: _NotificationPreviewTile(
                              title: notification.title,
                              body: notification.body,
                              timeLabel: _relativeTimeLabel(
                                notification.createdAt,
                              ),
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
                      child: Row(
                        children: [
                          Icon(
                            Icons.unfold_more_rounded,
                            size: 18,
                            color: kBrandGreenDark,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Alle meldingen openen',
                            style: TextStyle(
                              color: kBrandGreenDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  return items;
                },
                child: _AppBarIconSlot(
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_none_rounded,
                        color: kTextSecondary,
                        size: 24,
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: -4,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            decoration: BoxDecoration(
                              color: kDanger,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: kSurface, width: 1.5),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: 'Instellingen',
          child: _AppBarIconButton(
            icon: Icons.settings_outlined,
            onTap: isSettingsRoute
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
        ),
        const SizedBox(width: 4),
        Consumer<AuthService>(
          builder: (context, authService, child) {
            return Tooltip(
              message: 'Uitloggen',
              child: _AppBarIconButton(
                icon: Icons.logout_rounded,
                onTap: () async {
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
              ),
            );
          },
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(64);
}

class _AppBarIconButton extends StatelessWidget {
  const _AppBarIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: _AppBarIconSlot(
        child: Icon(
          icon,
          size: 24,
          color: onTap == null ? kTextMuted : kTextSecondary,
        ),
      ),
    );
  }
}

class _AppBarIconSlot extends StatelessWidget {
  const _AppBarIconSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(kRadiusMd)),
      child: child,
    );
  }
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
        color: unread ? kBrandGreenSubtle : Colors.transparent,
        borderRadius: BorderRadius.circular(kRadiusSm),
      ),
      padding: const EdgeInsets.all(12),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: kTextPrimary,
                  ),
                ),
              ),
              if (unread)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: kBrandGreenDark,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: kTextSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            timeLabel,
            style: const TextStyle(
              fontSize: 11.5,
              color: kTextMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
