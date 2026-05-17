import 'package:flutter/material.dart';

import 'manage_values_page.dart';

/// Dropdown field with one button that opens a single management page for add/delete.
class ManageDropdownField extends StatelessWidget {
  final List<String> items;
  final String value;
  final String hint;
  final String title;
  final String addLabel;
  final String addHint;
  final ValueChanged<String> onChanged;
  final Future<String?> Function(String value) onAddItem;
  final Future<bool> Function(String value) onDeleteItem;
  final ValueChanged<List<String>> onItemsChanged;
  final String noneLabel;

  const ManageDropdownField({
    Key? key,
    required this.items,
    required this.value,
    required this.hint,
    required this.title,
    required this.addLabel,
    required this.addHint,
    required this.onChanged,
    required this.onAddItem,
    required this.onDeleteItem,
    required this.onItemsChanged,
    this.noneLabel = '(geen)',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayValue = value.isEmpty ? '' : value;
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: displayValue,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDDE3D2))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: ['', ...items].map((e) => DropdownMenuItem(value: e, child: Text(e.isEmpty ? noneLabel : e))).toList(),
            onChanged: (v) => onChanged((v ?? '').trim()),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 40,
          width: 40,
          child: IconButton(
            icon: Image.asset(
              'assets/images/jap_gpp_manage_icon.png',
              width: 18,
              height: 18,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.format_list_bulleted, size: 18),
            ),
            tooltip: 'Beheer lijst',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              final result = await showDialog<ManageValuesResult>(
                context: context,
                barrierDismissible: true,
                barrierColor: Colors.black.withOpacity(0.28),
                builder: (_) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: ManageValuesPage(
                    title: title,
                    items: items,
                    selectedValue: value,
                    addLabel: addLabel,
                    addHint: addHint,
                    onAddItem: onAddItem,
                    onDeleteItem: onDeleteItem,
                  ),
                ),
              );

              if (result == null) return;
              onItemsChanged(result.items);
              onChanged(result.selectedValue ?? (result.items.isNotEmpty ? result.items.first : ''));
            },
          ),
        ),
      ],
    );
  }
}
