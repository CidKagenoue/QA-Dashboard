import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ManageValuesResult {
  final List<String> items;
  final String? selectedValue;

  const ManageValuesResult({
    required this.items,
    required this.selectedValue,
  });
}

class ManageValuesPage extends StatefulWidget {
  final String title;
  final List<String> items;
  final String selectedValue;
  final String addLabel;
  final String addHint;
  final Future<String?> Function(String value) onAddItem;
  final Future<bool> Function(String value) onDeleteItem;

  const ManageValuesPage({
    super.key,
    required this.title,
    required this.items,
    required this.selectedValue,
    required this.addLabel,
    required this.addHint,
    required this.onAddItem,
    required this.onDeleteItem,
  });

  @override
  State<ManageValuesPage> createState() => _ManageValuesPageState();
}

class _ManageValuesPageState extends State<ManageValuesPage> {
  late final TextEditingController _controller;
  late List<String> _items;
  String _selectedValue = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _items = _normalizeItems(widget.items);
    _selectedValue = widget.selectedValue.trim();
    if (_selectedValue.isNotEmpty && !_items.contains(_selectedValue)) {
      _items.add(_selectedValue);
      _items.sort();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> _normalizeItems(List<String> input) {
    final result = <String>[];
    for (final item in input) {
      final value = item.trim();
      if (value.isEmpty) continue;
      if (!result.contains(value)) {
        result.add(value);
      }
    }
    result.sort();
    return result;
  }

  void _close() {
    Navigator.of(context).pop(
      ManageValuesResult(
        items: List<String>.from(_items),
        selectedValue: _selectedValue.isEmpty ? null : _selectedValue,
      ),
    );
  }

  Future<void> _addItem() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty || _busy) return;

    setState(() => _busy = true);
    try {
      final created = await widget.onAddItem(raw);
      if (!mounted) return;
      if (created == null || created.trim().isEmpty) return;

      final value = created.trim();
      setState(() {
        if (!_items.contains(value)) {
          _items.add(value);
          _items.sort();
        }
        _selectedValue = value;
        _controller.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$value" toegevoegd.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Toevoegen mislukt: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteItem(String item) async {
    if (_busy) return;
    if (item == _selectedValue) return;

    setState(() => _busy = true);
    try {
      final deleted = await widget.onDeleteItem(item);
      if (!mounted) return;
      if (!deleted) return;

      setState(() {
        _items.remove(item);
        if (_selectedValue == item) {
          _selectedValue = _items.isNotEmpty ? _items.first : '';
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$item" verwijderd.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verwijderen mislukt: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: const Color(0xFF243022),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Voeg iets toe of verwijder een item in één compact scherm.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF4D5548),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : _close,
                    icon: const Icon(Icons.close),
                    tooltip: 'Sluiten',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _busy ? null : _addItem(),
                      decoration: InputDecoration(
                        labelText: widget.addLabel,
                        hintText: widget.addHint,
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD7DBD2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: kAppGreen,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _addItem,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Toevoegen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAppGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: _items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Nog geen items in deze lijst.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF6B7A62),
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final isSelected = item == _selectedValue;
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 0,
                            ),
                            leading: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.label_outline,
                              color: isSelected
                                  ? kAppGreen
                                  : const Color(0xFF6B7A62),
                            ),
                            title: Text(
                              item,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: const Color(0xFF2B3424),
                              ),
                            ),
                            subtitle: isSelected
                                ? const Text(
                                    'Geselecteerd',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7A62),
                                    ),
                                  )
                                : null,
                            trailing: IconButton(
                              tooltip: isSelected
                                  ? 'Geselecteerd'
                                  : 'Verwijderen',
                              icon: Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: isSelected
                                    ? Colors.grey.shade300
                                    : const Color(0xFFC43C33),
                              ),
                              onPressed: isSelected || _busy
                                  ? null
                                  : () => _deleteItem(item),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : _close,
                  child: const Text('Opslaan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
