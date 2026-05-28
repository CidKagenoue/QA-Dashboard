import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class AppInlineFilterPanel extends StatelessWidget {
  const AppInlineFilterPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kSurfaceMuted,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kBorder),
      ),
      child: child,
    );
  }
}

class AppInlineFilterSelectField<T> extends StatelessWidget {
  const AppInlineFilterSelectField({
    super.key,
    required this.width,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hintText,
  });

  final double width;
  final String label;
  final T? value;
  final List<AppInlineFilterOption<T>> options;
  final ValueChanged<T?> onChanged;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T?>(
        key: ValueKey<Object?>(value),
        initialValue: value,
        isExpanded: true,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: kTextTertiary,
        ),
        style: const TextStyle(
          fontSize: 14,
          color: kTextPrimary,
          fontWeight: FontWeight.w500,
        ),
        hint: hintText == null ? null : Text(hintText!),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: kSurface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
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
        items: options
            .map(
              (option) => DropdownMenuItem<T?>(
                value: option.value,
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class AppInlineFilterOption<T> {
  const AppInlineFilterOption({required this.value, required this.label});

  final T? value;
  final String label;
}

class AppInlineFilterClearButton extends StatelessWidget {
  const AppInlineFilterClearButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.refresh_rounded, size: 16),
      label: const Text('Filters wissen'),
    );
  }
}

class AppActiveFilterChip extends StatelessWidget {
  const AppActiveFilterChip({
    super.key,
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: kBrandGreenSoft,
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: const Color(0xFFCFE5A8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: kBrandGreenDeep,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(kRadiusPill),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: kBrandGreenDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
