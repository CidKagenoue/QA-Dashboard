import 'package:flutter/material.dart';
import '../models/jap_gpp_entry.dart';
import '../services/jap_gpp_api_service.dart';

class JapGppDetailPane extends StatefulWidget {
  final String token;
  final JapEntry? japEntry;
  final GppEntry? gppEntry;
  final VoidCallback onChanged;
  final VoidCallback onClose;

  const JapGppDetailPane._({
    required this.token,
    required this.japEntry,
    required this.gppEntry,
    required this.onChanged,
    required this.onClose,
  });

  factory JapGppDetailPane.jap({
    required String token,
    required JapEntry entry,
    required VoidCallback onChanged,
    required VoidCallback onClose,
  }) {
    return JapGppDetailPane._(
      token: token,
      japEntry: entry,
      gppEntry: null,
      onChanged: onChanged,
      onClose: onClose,
    );
  }

  factory JapGppDetailPane.gpp({
    required String token,
    required GppEntry entry,
    required VoidCallback onChanged,
    required VoidCallback onClose,
  }) {
    return JapGppDetailPane._(
      token: token,
      japEntry: null,
      gppEntry: entry,
      onChanged: onChanged,
      onClose: onClose,
    );
  }

  @override
  State<JapGppDetailPane> createState() => _JapGppDetailPaneState();
}

class _JapGppDetailPaneState extends State<JapGppDetailPane> {
  late final TextEditingController _goalController;
  late final TextEditingController _riskController;
  late final TextEditingController _executorController;
  late final TextEditingController _budgetController;
  late final TextEditingController _remarkController;

  late String _priority;
  late String _realisation;
  late String _selectedDomain;
  late List<String> _availableDomains;
  bool _editing = false;
  bool _saving = false;
  bool _loadingDomains = true;
  late DateTime? _editStartDate;
  late DateTime? _editEndDate;

  bool get _isJap => widget.japEntry != null;

  JapEntry get _jap => widget.japEntry!;
  GppEntry get _gpp => widget.gppEntry!;

  @override
  void initState() {
    super.initState();
    final initialGoal = _isJap ? _jap.goalMeasure : _gpp.goalMeasure;
    final initialDomain = _isJap ? _jap.domain : _gpp.domain;
    final initialRisk = _isJap ? _jap.riskField : _gpp.riskField;
    final initialExecutor = _isJap ? _jap.executor : _gpp.executor;
    final initialBudget = _isJap ? _jap.resourcesBudget : _gpp.resourcesBudget;
    final initialRemark = _isJap ? _jap.remark : _gpp.remark;

    _goalController = TextEditingController(text: initialGoal);
    _riskController = TextEditingController(text: initialRisk);
    _executorController = TextEditingController(text: initialExecutor);
    _budgetController = TextEditingController(text: initialBudget);
    _remarkController = TextEditingController(text: initialRemark);
    _priority = _isJap ? _jap.priority.name : _gpp.priority;
    _realisation = _isJap ? _jap.realisation.name : _gpp.realisation;
    _selectedDomain = initialDomain;
    _editStartDate = _isJap ? _jap.startDate : _gpp.startDate;
    _editEndDate = _isJap ? _jap.endDate : _gpp.endDate;
    
    _loadDomains();
  }

