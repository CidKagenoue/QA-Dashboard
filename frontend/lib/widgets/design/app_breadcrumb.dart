import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AppBreadcrumbNavigation extends InheritedWidget {
  const AppBreadcrumbNavigation({
    super.key,
    required this.onNavigateTo,
    required super.child,
  });

  final ValueChanged<String> onNavigateTo;

  static AppBreadcrumbNavigation? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppBreadcrumbNavigation>();
  }

  @override
  bool updateShouldNotify(AppBreadcrumbNavigation oldWidget) {
    return onNavigateTo != oldWidget.onNavigateTo;
  }
}

/// Light, text-based breadcrumb shown above the page title.
class AppBreadcrumb extends StatelessWidget {
  const AppBreadcrumb({super.key, required this.segments});

  final List<String> segments;

  @override
  Widget build(BuildContext context) {
    final navigation = AppBreadcrumbNavigation.maybeOf(context);
    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      final isLast = i == segments.length - 1;
      final segment = segments[i];
      final navigationKey = _navigationKeyFor(segment);
      final onTap = navigation != null && navigationKey != null
          ? () => navigation.onNavigateTo(navigationKey)
          : null;

      children.add(
        _BreadcrumbSegment(label: segment, isLast: isLast, onTap: onTap),
      );
      if (!isLast) {
        children.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: kTextMuted,
            ),
          ),
        );
      }
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  String? _navigationKeyFor(String segment) {
    switch (segment) {
      case 'Dashboard':
        return 'dashboard';
      case 'WHS-Tours':
        return 'whsTours';
      case 'OVA':
        return 'ova';
      case 'Tickets':
        return 'ovaTickets';
      case 'Acties':
        return 'ovaActions';
      case 'Onderhoud':
      case 'Onderhoud & Keuringen':
        return 'onderhoud';
      case 'JAP & GPP':
        return 'japGpp';
      case 'Instellingen':
        return 'settings';
      case 'Profiel':
        return 'settingsProfile';
      case 'Meldingen':
        return 'settingsNotifications';
      case 'Accountbeheer':
        return 'settingsAccounts';
      case 'Afdelingen':
        return 'settingsDepartments';
      case 'Locaties':
        return 'settingsLocations';
      default:
        return null;
    }
  }
}

class _BreadcrumbSegment extends StatefulWidget {
  const _BreadcrumbSegment({
    required this.label,
    required this.isLast,
    required this.onTap,
  });

  final String label;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  State<_BreadcrumbSegment> createState() => _BreadcrumbSegmentState();
}

class _BreadcrumbSegmentState extends State<_BreadcrumbSegment> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isClickable = widget.onTap != null;
    final baseColor = widget.isLast ? kTextSecondary : kTextTertiary;
    final color = isClickable && _hovered ? kBrandGreenDeep : baseColor;

    final text = Text(
      widget.label,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: widget.isLast ? FontWeight.w700 : FontWeight.w500,
        color: color,
        letterSpacing: 0.1,
        decoration: isClickable && _hovered ? TextDecoration.underline : null,
        decorationColor: kBrandGreenDeep,
      ),
    );

    if (!isClickable) return text;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: text,
        ),
      ),
    );
  }
}
