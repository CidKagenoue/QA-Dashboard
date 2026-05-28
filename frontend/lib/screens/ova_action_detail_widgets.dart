part of 'ova_action_detail_screen.dart';

class _ActionStatusMenuButton extends StatelessWidget {
  const _ActionStatusMenuButton({
    required this.isOk,
    required this.isSaving,
    required this.onChanged,
  });

  final bool isOk;
  final bool isSaving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final fg = isOk ? kSuccess : kDanger;
    final bg = isOk ? kSuccessBg : kDangerBg;
    final border = isOk ? kSuccessBorder : kDangerBorder;

    return PopupMenuButton<bool>(
      enabled: !isSaving,
      tooltip: 'Status wijzigen',
      onSelected: onChanged,
      offset: const Offset(0, 48),
      position: PopupMenuPosition.under,
      itemBuilder: (context) => const [
        PopupMenuItem(value: false, child: Text('NOK')),
        PopupMenuItem(value: true, child: Text('OK')),
      ],
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(kRadiusPill),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isOk ? 'Status OK' : 'Status NOK',
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                height: 1,
              ),
            ),
            const SizedBox(width: 8),
            if (isSaving)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            else
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: fg),
          ],
        ),
      ),
    );
  }
}

class _CenteredButtonContent extends StatelessWidget {
  const _CenteredButtonContent({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(height: 1)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isOk});

  final bool isOk;

  @override
  Widget build(BuildContext context) {
    final fg = isOk ? kSuccess : kDanger;
    final bg = isOk ? kSuccessBg : kDangerBg;
    final border = isOk ? kSuccessBorder : kDangerBorder;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: border),
      ),
      child: Text(
        isOk ? 'OK' : 'NOK',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Terug naar acties',
      child: Material(
        color: kSurfaceMuted,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadiusMd),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kRadiusMd),
              border: Border.all(color: kBorder),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.arrow_back_rounded,
              color: kTextPrimary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.segments});
  final List<String> segments;

  @override
  Widget build(BuildContext context) {
    return AppBreadcrumb(segments: segments);
  }
}

class _ActionMetric extends StatelessWidget {
  const _ActionMetric({required this.data});

  final _ActionMetricData data;

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
                  fontSize: 14.5,
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
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
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

class _ActionMetricData {
  const _ActionMetricData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: kBrandGreenSubtle,
                  borderRadius: BorderRadius.circular(kRadiusSm),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: kBrandGreenDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.fields, this.minItemWidth = 180});

  final List<_InfoField> fields;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 18.0;
        final columnCount =
            ((constraints.maxWidth + gap) / (minItemWidth + gap)).floor().clamp(
              1,
              3,
            );
        final itemWidth =
            (constraints.maxWidth - (gap * (columnCount - 1))) / columnCount;

        return Wrap(
          spacing: gap,
          runSpacing: 16,
          children: fields.map((field) {
            return SizedBox(
              width: field.wide ? constraints.maxWidth : itemWidth,
              child: _InfoItem(label: field.label, value: field.value),
            );
          }).toList(),
        );
      },
    );
  }
}

class _InfoField {
  const _InfoField({
    required this.label,
    required this.value,
    this.wide = false,
  });

  final String label;
  final String value;
  final bool wide;
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.label, required this.value});

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
            fontSize: 15.5,
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
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: isEmpty ? kTextMuted : Colors.black,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kDangerBg,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: kDangerBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: kDanger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: kDanger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Opnieuw')),
        ],
      ),
    );
  }
}
