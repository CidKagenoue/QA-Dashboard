import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum AppStatusTone { success, danger, warning, info, neutral, brand }

/// Compact label that communicates state. Use `tone` to pick a semantic colour
/// scheme.
class AppStatusPill extends StatelessWidget {
  const AppStatusPill({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  final String label;
  final AppStatusTone tone;
  final IconData? icon;

  ({Color bg, Color fg, Color border}) get _colors {
    switch (tone) {
      case AppStatusTone.success:
        return (bg: kSuccessBg, fg: kSuccess, border: kSuccessBorder);
      case AppStatusTone.danger:
        return (bg: kDangerBg, fg: kDanger, border: kDangerBorder);
      case AppStatusTone.warning:
        return (bg: kWarningBg, fg: kWarning, border: kWarningBorder);
      case AppStatusTone.info:
        return (bg: kInfoBg, fg: kInfo, border: kInfoBorder);
      case AppStatusTone.brand:
        return (bg: kBrandGreenSoft, fg: kBrandGreenDeep, border: kBrandGreenSoft);
      case AppStatusTone.neutral:
        return (bg: kSurfaceMuted, fg: kTextSecondary, border: kBorder);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c.fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: c.fg,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
