import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Bordered surface panel with a small icon chip + title + optional trailing
/// widget. Used to group fields inside a detail screen.
class AppSectionPanel extends StatelessWidget {
  const AppSectionPanel({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(20),
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
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
