import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Light, text-based breadcrumb shown above the page title.
class AppBreadcrumb extends StatelessWidget {
  const AppBreadcrumb({super.key, required this.segments});

  final List<String> segments;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      final isLast = i == segments.length - 1;
      children.add(
        Text(
          segments[i],
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
            color: isLast ? kTextSecondary : kTextTertiary,
            letterSpacing: 0.1,
          ),
        ),
      );
      if (!isLast) {
        children.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.chevron_right_rounded,
              size: 16, color: kTextMuted),
        ));
      }
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}
