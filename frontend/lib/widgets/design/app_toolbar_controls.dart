import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class AppToolbarSearchField extends StatelessWidget {
  const AppToolbarSearchField({
    super.key,
    required this.hintText,
    this.controller,
    this.onChanged,
    this.width = 340,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: kTextPrimary,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: kTextMuted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: kTextTertiary,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 46,
          ),
          filled: true,
          fillColor: kSurfaceMuted,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kRadiusMd),
            borderSide: const BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kRadiusMd),
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kRadiusMd),
            borderSide: const BorderSide(color: kBrandGreen, width: 1.4),
          ),
        ),
      ),
    );
  }
}

class AppToolbarFilterButton extends StatelessWidget {
  const AppToolbarFilterButton({
    super.key,
    required this.onPressed,
    this.active = false,
    this.expanded = false,
    this.activeCount = 0,
    this.label = 'Filters',
  });

  final VoidCallback? onPressed;
  final bool active;
  final bool expanded;
  final int activeCount;
  final String label;

  @override
  Widget build(BuildContext context) {
    final highlighted = active || expanded || activeCount > 0;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.filter_alt_rounded, size: 18),
      label: Text(activeCount > 0 ? '$label $activeCount' : label),
      style: OutlinedButton.styleFrom(
        foregroundColor: highlighted ? kBrandGreenDeep : kTextSecondary,
        backgroundColor: expanded ? kBrandGreenSubtle : kSurface,
        side: BorderSide(color: highlighted ? kBrandGreenSoft : kBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class AppToolbarPrimaryButton extends StatelessWidget {
  const AppToolbarPrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon = Icons.add_rounded,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusPill),
        ),
      ),
    );
  }
}
