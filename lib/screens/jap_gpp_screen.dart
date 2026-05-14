import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/jap_gpp_entry.dart';
import '../services/jap_export_service.dart';
import '../services/jap_gpp_api_service.dart';
import 'jap_gpp_detail_pane.dart';

class JapGppScreen extends StatefulWidget {
  final String token;
  final String? initialModule;
  final int? initialEntryId;
  final VoidCallback? onInitialContextConsumed;

  const JapGppScreen({
    super.key,
    required this.token,
    this.initialModule,
    this.initialEntryId,
    this.onInitialContextConsumed,
  });

  @override
  State<JapGppScreen> createState() => _JapGppScreenState();
}

class _JapGppScreenState extends State<JapGppScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<JapEntry> _japEntries = [];
  List<GppEntry> _gppEntries = [];
  bool _loading = true;
  bool _savingImport = false;
  String? _error;

  JapEntry? _selectedJap;
  GppEntry? _selectedGpp;
  bool _initialContextConsumed = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _reloadAll();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _reloadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<List<dynamic>>([
        JapApiService.fetchJapEntries(token: widget.token),
        JapApiService.fetchGppEntries(token: widget.token),
      ]);

      final japEntries = List<JapEntry>.from(results[0] as List<JapEntry>);
      final gppEntries = List<GppEntry>.from(results[1] as List<GppEntry>);

      japEntries.sort((a, b) => b.year.compareTo(a.year));
      gppEntries.sort((a, b) {
        final endCompare = b.endYear.compareTo(a.endYear);
        if (endCompare != 0) return endCompare;
        return b.startYear.compareTo(a.startYear);
      });

      if (!mounted) return;
      setState(() {
        _japEntries = japEntries;
        _gppEntries = gppEntries;
        _loading = false;
      });

      _applyInitialContext();
      _consumeInitialContextIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _consumeInitialContextIfNeeded() {
    if (_initialContextConsumed) return;
    if (widget.initialModule == null && widget.initialEntryId == null) return;
    _initialContextConsumed = true;
    widget.onInitialContextConsumed?.call();
  }

  void _applyInitialContext() {
    if (_initialContextConsumed) return;

    final module = (widget.initialModule ?? '').trim().toUpperCase();
    final id = widget.initialEntryId;
    if (module.isEmpty && id == null) return;

    if (module == 'GPP') {
      final match = id == null
          ? (_gppEntries.isNotEmpty ? _gppEntries.first : null)
          : _gppEntries.where((entry) => entry.id == id).cast<GppEntry?>().firstWhere((entry) => entry != null, orElse: () => null);
      if (match != null) {
        _selectGpp(match);
      }
      return;
    }

    if (module == 'JAP') {
      final match = id == null
          ? (_japEntries.isNotEmpty ? _japEntries.first : null)
          : _japEntries.where((entry) => entry.id == id).cast<JapEntry?>().firstWhere((entry) => entry != null, orElse: () => null);
      if (match != null) {
        _selectJap(match);
      }
      return;
    }

    if (_japEntries.isNotEmpty) {
      _selectJap(_japEntries.first);
    } else if (_gppEntries.isNotEmpty) {
      _selectGpp(_gppEntries.first);
    }
  }

  void _selectJap(JapEntry entry) {
    setState(() {
      _selectedJap = entry;
      _selectedGpp = null;
    });
  }

  void _selectGpp(GppEntry entry) {
    setState(() {
      _selectedGpp = entry;
      _selectedJap = null;
    });
  }

  List<JapEntry> _filteredJapEntries() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _japEntries;
    return _japEntries.where((entry) {
      return entry.goalMeasure.toLowerCase().contains(query) ||
          entry.domain.toLowerCase().contains(query) ||
          entry.executor.toLowerCase().contains(query) ||
          entry.remark.toLowerCase().contains(query) ||
          entry.year.toString().contains(query);
    }).toList();
  }

  List<GppEntry> _filteredGppEntries() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _gppEntries;
    return _gppEntries.where((entry) {
      return entry.goalMeasure.toLowerCase().contains(query) ||
          entry.domain.toLowerCase().contains(query) ||
          entry.executor.toLowerCase().contains(query) ||
          entry.remark.toLowerCase().contains(query) ||
          entry.yearLabel.toLowerCase().contains(query);
    }).toList();
  }

  List<int> _availableYears() {
    final years = <int>{};
    for (final entry in _japEntries) {
      years.add(entry.year);
    }
    for (final entry in _gppEntries) {
      for (var year = entry.startYear; year <= entry.endYear; year++) {
        years.add(year);
      }
    }
    return years.toList()..sort((a, b) => b.compareTo(a));
  }

  List<JapEntry> _entriesForExportYear(int year) {
    return [
      ..._japEntries.where((entry) => entry.year == year),
      ..._gppEntries
          .where((entry) => entry.startYear <= year && year <= entry.endYear)
          .map(
            (entry) => JapEntry(
              id: -entry.id,
              year: year,
              goalMeasure: entry.goalMeasure,
              domain: entry.domain,
              riskField: entry.riskField,
              resourcesBudget: entry.resourcesBudget,
              priority: _gppPriorityToJapPriority(entry.priority),
              realisation: _gppRealisationToJapRealisation(entry.realisation),
              executor: entry.executor,
              startDate: entry.startDate,
              endDate: entry.endDate,
              remark: entry.remark,
            ),
          ),
    ];
  }

  JapPriority _gppPriorityToJapPriority(String value) {
    switch (value.toLowerCase()) {
      case 'hoog':
      case 'high':
        return JapPriority.high;
      case 'middel':
      case 'middelmatig':
      case 'medium':
        return JapPriority.medium;
      default:
        return JapPriority.low;
    }
  }

  JapRealisation _gppRealisationToJapRealisation(String value) {
    final normalised = value.toLowerCase().replaceAll(' ', '_');
    switch (normalised) {
      case 'in_uitvoering':
      case 'inuitvoering':
      case 'in_progress':
        return JapRealisation.inProgress;
      case 'uitgevoerd':
      case 'completed':
        return JapRealisation.completed;
      case 'nog_niet_uitgevoerd':
      case 'neg_niet_uitgevoerd':
        return JapRealisation.notYetCompleted;
      default:
        return JapRealisation.fillIn;
    }
  }

  Future<void> _exportByYear() async {
    final years = _availableYears();
    if (years.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geen jaren beschikbaar voor export.')),
      );
      return;
    }

    final selectedYear = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F2EA),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kies jaar voor export',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Selecteer het jaar dat je wil exporteren naar PDF.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: years
                          .map(
                            (year) => ChoiceChip(
                              label: Text(year.toString()),
                              selected: false,
                              onSelected: (_) => Navigator.pop(dialogContext, year),
                              backgroundColor: Colors.white,
                              selectedColor: const Color(0xFF8BC34A).withValues(alpha: 0.18),
                              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Annuleren'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (selectedYear == null) return;
    final entries = _entriesForExportYear(selectedYear);
    if (entries.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geen items voor dit jaar.')),
      );
      return;
    }

    final savedPath = await JapExportService.exportJapForYear(selectedYear, entries);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          savedPath != null ? 'PDF opgeslagen: $savedPath' : 'PDF-export gestart voor $selectedYear',
        ),
      ),
    );
  }

  Future<void> _importGppExcel() async {
    if (_savingImport) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kon het bestand niet lezen.')),
      );
      return;
    }

    setState(() => _savingImport = true);
    try {
      final response = await JapApiService.importGppExcel(
        token: widget.token,
        fileName: file.name,
        bytes: bytes,
      );

      await _reloadAll();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message']?.toString() ?? 'GPP import gelukt')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPP import mislukt: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingImport = false);
      }
    }
  }

  Future<void> _showCreateGppDialog() async {
    final goalController = TextEditingController();
    final riskController = TextEditingController(text: 'Algemeen');
    final executorController = TextEditingController();
    final budgetController = TextEditingController();
    final remarkController = TextEditingController();
    final startYearController = TextEditingController(text: DateTime.now().year.toString());
    final endYearController = TextEditingController(text: (DateTime.now().year + 3).toString());
    String priority = 'laag';
    String realisation = 'in_uitvoering';
    String selectedDomain = 'Arbeidsveiligheid';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        InputDecoration fieldDecoration(String hint) {
          return InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDDE3D2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDDE3D2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF8BC34A)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          );
        }

        Widget label(String text) {
          return Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7A62),
            ),
          );
        }

        return StatefulBuilder(
          builder: (buildContext, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F2EA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Nieuwe GPP regel aanmaken',
                            style: Theme.of(dialogContext).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Vul de gegevens in om een nieuwe JAP/GPP-lijn toe te voegen.',
                            style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 20),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final twoColumn = constraints.maxWidth > 560;
                              if (twoColumn) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          label('Doelstelling - maatregel *'),
                                          const SizedBox(height: 8),
                                          TextField(controller: goalController, decoration: fieldDecoration('...')),
                                          const SizedBox(height: 16),
                                          label('Domein *'),
                                          const SizedBox(height: 8),
                                          DropdownButtonFormField<String>(
                                            value: selectedDomain,
                                            isExpanded: true,
                                            decoration: fieldDecoration(''),
                                            items: const [
                                              DropdownMenuItem(value: 'Arbeidsveiligheid', child: Text('Arbeidsveiligheid')),
                                              DropdownMenuItem(value: 'Gezondheid', child: Text('Gezondheid')),
                                              DropdownMenuItem(value: 'Milieu', child: Text('Milieu')),
                                              DropdownMenuItem(value: 'Kwaliteit', child: Text('Kwaliteit')),
                                              DropdownMenuItem(value: 'Veiligheid', child: Text('Veiligheid')),
                                            ],
                                            onChanged: (value) {
                                              setDialogState(() => selectedDomain = value ?? 'Arbeidsveiligheid');
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                          label('Risicoveld'),
                                          const SizedBox(height: 8),
                                          TextField(controller: riskController, decoration: fieldDecoration('Algemeen')),
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    label('Startjaar *'),
                                                    const SizedBox(height: 8),
                                                    TextField(
                                                      controller: startYearController,
                                                      keyboardType: TextInputType.number,
                                                      decoration: fieldDecoration('2026'),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    label('Eindjaar *'),
                                                    const SizedBox(height: 8),
                                                    TextField(
                                                      controller: endYearController,
                                                      keyboardType: TextInputType.number,
                                                      decoration: fieldDecoration('2027'),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          label('Uitvoerder'),
                                          const SizedBox(height: 8),
                                          TextField(controller: executorController, decoration: fieldDecoration('...')),
                                          const SizedBox(height: 16),
                                          label('Middelen / Budget / Werkuren'),
                                          const SizedBox(height: 8),
                                          TextField(controller: budgetController, decoration: fieldDecoration('...')),
                                          const SizedBox(height: 16),
                                          label('Prioriteit'),
                                          const SizedBox(height: 8),
                                          DropdownButtonFormField<String>(
                                            initialValue: priority,
                                            isExpanded: true,
                                            decoration: fieldDecoration(''),
                                            items: const [
                                              DropdownMenuItem(value: 'hoog', child: Text('Hoge prioriteit')),
                                              DropdownMenuItem(value: 'middel', child: Text('Middelhoge prioriteit')),
                                              DropdownMenuItem(value: 'laag', child: Text('Lage prioriteit')),
                                            ],
                                            onChanged: (value) => priority = value ?? 'laag',
                                          ),
                                          const SizedBox(height: 16),
                                          label('Realisatie'),
                                          const SizedBox(height: 8),
                                          DropdownButtonFormField<String>(
                                            initialValue: realisation,
                                            isExpanded: true,
                                            decoration: fieldDecoration(''),
                                            items: const [
                                              DropdownMenuItem(value: 'in_uitvoering', child: Text('In uitvoering')),
                                              DropdownMenuItem(value: 'uitgevoerd', child: Text('Uitgevoerd')),
                                              DropdownMenuItem(value: 'neg_niet_uitgevoerd', child: Text('Nog niet uitgevoerd')),
                                              DropdownMenuItem(value: 'vul_aan', child: Text('Vul aan')),
                                            ],
                                            onChanged: (value) => realisation = value ?? 'in_uitvoering',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  label('Doelstelling - maatregel *'),
                                  const SizedBox(height: 8),
                                  TextField(controller: goalController, decoration: fieldDecoration('...')),
                                  const SizedBox(height: 16),
                                  label('Domein *'),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    value: selectedDomain,
                                    isExpanded: true,
                                    decoration: fieldDecoration(''),
                                    items: const [
                                      DropdownMenuItem(value: 'Arbeidsveiligheid', child: Text('Arbeidsveiligheid')),
                                      DropdownMenuItem(value: 'Gezondheid', child: Text('Gezondheid')),
                                      DropdownMenuItem(value: 'Milieu', child: Text('Milieu')),
                                      DropdownMenuItem(value: 'Kwaliteit', child: Text('Kwaliteit')),
                                      DropdownMenuItem(value: 'Veiligheid', child: Text('Veiligheid')),
                                    ],
                                    onChanged: (value) {
                                      setDialogState(() => selectedDomain = value ?? 'Arbeidsveiligheid');
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  label('Risicoveld'),
                                  const SizedBox(height: 8),
                                  TextField(controller: riskController, decoration: fieldDecoration('Algemeen')),
                                  const SizedBox(height: 16),
                                  label('Startjaar *'),
                                  const SizedBox(height: 8),
                                  TextField(controller: startYearController, keyboardType: TextInputType.number, decoration: fieldDecoration('2026')),
                                  const SizedBox(height: 16),
                                  label('Eindjaar *'),
                                  const SizedBox(height: 8),
                                  TextField(controller: endYearController, keyboardType: TextInputType.number, decoration: fieldDecoration('2027')),
                                  const SizedBox(height: 16),
                                  label('Uitvoerder'),
                                  const SizedBox(height: 8),
                                  TextField(controller: executorController, decoration: fieldDecoration('...')),
                                  const SizedBox(height: 16),
                                  label('Middelen / Budget / Werkuren'),
                                  const SizedBox(height: 8),
                                  TextField(controller: budgetController, decoration: fieldDecoration('...')),
                                  const SizedBox(height: 16),
                                  label('Prioriteit'),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue: priority,
                                    isExpanded: true,
                                    decoration: fieldDecoration(''),
                                    items: const [
                                      DropdownMenuItem(value: 'hoog', child: Text('Hoge prioriteit')),
                                      DropdownMenuItem(value: 'middel', child: Text('Middelhoge prioriteit')),
                                      DropdownMenuItem(value: 'laag', child: Text('Lage prioriteit')),
                                    ],
                                    onChanged: (value) => priority = value ?? 'laag',
                                  ),
                                  const SizedBox(height: 16),
                                  label('Realisatie'),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue: realisation,
                                    isExpanded: true,
                                    decoration: fieldDecoration(''),
                                    items: const [
                                      DropdownMenuItem(value: 'in_uitvoering', child: Text('In uitvoering')),
                                      DropdownMenuItem(value: 'uitgevoerd', child: Text('Uitgevoerd')),
                                      DropdownMenuItem(value: 'neg_niet_uitgevoerd', child: Text('Nog niet uitgevoerd')),
                                      DropdownMenuItem(value: 'vul_aan', child: Text('Vul aan')),
                                    ],
                                    onChanged: (value) => realisation = value ?? 'in_uitvoering',
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          label('Opmerking'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: remarkController,
                            maxLines: 3,
                            decoration: fieldDecoration('...'),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext, false),
                                child: const Text('Annuleren'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () async {
                                  final startYear = int.tryParse(startYearController.text.trim());
                                  final endYear = int.tryParse(endYearController.text.trim());
                                  final goal = goalController.text.trim();
                                  if (startYear == null || endYear == null || goal.isEmpty) return;

                                  try {
                                    await JapApiService.createGppEntry(
                                      token: widget.token,
                                      payload: {
                                        'doelstellingMaatregel': goal,
                                        'domein': selectedDomain,
                                        'risicoveld': riskController.text.trim(),
                                        'startJaar': startYear,
                                        'eindJaar': endYear,
                                        'prioriteit': priority,
                                        'realisatie': realisation,
                                        'uitvoerder': executorController.text.trim(),
                                        'middelenBudgetWerkuren': budgetController.text.trim(),
                                        'startdatum': '$startYear.01.01',
                                        'einddatum': '$endYear.12.31',
                                        'opmerking': remarkController.text.trim(),
                                      },
                                    );
                                    if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                                  } catch (e) {
                                    if (dialogContext.mounted) {
                                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                                        SnackBar(content: Text('Opslaan mislukt: $e')),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8BC34A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                child: const Text('Opslaan'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    goalController.dispose();
    riskController.dispose();
    executorController.dispose();
    budgetController.dispose();
    remarkController.dispose();
    startYearController.dispose();
    endYearController.dispose();

    if (saved == true) {
      await _reloadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPP aangemaakt.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show full-screen detail view when an entry is selected
    if (_selectedJap != null || _selectedGpp != null) {
      if (_selectedJap != null) {
        return JapGppDetailPane.jap(
          token: widget.token,
          entry: _selectedJap!,
          onChanged: _reloadAll,
          onClose: () {
            setState(() => _selectedJap = null);
          },
        );
      }

      if (_selectedGpp != null) {
        return JapGppDetailPane.gpp(
          token: widget.token,
          entry: _selectedGpp!,
          onChanged: _reloadAll,
          onClose: () {
            setState(() => _selectedGpp = null);
          },
        );
      }
    }

    // Show list view in container
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildToolbar(),
            const SizedBox(height: 12),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Text('JAP & GPP', style: Theme.of(context).textTheme.headlineMedium),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: _loading ? null : _showCreateGppDialog,
            icon: const Icon(Icons.add),
            label: const Text('Nieuw'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8BC34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Zoeken',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF8F8F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              controller: _searchController,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _savingImport ? null : _importGppExcel,
            icon: _savingImport
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.upload_file),
            label: const Text('Import'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8BC34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _exportByYear,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Export'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8BC34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _reloadAll,
              child: const Text('Opnieuw proberen'),
            ),
          ],
        ),
      );
    }

    return _buildListPane();
  }

  Widget _buildListPane() {
    final combinedItems = <_CombinedListItem>[
      ..._filteredJapEntries().map((entry) => _CombinedListItem.jap(entry)),
      ..._filteredGppEntries().map((entry) => _CombinedListItem.gpp(entry)),
    ]
      ..sort((a, b) {
        final yearCompare = b.sortYear.compareTo(a.sortYear);
        if (yearCompare != 0) return yearCompare;
        return a.goalMeasure.compareTo(b.goalMeasure);
      });

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E9DD)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SizedBox(
            width: double.infinity,
            child: DataTable(
              showCheckboxColumn: false,
              headingRowHeight: 56,
              dataRowMinHeight: 58,
              dataRowMaxHeight: 72,
              columnSpacing: 32,
              horizontalMargin: 24,
              headingRowColor: WidgetStateColor.resolveWith(
                (states) => const Color(0xFFF5F5F5),
              ),
              columns: const [
                DataColumn(label: Text('Jaar')),
                DataColumn(label: Text('Doelstelling - maatregel')),
                DataColumn(label: Text('Domein')),
                DataColumn(label: Text('Prioriteit')),
                DataColumn(label: Text('Realisatie')),
              ],
              rows: combinedItems.isEmpty
                  ? [
                      const DataRow(cells: [
                        DataCell(Text('Geen resultaten')),
                        DataCell(Text('')),
                        DataCell(Text('')),
                        DataCell(Text('')),
                        DataCell(Text('')),
                      ]),
                    ]
                  : combinedItems.map((item) {
                      return DataRow(
                        onSelectChanged: (_) {
                          if (item.isJap) {
                            _selectJap(item.jap!);
                          } else {
                            _selectGpp(item.gpp!);
                          }
                        },
                        cells: [
                          DataCell(Text(item.yearLabel)),
                          DataCell(
                            Text(
                              item.goalMeasure,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                            ),
                          ),
                          DataCell(Text(item.domain, overflow: TextOverflow.ellipsis)),
                          DataCell(Text(item.priorityLabel)),
                          DataCell(Text(item.realisationLabel)),
                        ],
                      );
                    }).toList(),
            ),
          ),
        ),
      ),
    );
  }

}

class _CombinedListItem {
  final bool isJap;
  final JapEntry? jap;
  final GppEntry? gpp;

  _CombinedListItem._({required this.isJap, this.jap, this.gpp});

  factory _CombinedListItem.jap(JapEntry entry) => _CombinedListItem._(isJap: true, jap: entry);
  factory _CombinedListItem.gpp(GppEntry entry) => _CombinedListItem._(isJap: false, gpp: entry);

  int get sortYear => isJap ? jap!.year : gpp!.endYear;

  String get yearLabel => isJap ? jap!.year.toString() : gpp!.yearLabel;

  String get domain => isJap ? jap!.domain : gpp!.domain;

  String get goalMeasure => isJap ? jap!.goalMeasure : gpp!.goalMeasure;

  String get priorityLabel => isJap ? _priorityToLabel(jap!.priority) : _priorityLabelFromString(gpp!.priority);

  String get realisationLabel => isJap ? _realisationToLabel(jap!.realisation) : _realisationLabelFromString(gpp!.realisation);

  String _priorityToLabel(JapPriority priority) {
    switch (priority) {
      case JapPriority.high:
        return 'Hoog';
      case JapPriority.medium:
        return 'Middel';
      case JapPriority.low:
        return 'Laag';
    }
  }

  String _realisationToLabel(JapRealisation realisation) {
    switch (realisation) {
      case JapRealisation.inProgress:
        return 'In uitvoering';
      case JapRealisation.completed:
        return 'Uitgevoerd';
      case JapRealisation.notYetCompleted:
        return 'Nog niet';
      case JapRealisation.fillIn:
        return 'Vul aan';
    }
  }

  String _priorityLabelFromString(String value) {
    switch (value.toLowerCase()) {
      case 'hoog':
      case 'high':
        return 'Hoog';
      case 'middel':
      case 'middelmatig':
      case 'medium':
        return 'Middel';
      default:
        return 'Laag';
    }
  }

  String _realisationLabelFromString(String value) {
    final normalised = value.toLowerCase().replaceAll(' ', '_');
    switch (normalised) {
      case 'in_uitvoering':
      case 'inuitvoering':
      case 'in_progress':
        return 'In uitvoering';
      case 'uitgevoerd':
      case 'completed':
        return 'Uitgevoerd';
      case 'nog_niet_uitgevoerd':
      case 'neg_niet_uitgevoerd':
        return 'Nog niet';
      default:
        return 'Vul aan';
    }
  }
}
