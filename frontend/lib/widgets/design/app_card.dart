import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Standard surface card with optional tap handling.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.borderColor,
    this.borderRadius = kRadiusLg,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final surface = color ?? kSurface;
    final border = borderColor ?? kBorder;

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        onTap: onTap,
        hoverColor: kSurfaceHover,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: border),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Surface card with hover-lift, used for grid tiles.
class AppTileCard extends StatefulWidget {
  const AppTileCard({
    super.key,
    required this.child,
    required this.onTap,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
  });

  final Widget child;
  final VoidCallback onTap;
  final double? width;
  final EdgeInsets padding;

  @override
  State<AppTileCard> createState() => _AppTileCardState();
}

class _AppTileCardState extends State<AppTileCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        child: Material(
          color: kSurface,
          borderRadius: BorderRadius.circular(kRadiusXl),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(kRadiusXl),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: widget.width,
              padding: widget.padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kRadiusXl),
                border: Border.all(
                  color: _hovered ? kBrandGreenDark : kBorder,
                  width: _hovered ? 1.4 : 1,
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
