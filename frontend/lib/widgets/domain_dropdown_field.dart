import 'package:flutter/material.dart';

import '../services/domain_service.dart';

class DomainDropdownField extends StatelessWidget {
  static const String addDomainValue = '__add_domain__';

  final String? label;
  final String value;
  final List<String> domains;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onDomainAdded;

  const DomainDropdownField({
    super.key,
    this.label,
    required this.value,
    required this.domains,
    required this.onChanged,
    this.onDomainAdded,
  });

  Future<void> _handleAddDomain(BuildContext context) async {
    final controller = TextEditingController();
    final newDomain = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nieuw domein toevoegen'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Domeinnaam',
              hintText: 'Bijvoorbeeld: Brandveiligheid',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuleren'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Toevoegen'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    final normalized = newDomain?.trim();
    if (normalized == null || normalized.isEmpty) return;

    await DomainService.addDomain(normalized);
    onDomainAdded?.call(normalized);
    onChanged(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final optionsRaw = domains
        .where((domain) => domain.trim().isNotEmpty)
        .toList(growable: false);
    // Remove duplicates while preserving order to avoid duplicate DropdownMenuItem values
    final options = <String>[];
    for (final d in optionsRaw) {
      if (!options.contains(d)) options.add(d);
    }
    final selectedValue = options.any((domain) => domain == value)
        ? value
        : (options.isNotEmpty ? options.first : null);

    return DropdownButtonFormField<String>(
      key: ValueKey('${label ?? ''}|$value|${options.join('|')}'),
      initialValue: selectedValue,
      isExpanded: true,
      items: [
        ...options.map(
          (domain) => DropdownMenuItem<String>(
            value: domain,
            child: Text(
              domain,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const DropdownMenuItem<String>(
          value: addDomainValue,
          child: Text(
            'Nieuw domein toevoegen...',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
      onChanged: (selected) async {
        if (selected == null) return;
        if (selected == addDomainValue) {
          await _handleAddDomain(context);
          return;
        }
        onChanged(selected);
      },
      decoration: InputDecoration(
        labelText: (label != null && label!.trim().isNotEmpty) ? label : null,
        isDense: true,
      ),
    );
  }
}