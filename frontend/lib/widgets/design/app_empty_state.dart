import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Vector-style empty-state illustration painted with the brand palette.
class _EmptyIllustration extends StatelessWidget {
  const _EmptyIllustration({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft outer halo
          Container(
            decoration: BoxDecoration(
              color: kBrandGreenSubtle,
              shape: BoxShape.circle,
            ),
          ),
          // Inner ring
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kBrandGreenSoft,
              shape: BoxShape.circle,
            ),
          ),
          // Decorative dots
          Positioned(
            top: 14,
            right: 10,
            child: _Dot(size: 10, color: kBrandGreenDeep.withValues(alpha: 0.25)),
          ),
          Positioned(
            bottom: 18,
            left: 8,
            child: _Dot(size: 6, color: kBrandGreenDeep.withValues(alpha: 0.35)),
          ),
          Positioned(
            top: 22,
            left: 18,
            child: _Dot(size: 4, color: kBrandGreenDeep.withValues(alpha: 0.4)),
          ),
          // Core icon chip
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: kSurface,
              shape: BoxShape.circle,
              border: Border.all(color: kBorder),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 28, color: kBrandGreenDeep),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Empty-state shown when a list has no items. Uses a decorative illustration
/// instead of a flat icon.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.tone = AppEmptyTone.subtle,
  });

  /// Construct an emphasis-tone empty state — usually used inside a list
  /// container that should fill the available width.
  const AppEmptyState.emphasis({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : tone = AppEmptyTone.emphasis;

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final AppEmptyTone tone;

  @override
  Widget build(BuildContext context) {
    final isEmphasis = tone == AppEmptyTone.emphasis;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isEmphasis ? 36 : 28),
      decoration: BoxDecoration(
        color: isEmphasis ? kSurfaceMuted : Colors.transparent,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: isEmphasis ? Border.all(color: kBorder) : null,
      ),
      child: Column(
        children: [
          _EmptyIllustration(icon: icon),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: kTextTertiary,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

enum AppEmptyTone { subtle, emphasis }
