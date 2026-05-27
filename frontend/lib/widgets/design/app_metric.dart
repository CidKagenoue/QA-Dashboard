import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AppMetricData {
  const AppMetricData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

/// Single metric row used in detail-screen summary strips: small green icon
/// chip, label on top, bold value underneath.
class AppMetric extends StatelessWidget {
  const AppMetric({super.key, required this.data});

  final AppMetricData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: kBrandGreenSoft,
            borderRadius: BorderRadius.circular(kRadiusSm),
          ),
          alignment: Alignment.center,
          child: Icon(data.icon, size: 18, color: kBrandGreenDeep),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: kTextTertiary,
                  height: 1.2,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Lays a list of [AppMetric] widgets out as a single horizontal strip with
/// thin vertical dividers when there is enough room, otherwise wraps them.
class AppMetricStrip extends StatelessWidget {
  const AppMetricStrip({
    super.key,
    required this.metrics,
    this.padding = const EdgeInsets.all(18),
    this.compactBreakpoint = 900,
    this.wrapBreakpoint = 560,
  });

  final List<AppMetricData> metrics;
  final EdgeInsets padding;
  final double compactBreakpoint;
  final double wrapBreakpoint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: kSurfaceMuted,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= compactBreakpoint) {
            final children = <Widget>[];
            for (var i = 0; i < metrics.length; i++) {
              children.add(Expanded(child: AppMetric(data: metrics[i])));
              if (i != metrics.length - 1) {
                children.add(const SizedBox(
                  height: 36,
                  child:
                      VerticalDivider(width: 24, color: kBorderSubtle),
                ));
              }
            }
            return Row(children: children);
          }

          final itemWidth = constraints.maxWidth >= wrapBreakpoint
              ? (constraints.maxWidth - 16) / 2
              : constraints.maxWidth;

          return Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: metrics
                .map((metric) =>
                    SizedBox(width: itemWidth, child: AppMetric(data: metric)))
                .toList(),
          );
        },
      ),
    );
  }
}
