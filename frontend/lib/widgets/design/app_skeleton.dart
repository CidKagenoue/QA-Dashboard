import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Animated placeholder that pulses while content is loading. Use it inside
/// the same layout as the eventual content so the page reserves its space.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = kRadiusSm,
  });

  /// Convenience for circular avatars / icon chips.
  const AppSkeleton.circle({super.key, required double size})
      : width = size,
        height = size,
        borderRadius = size;

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final color = Color.lerp(
          const Color(0xFFE9ECE3),
          const Color(0xFFF2F4ED),
          t,
        )!;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Skeleton variant of a card that mimics the standard list-row layout.
class AppListRowSkeleton extends StatelessWidget {
  const AppListRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppSkeleton.circle(size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSkeleton(height: 14, width: 220),
                    const SizedBox(height: 8),
                    AppSkeleton(
                      height: 12,
                      width: MediaQuery.of(context).size.width * 0.35,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const AppSkeleton(height: 22, width: 60, borderRadius: 999),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton variant of a metric card (used on dashboard).
class AppMetricCardSkeleton extends StatelessWidget {
  const AppMetricCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              AppSkeleton(height: 12, width: 90),
              Spacer(),
              AppSkeleton.circle(size: 18),
            ],
          ),
          SizedBox(height: 18),
          AppSkeleton(height: 28, width: 80),
          SizedBox(height: 10),
          AppSkeleton(height: 12, width: 130),
        ],
      ),
    );
  }
}
