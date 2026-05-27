import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Square 40×40 back-button used in detail screen headers.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, required this.onTap, this.tooltip = 'Terug'});

  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
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
            child: const Icon(Icons.arrow_back_rounded,
                color: kTextPrimary, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Inline back-link with chevron, suitable above breadcrumbs in embedded
/// modules.
class AppBackLink extends StatelessWidget {
  const AppBackLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back_rounded,
                color: kBrandGreenDark, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: kBrandGreenDark,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
