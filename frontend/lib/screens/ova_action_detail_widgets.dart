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
    final foreground = isOk ? const Color(0xFF5F8424) : const Color(0xFFC43C33);
    final background = isOk ? const Color(0xFFEAF4D9) : const Color(0xFFFFECEB);
    final border = isOk ? const Color(0xFF98C74D) : const Color(0xFFE8A09C);

    return PopupMenuButton<bool>(
      enabled: !isSaving,
      tooltip: 'Status wijzigen',
      onSelected: onChanged,
      itemBuilder: (context) => const [
        PopupMenuItem(value: false, child: Text('NOK')),
        PopupMenuItem(value: true, child: Text('OK')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isOk ? 'Status OK' : 'Status NOK',
              style: TextStyle(
                color: foreground,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            if (isSaving)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            else
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: foreground,
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.foregroundColor,
    required this.borderColor,
    required this.backgroundColor,
    this.isLoading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color foregroundColor;
  final Color borderColor;
  final Color backgroundColor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: IconButton(
          onPressed: isLoading ? null : onPressed,
          icon: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foregroundColor,
                  ),
                )
              : Icon(icon, size: 20),
          color: foregroundColor,
          disabledColor: foregroundColor.withValues(alpha: 0.45),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _ActionMetric extends StatelessWidget {
  const _ActionMetric({required this.data});

  final _ActionMetricData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF4D9),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(data.icon, size: 18, color: const Color(0xFF5F8424)),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6F7A68),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF243022),
                  height: 1.1,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E9DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF6B7A62)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2B3424),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
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
        const gap = 16.0;
        final columnCount =
            ((constraints.maxWidth + gap) / (minItemWidth + gap)).floor().clamp(
              1,
              3,
            );
        final itemWidth =
            (constraints.maxWidth - (gap * (columnCount - 1))) / columnCount;

        return Wrap(
          spacing: gap,
          runSpacing: 14,
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
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6F7A68),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: isEmpty ? const Color(0xFF6F7A68) : const Color(0xFF243022),
            height: 1.35,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1C9C9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Colors.redAccent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFC43C33),
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