  Future<void> _loadDomains() async {
    try {
      final domains = await JapApiService.fetchDomains(token: widget.token);
      if (!mounted) return;
      setState(() {
        _availableDomains = domains;
        _loadingDomains = false;
        // Ensure selected domain is in list
        if (!_availableDomains.contains(_selectedDomain)) {
          _availableDomains.add(_selectedDomain);
          _availableDomains.sort();
        }
      });
    } catch (e) {
      if (!mounted) return;
      // Fallback to default domains if loading fails
      setState(() {
        _availableDomains = {
          'Arbeidsveiligheid',
          'Gezondheid',
          'Milieu',
          'Kwaliteit',
          'Veiligheid',
          _selectedDomain,
        }.toList()..sort();
        _loadingDomains = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Domeinen laden mislukt: $e')),
      );
    }
  }

  @override
  void dispose() {
    _goalController.dispose();
    _riskController.dispose();
    _executorController.dispose();
    _budgetController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_isJap) {
        final year = _jap.year;
        await JapApiService.updateJapEntry(
          token: widget.token,
          id: _jap.id,
          payload: {
            'doelstellingMaatregel': _goalController.text.trim(),
            'domein': _selectedDomain,
            'risicoveld': _riskController.text.trim(),
            'jaar': year,
            'prioriteit': _priority,
            'realisatie': _realisation,
            'uitvoerder': _executorController.text.trim(),
            'middelenBudgetWerkuren': _budgetController.text.trim(),
            'startdatum': _editStartDate != null ? _editStartDate!.toIso8601String().split('T')[0] : '$year.01.01',
            'einddatum': _editEndDate != null ? _editEndDate!.toIso8601String().split('T')[0] : '$year.12.31',
            'opmerking': _remarkController.text.trim(),
          },
        );
      } else {
        final startYear = _editStartDate?.year ?? _gpp.startYear;
        final endYear = _editEndDate?.year ?? _gpp.endYear;
        await JapApiService.updateGppEntry(
          token: widget.token,
          id: _gpp.id,
          payload: {
            'doelstellingMaatregel': _goalController.text.trim(),
            'domein': _selectedDomain,
            'risicoveld': _riskController.text.trim(),
            'startJaar': startYear,
            'eindJaar': endYear,
            'prioriteit': _priority,
            'realisatie': _realisation,
            'uitvoerder': _executorController.text.trim(),
            'middelenBudgetWerkuren': _budgetController.text.trim(),
            'startdatum': _editStartDate != null ? _editStartDate!.toIso8601String().split('T')[0] : '$startYear.01.01',
            'einddatum': _editEndDate != null ? _editEndDate!.toIso8601String().split('T')[0] : '$endYear.12.31',
            'opmerking': _remarkController.text.trim(),
          },
        );
      }

      if (!mounted) return;
      setState(() => _editing = false);
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opgeslagen.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opslaan mislukt: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Verwijderen?'),
          content: const Text('Weet je zeker dat je dit item wilt verwijderen?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuleren'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Verwijderen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      if (_isJap) {
        await JapApiService.deleteJapEntry(token: widget.token, id: _jap.id);
      } else {
        await JapApiService.deleteGppEntry(token: widget.token, id: _gpp.id);
      }

      if (!mounted) return;
      widget.onClose();
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item verwijderd.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verwijderen mislukt: $e')),
      );
    }
  }

  Widget _buildReadOnlyBox(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDE3D2)),
      ),
      child: Text(value.isEmpty ? '-' : value),
    );
  }

  Widget _buildTextField(TextEditingController controller, {int maxLines = 1}) {
    if (!_editing) {
      return _buildReadOnlyBox(controller.text.trim());
    }

    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDE3D2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF8BC34A)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildDropdown({required String value, required List<DropdownMenuItem<String>> items, required ValueChanged<String?> onChanged}) {
    if (!_editing) {
      return _buildReadOnlyBox(value);
    }

    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDE3D2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF8BC34A)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildDomainDropdown() {
    if (!_editing) {
      return _buildReadOnlyBox(_selectedDomain);
    }

    if (_loadingDomains) {
      return const Center(child: CircularProgressIndicator());
    }

    // Ensure available domains are unique (preserve order) and determine a safe initial value
    final uniqueDomains = <String>[];
    for (final d in _availableDomains) {
      if (d.trim().isEmpty) continue;
      if (!uniqueDomains.contains(d)) uniqueDomains.add(d);
    }
    final safeInitialDomain = uniqueDomains.contains(_selectedDomain) ? _selectedDomain : null;

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: safeInitialDomain,
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFDDE3D2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF8BC34A)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: uniqueDomains.map((domain) {
              return DropdownMenuItem(
                value: domain,
                child: Text(domain),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selectedDomain = value);
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 40,
          width: 40,
          child: IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: _showAddDomainDialog,
            tooltip: 'Nieuw domein toevoegen',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF8BC34A).withValues(alpha: 0.1),
              foregroundColor: const Color(0xFF8BC34A),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (_availableDomains.length > 1)
          SizedBox(
            height: 40,
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: _showRemoveDomainDialog,
              tooltip: 'Domein verwijderen',
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.1),
                foregroundColor: Colors.red,
              ),
            ),
          ),
      ],
    );
  }

  void _showAddDomainDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nieuw domein toevoegen'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Voer domeinnaam in',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuleren'),
            ),
            ElevatedButton(
              onPressed: () async {
                final domain = controller.text.trim();
                if (domain.isNotEmpty && !_availableDomains.contains(domain)) {
                  try {
                    await JapApiService.createDomain(
                      token: widget.token,
                      name: domain,
                    );
                    if (!mounted) return;
                    setState(() {
                      _availableDomains.add(domain);
                      _availableDomains.sort();
                      _selectedDomain = domain;
                    });
                    if (mounted) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Domein "$domain" toegevoegd.')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Domein toevoegen mislukt: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('Toevoegen'),
            ),
          ],
        );
      },
    );
  }

  void _showRemoveDomainDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Domein verwijderen'),
          content: const Text('Welk domein wil je verwijderen?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuleren'),
            ),
            SizedBox(
              height: 200,
              width: double.maxFinite,
              child: ListView.builder(
                itemCount: _availableDomains.length,
                itemBuilder: (context, index) {
                  final domain = _availableDomains[index];
                  return ListTile(
                    title: Text(domain),
                    trailing: domain == _selectedDomain
                        ? const Tooltip(
                            message: 'Dit domein is geselecteerd',
                            child: Icon(Icons.info, size: 18, color: Colors.orange),
                          )
                        : IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            onPressed: () async {
                              try {
                                await JapApiService.deleteDomain(
                                  token: widget.token,
                                  domainName: domain,
                                );
                                if (!mounted) return;
                                setState(() => _availableDomains.remove(domain));
                                if (mounted) {
                                  Navigator.pop(dialogContext);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Domein "$domain" verwijderd.')),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Domein verwijderen mislukt: $e')),
                                  );
                                }
                              }
                            },
                          ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final idText = _isJap ? _jap.id.toString().padLeft(4, '0') : _gpp.id.toString().padLeft(4, '0');
    final periodText = _isJap ? 'Jaar ${_jap.year}' : '${_gpp.startYear} - ${_gpp.endYear}';

    return Container(
      color: const Color(0xFFF6F6F3),
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard > JAP & GPP',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF9CA39A),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF243022)),
                    tooltip: 'Terug',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        _editing
                            ? ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 88, maxHeight: 360),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                                  child: TextField(
                                    controller: _goalController,
                                    minLines: 2,
                                    maxLines: 8,
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF243022),
                                          height: 1.05,
                                        ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                      border: InputBorder.none,
                                      hintText: 'Detail',
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              )
                            : Text(
                                _goalController.text.trim().isEmpty ? 'Detail' : _goalController.text.trim(),
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF243022),
                                      height: 1.1,
                                    ),
                              ),
                        const SizedBox(height: 4),
                        Text(
                          '$periodText • ID $idText',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7A62),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      if (_editing)
                        TextButton(
                          onPressed: _saving ? null : () => setState(() => _editing = false),
                          child: const Text('Annuleren'),
                        ),
                      TextButton.icon(
                        onPressed: _saving ? null : _delete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Verwijderen'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFD32F2F),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : (_editing ? _save : () => setState(() => _editing = true)),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(_editing ? Icons.save_outlined : Icons.edit_outlined, size: 18),
                        label: Text(_editing ? 'Opslaan' : 'Bewerken'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8BC34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBFCF8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE4E9DD)),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 980;
                        final fieldWidth = wide ? (constraints.maxWidth - 32) / 2 : constraints.maxWidth;

                        Widget field(String label, Widget child, {double? width}) {
                          return SizedBox(
                            width: width ?? fieldWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6B7A62),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                child,
                              ],
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              // Goal is edited in the header; remove duplicate body field
                              const SizedBox(height: 6),
                              const SizedBox(height: 10),
                            _Pill(
                              label: _getRealisationLabel(_realisation),
                              background: _getRealisationColor(_realisation).withValues(alpha: 0.12),
                              foreground: _getRealisationColor(_realisation),
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: Color(0xFFE4E9DD), height: 1),
                            const SizedBox(height: 12),
                            if (_isJap)
                              field('Jaar', _buildReadOnlyBox(_jap.year.toString()), width: constraints.maxWidth)
                            else
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  field(
                                    'Startdatum',
                                    _editing
                                        ? GestureDetector(
                                            onTap: () async {
                                              final picked = await showDatePicker(
                                                context: context,
                                                initialDate: _editStartDate ?? DateTime(_gpp.startYear, 1, 1),
                                                firstDate: DateTime(1900),
                                                lastDate: DateTime(2100),
                                              );
                                              if (picked != null) setState(() => _editStartDate = picked);
                                            },
                                            child: Container(
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: const Color(0xFFDDE3D2)),
                                              ),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                              alignment: Alignment.centerLeft,
                                              child: Text(_editStartDate != null ? _editStartDate!.toIso8601String().split('T')[0] : _gpp.startYear.toString()),
                                            ),
                                          )
                                        : _buildReadOnlyBox(_gpp.startDate != null ? _gpp.startDate!.toIso8601String().split('T')[0] : _gpp.startYear.toString()),
                                  ),
                                  field(
                                    'Einddatum',
                                    _editing
                                        ? GestureDetector(
                                            onTap: () async {
                                              final picked = await showDatePicker(
                                                context: context,
                                                initialDate: _editEndDate ?? DateTime(_gpp.endYear, 12, 31),
                                                firstDate: DateTime(1900),
                                                lastDate: DateTime(2100),
                                              );
                                              if (picked != null) setState(() => _editEndDate = picked);
                                            },
                                            child: Container(
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: const Color(0xFFDDE3D2)),
                                              ),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                              alignment: Alignment.centerLeft,
                                              child: Text(_editEndDate != null ? _editEndDate!.toIso8601String().split('T')[0] : _gpp.endYear.toString()),
                                            ),
                                          )
                                        : _buildReadOnlyBox(_gpp.endDate != null ? _gpp.endDate!.toIso8601String().split('T')[0] : _gpp.endYear.toString()),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                field('Domein', _buildDomainDropdown()),
                                field('Risicoveld', _buildTextField(_riskController)),
                                field('Uitvoerder', _buildTextField(_executorController)),
                                field('Middelen / Budget / Werkuren', _buildTextField(_budgetController)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                field(
                                  'Prioriteit',
                                  _buildDropdown(
                                    value: _priority,
                                    items: const [
                                      DropdownMenuItem(value: 'hoog', child: Text('Hoge prioriteit')),
                                      DropdownMenuItem(value: 'middel', child: Text('Middelhoge prioriteit')),
                                      DropdownMenuItem(value: 'laag', child: Text('Lage prioriteit')),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) setState(() => _priority = value);
                                    },
                                  ),
                                ),
                                field(
                                  'Realisatie',
                                  _buildDropdown(
                                    value: _realisation,
                                    items: const [
                                      DropdownMenuItem(value: 'in_uitvoering', child: Text('In uitvoering')),
                                      DropdownMenuItem(value: 'uitgevoerd', child: Text('Uitgevoerd')),
                                      DropdownMenuItem(value: 'neg_niet_uitgevoerd', child: Text('Nog niet uitgevoerd')),
                                      DropdownMenuItem(value: 'vul_aan', child: Text('Vul aan')),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) setState(() => _realisation = value);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            field('Opmerking', _buildTextField(_remarkController, maxLines: 4), width: constraints.maxWidth),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRealisationLabel(String realisation) {
    switch (realisation.toLowerCase()) {
      case 'in_uitvoering':
        return 'In uitvoering';
      case 'uitgevoerd':
        return 'Uitgevoerd';
      case 'neg_niet_uitgevoerd':
        return 'Nog niet';
      case 'vul_aan':
        return 'Vul aan';
      default:
        return realisation;
    }
  }

  Color _getRealisationColor(String realisation) {
    switch (realisation.toLowerCase()) {
      case 'in_uitvoering':
        return Colors.orange;
      case 'uitgevoerd':
        return const Color(0xFF4A7A1E);
      case 'neg_niet_uitgevoerd':
        return Colors.red;
      case 'vul_aan':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}
