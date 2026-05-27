import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AppInfoField {
  const AppInfoField({
    required this.label,
    required this.value,
    this.wide = false,
  });

  final String label;
  final String value;
  final bool wide;
}

/// Auto-flowing key-value grid. Items wrap based on `minItemWidth`. Fields
/// marked `wide: true` always span the full width.
class AppInfoGrid extends StatelessWidget {
  const AppInfoGrid({
    super.key,
    required this.fields,
    this.minItemWidth = 200,
    this.maxColumns = 3,
    this.gap = 20,
    this.runGap = 16,
  });

  final List<AppInfoField> fields;
  final double minItemWidth;
  final int maxColumns;
  final double gap;
  final double runGap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount =
            ((constraints.maxWidth + gap) / (minItemWidth + gap))
                .floor()
                .clamp(1, maxColumns);
        final itemWidth =
            (constraints.maxWidth - (gap * (columnCount - 1))) / columnCount;

        return Wrap(
          spacing: gap,
          runSpacing: runGap,
          children: fields.map((field) {
            return SizedBox(
              width: field.wide ? constraints.maxWidth : itemWidth,
              child: AppInfoItem(label: field.label, value: field.value),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Single label/value pair as used inside an [AppInfoGrid].
class AppInfoItem extends StatelessWidget {
  const AppInfoItem({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.trim() == '-';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: kTextTertiary,
            letterSpacing: 0.2,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: isEmpty ? kTextMuted : kTextPrimary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
