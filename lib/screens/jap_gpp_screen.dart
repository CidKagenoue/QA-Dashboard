import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../widgets/manage_dropdown_field.dart';
import '../services/jap_export_service.dart';
import '../models/jap_gpp_entry.dart';
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
  
  // Filters
  final Set<int> _filterYears = <int>{};
  String? _filterDomain;
  final Set<String> _filterPriorities = <String>{};
  String? _filterRealisation;
  String _filterExecutor = '';

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
    // First apply explicit filters
    var entries = _japEntries.where((entry) {
      if (_filterYears.isNotEmpty && !_filterYears.contains(entry.year)) return false;
      if (_filterDomain != null && _filterDomain!.isNotEmpty && entry.domain != _filterDomain) return false;
      if (_filterPriorities.isNotEmpty) {
        final p = _japPriorityRaw(entry.priority);
        if (!_filterPriorities.contains(p)) return false;
      }
      if (_filterRealisation != null && _filterRealisation!.isNotEmpty) {
        final r = _japRealisationRaw(entry.realisation);
        if (r != _filterRealisation) return false;
      }
      if (_filterExecutor.trim().isNotEmpty) {
        if (!entry.executor.toLowerCase().contains(_filterExecutor.toLowerCase())) return false;
      }
      return true;
    }).toList();

    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return entries;
    return entries.where((entry) {
      return entry.goalMeasure.toLowerCase().contains(query) ||
          entry.domain.toLowerCase().contains(query) ||
          entry.executor.toLowerCase().contains(query) ||
          entry.remark.toLowerCase().contains(query) ||
          entry.year.toString().contains(query);
    }).toList();
  }

  List<GppEntry> _filteredGppEntries() {
    var entries = _gppEntries.where((entry) {
      if (_filterYears.isNotEmpty) {
        var matchesYear = false;
        for (final y in _filterYears) {
          if (entry.startYear <= y && y <= entry.endYear) {
            matchesYear = true;
            break;
          }
        }
        if (!matchesYear) return false;
      }
      if (_filterDomain != null && _filterDomain!.isNotEmpty && entry.domain != _filterDomain) return false;
      if (_filterPriorities.isNotEmpty) {
        final p = entry.priority.toLowerCase();
        if (!_filterPriorities.contains(p)) return false;
      }
      if (_filterRealisation != null && _filterRealisation!.isNotEmpty) {
        final r = entry.realisation.toLowerCase();
        if (r != _filterRealisation) return false;
      }
      if (_filterExecutor.trim().isNotEmpty) {
        if (!entry.executor.toLowerCase().contains(_filterExecutor.toLowerCase())) return false;
      }
      return true;
    }).toList();

    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return entries;
    return entries.where((entry) {
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

  List<String> _distinctDomains() {
    final set = <String>{};
    for (final e in _japEntries) set.add(e.domain);
    for (final e in _gppEntries) set.add(e.domain);
    return set.toList()..sort();
  }

  List<String> _distinctExecutors() {
    final set = <String>{};
    for (final e in _japEntries) {
      if (e.executor.trim().isNotEmpty) set.add(e.executor.trim());
    }
    for (final e in _gppEntries) {
      if (e.executor.trim().isNotEmpty) set.add(e.executor.trim());
    }
    return set.toList()..sort();
  }

  String _japPriorityRaw(JapPriority p) {
    switch (p) {
      case JapPriority.high:
        return 'hoog';
      case JapPriority.medium:
        return 'middel';
      case JapPriority.low:
        return 'laag';
    }
  }

  String _japRealisationRaw(JapRealisation r) {
    switch (r) {
      case JapRealisation.inProgress:
        return 'in_uitvoering';
      case JapRealisation.completed:
        return 'uitgevoerd';
      case JapRealisation.notYetCompleted:
        return 'neg_niet_uitgevoerd';
      case JapRealisation.fillIn:
        return 'vul_aan';
    }
  }

  void _clearFilters() {
    setState(() {
      _filterYears.clear();
      _filterDomain = null;
      _filterPriorities.clear();
      _filterRealisation = null;
      _filterExecutor = '';
    });
  }

  Future<void> _openFilterDialog() async {
    final availableYears = _availableYears();
    final domains = _distinctDomains();

    final selectedYears = Set<int>.from(_filterYears);
    String? selectedDomain = _filterDomain;
    final selectedPriorities = Set<String>.from(_filterPriorities);
    String? selectedRealisation = _filterRealisation;
    final executors = _distinctExecutors();
    String? selectedExecutor = _filterExecutor.trim().isEmpty ? null : _filterExecutor.trim();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (c, setDialogState) {
          Widget chipYear(int y) {
            final sel = selectedYears.contains(y);
            return ChoiceChip(
              label: Text(y.toString()),
              selected: sel,
              onSelected: (_) => setDialogState(() {
                if (sel)
                  selectedYears.remove(y);
                else
                  selectedYears.add(y);
              }),
            );
          }

          Widget priorityChip(String val, String label) {
            final sel = selectedPriorities.contains(val);
            return FilterChip(
              label: Text(label),
              selected: sel,
              onSelected: (_) => setDialogState(() {
                if (sel)
                  selectedPriorities.remove(val);
                else
                  selectedPriorities.add(val);
              }),
            );
          }

          return AlertDialog(
            title: const Text('Filters'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Jaar'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: availableYears.map(chipYear).toList()),
                  const SizedBox(height: 12),
                  const Text('Domein'),
                  const SizedBox(height: 8),
                  DropdownButton<String?>(
                    isExpanded: true,
                    value: selectedDomain,
                    hint: const Text('Alle domeinen'),
                    items: [null, ...domains].map((d) {
                      return DropdownMenuItem<String?>(value: d, child: Text(d ?? 'Alle domeinen'));
                    }).toList(),
                    onChanged: (v) => setDialogState(() => selectedDomain = v),
                  ),
                  const SizedBox(height: 12),
                  const Text('Prioriteit'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, children: [
                    priorityChip('hoog', 'Hoog'),
                    priorityChip('middel', 'Middel'),
                    priorityChip('laag', 'Laag'),
                  ]),
                  const SizedBox(height: 12),
                  const Text('Realisatie'),
                  const SizedBox(height: 8),
                  // show human-friendly labels instead of raw keys with underscores
                  DropdownButton<String?>(
                    isExpanded: true,
                    value: selectedRealisation,
                    hint: const Text('Alle'),
                    items: <MapEntry<String?, String>>[
                      MapEntry(null, 'Alle'),
                      MapEntry('in_uitvoering', 'In uitvoering'),
                      MapEntry('uitgevoerd', 'Uitgevoerd'),
                      MapEntry('neg_niet_uitgevoerd', 'Nog niet uitgevoerd'),
                      MapEntry('vul_aan', 'Vul aan'),
                    ].map((opt) => DropdownMenuItem<String?>(value: opt.key, child: Text(opt.value))).toList(),
                    onChanged: (v) => setDialogState(() => selectedRealisation = v),
                  ),
                  const SizedBox(height: 12),
                  const Text('Uitvoerder'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    value: selectedExecutor,
                    decoration: const InputDecoration(isDense: true),
                    hint: const Text('Alle uitvoerders'),
                    items: [null, ...executors].map((e) => DropdownMenuItem<String?>(value: e, child: Text(e ?? 'Alle uitvoerders'))).toList(),
                    onChanged: (v) => setDialogState(() => selectedExecutor = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // clear only in dialog then close
                  _clearFilters();
                  Navigator.pop(dialogContext);
                },
                child: const Text('Wis filters'),
              ),
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuleren')),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _filterYears
                      ..clear()
                      ..addAll(selectedYears);
                    _filterDomain = selectedDomain;
                    _filterPriorities
                      ..clear()
                      ..addAll(selectedPriorities);
                    _filterRealisation = selectedRealisation;
                    _filterExecutor = selectedExecutor ?? '';
                  });
                  Navigator.pop(dialogContext);
                },
                child: const Text('Toepassen'),
              ),
            ],
          );
        });
      },
    );
    
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

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        int? selectedYear = years.first;
        List<JapEntry> previewEntries = [];
        bool exporting = false;

        // previewEntries are computed locally from _entriesForExportYear when requested

        return StatefulBuilder(builder: (c, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900, maxHeight: 720),
                child: Container(
                  decoration: BoxDecoration(color: const Color(0xFFF1F2EA), borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Export JAP - kies jaar', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(dialogContext),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Selecteer het jaar en bekijk een preview voordat je downloadt.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
                      const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Wrap(
                                      spacing: 8,
                                      children: years.map((y) {
                                        final selected = selectedYear == y;
                                        return ChoiceChip(
                                          label: Text(y.toString()),
                                          selected: selected,
                                          onSelected: (_) => setDialogState(() {
                                            selectedYear = y;
                                            previewEntries = _entriesForExportYear(y);
                                          }),
                                          backgroundColor: Colors.white,
                                          selectedColor: const Color(0xFF8BC34A).withOpacity(0.18),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                              ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE6E6E6))),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Voorbeeld - ${selectedYear ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(previewEntries.isEmpty ? 'Geen items geselecteerd' : '${previewEntries.length} items', style: const TextStyle(color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: previewEntries.isEmpty
                                    ? Center(child: Text('Kies een jaar om het voorbeeld te laden.', style: TextStyle(color: Colors.grey[700])))
                                    : ListView.separated(
                                        itemCount: previewEntries.length,
                                            separatorBuilder: (_, __) => const Divider(height: 8),
                                        itemBuilder: (context, idx) {
                                          final e = previewEntries[idx];
                                          return ListTile(
                                            contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                            leading: CircleAvatar(
                                              radius: 14,
                                              backgroundColor: const Color(0xFF8BC34A).withOpacity(0.12),
                                              child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, color: Color(0xFF4A7A1E), fontWeight: FontWeight.w700)),
                                            ),
                                            title: Text(e.goalMeasure, maxLines: 2, overflow: TextOverflow.ellipsis),
                                            subtitle: Text('${e.domain} | ${e.startDate != null ? e.startDate!.toIso8601String().split('T')[0] : ''} - ${e.endDate != null ? e.endDate!.toIso8601String().split('T')[0] : ''}\n${e.executor.isEmpty ? '-' : e.executor}', maxLines: 2, overflow: TextOverflow.ellipsis),
                                            isThreeLine: true,
                                            trailing: Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                                                  child: Text(e.priority.toLabel(), style: const TextStyle(fontSize: 11)),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                                                  child: Text(e.realisation.toLabel(), style: const TextStyle(fontSize: 11)),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuleren')),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: exporting
                                ? null
                                : () async {
                                    if (selectedYear == null) return;
                                    final year = selectedYear!;
                                    setDialogState(() => exporting = true);
                                    final entries = _entriesForExportYear(year);
                                    try {
                                      final savedPath = await JapExportService.exportJapForYear(year, entries);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(savedPath != null ? 'PDF opgeslagen: $savedPath' : 'PDF-export gestart voor $year')));
                                      Navigator.pop(dialogContext);
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export mislukt: $e')));
                                    } finally {
                                      setDialogState(() => exporting = false);
                                    }
                                  },
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: exporting ? const Text('Bezig met exporteren...') : const Text('PDF downloaden'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8BC34A)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
      },
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
    DateTime startDate = DateTime(DateTime.now().year, 1, 1);
    DateTime endDate = DateTime(DateTime.now().year + 3, 12, 31);
    String priority = 'laag';
    String realisation = 'in_uitvoering';
    String selectedDomain = 'Arbeidsveiligheid';

    final executors = <String>[];
    try {
      executors.addAll(await JapApiService.fetchExecutors(token: widget.token));
    } catch (_) {
      executors.addAll(_distinctExecutors());
    }

    // load domains from API (fallback to defaults on error)
    List<String> domains;
    try {
      domains = await JapApiService.fetchDomains(token: widget.token);
      if (domains.isEmpty) throw Exception('empty');
    } catch (e) {
      domains = [
        'Arbeidsveiligheid',
        'Gezondheid',
        'Milieu',
        'Kwaliteit',
        'Veiligheid',
      ];
    }

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
                                          ManageDropdownField(
                                            items: domains,
                                            value: selectedDomain,
                                            hint: '',
                                            title: 'Domeinen beheren',
                                            addLabel: 'Nieuw domein',
                                            addHint: 'Naam domein',
                                            onChanged: (value) => setDialogState(() => selectedDomain = value.isEmpty ? (domains.isNotEmpty ? domains.first : '') : value),
                                            onItemsChanged: (items) => setDialogState(() {
                                              domains
                                                ..clear()
                                                ..addAll(items);
                                            }),
                                            onAddItem: (value) async {
                                              try {
                                                return await JapApiService.createDomain(token: widget.token, name: value);
                                              } catch (e) {
                                                if (dialogContext.mounted) {
                                                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Domein toevoegen mislukt: $e')));
                                                }
                                                return null;
                                              }
                                            },
                                            onDeleteItem: (value) async {
                                              try {
                                                await JapApiService.deleteDomain(token: widget.token, domainName: value);
                                                return true;
                                              } catch (e) {
                                                if (dialogContext.mounted) {
                                                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Domein verwijderen mislukt: $e')));
                                                }
                                                return false;
                                              }
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
                                                    label('Startdatum *'),
                                                    const SizedBox(height: 8),
                                                    GestureDetector(
                                                      onTap: () async {
                                                        final picked = await showDatePicker(
                                                          context: dialogContext,
                                                          initialDate: startDate,
                                                          firstDate: DateTime(1900),
                                                          lastDate: DateTime(2100),
                                                        );
                                                        if (picked != null) setDialogState(() => startDate = picked);
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
                                                        child: Text(startDate.toIso8601String().split('T')[0]),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    label('Einddatum *'),
                                                    const SizedBox(height: 8),
                                                    GestureDetector(
                                                      onTap: () async {
                                                        final picked = await showDatePicker(
                                                          context: dialogContext,
                                                          initialDate: endDate,
                                                          firstDate: DateTime(1900),
                                                          lastDate: DateTime(2100),
                                                        );
                                                        if (picked != null) setDialogState(() => endDate = picked);
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
                                                        child: Text(endDate.toIso8601String().split('T')[0]),
                                                      ),
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
                                          ManageDropdownField(
                                            items: executors,
                                            value: executorController.text.trim(),
                                            hint: '',
                                            title: 'Uitvoerders beheren',
                                            addLabel: 'Nieuwe uitvoerder',
                                            addHint: 'Naam uitvoerder',
                                            onChanged: (v) => setDialogState(() => executorController.text = v),
                                            onItemsChanged: (items) => setDialogState(() {
                                              executors
                                                ..clear()
                                                ..addAll(items);
                                            }),
                                            onAddItem: (value) async {
                                              return JapApiService.createExecutor(token: widget.token, name: value);
                                            },
                                            onDeleteItem: (value) async {
                                              try {
                                                await JapApiService.deleteExecutor(token: widget.token, executorName: value);
                                                return true;
                                              } catch (e) {
                                                if (dialogContext.mounted) {
                                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                                    SnackBar(content: Text('Uitvoerder verwijderen mislukt: $e')),
                                                  );
                                                }
                                                return false;
                                              }
                                            },
                                          ),
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
                                  ManageDropdownField(
                                    items: domains,
                                    value: selectedDomain,
                                    hint: '',
                                    title: 'Domeinen beheren',
                                    addLabel: 'Nieuw domein',
                                    addHint: 'Naam domein',
                                    onChanged: (value) => setDialogState(() => selectedDomain = value.isEmpty ? (domains.isNotEmpty ? domains.first : '') : value),
                                    onItemsChanged: (items) => setDialogState(() {
                                      domains
                                        ..clear()
                                        ..addAll(items);
                                    }),
                                    onAddItem: (value) async {
                                      try {
                                        return await JapApiService.createDomain(token: widget.token, name: value);
                                      } catch (e) {
                                        if (dialogContext.mounted) {
                                          ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Domein toevoegen mislukt: $e')));
                                        }
                                        return null;
                                      }
                                    },
                                    onDeleteItem: (value) async {
                                      try {
                                        await JapApiService.deleteDomain(token: widget.token, domainName: value);
                                        return true;
                                      } catch (e) {
                                        if (dialogContext.mounted) {
                                          ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Domein verwijderen mislukt: $e')));
                                        }
                                        return false;
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  label('Risicoveld'),
                                  const SizedBox(height: 8),
                                  TextField(controller: riskController, decoration: fieldDecoration('Algemeen')),
                                  const SizedBox(height: 16),
                                  label('Startdatum *'),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: dialogContext,
                                        initialDate: startDate,
                                        firstDate: DateTime(1900),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) setDialogState(() => startDate = picked);
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
                                      child: Text(startDate.toIso8601String().split('T')[0]),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  label('Einddatum *'),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: dialogContext,
                                        initialDate: endDate,
                                        firstDate: DateTime(1900),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) setDialogState(() => endDate = picked);
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
                                      child: Text(endDate.toIso8601String().split('T')[0]),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  label('Uitvoerder'),
                                  const SizedBox(height: 8),
                                  ManageDropdownField(
                                    items: executors,
                                    value: executorController.text.trim(),
                                    hint: '',
                                    title: 'Uitvoerders beheren',
                                    addLabel: 'Nieuwe uitvoerder',
                                    addHint: 'Naam uitvoerder',
                                    onChanged: (v) => executorController.text = v,
                                    onItemsChanged: (items) => setDialogState(() {
                                      executors
                                        ..clear()
                                        ..addAll(items);
                                    }),
                                    onAddItem: (value) async {
                                      return JapApiService.createExecutor(token: widget.token, name: value);
                                    },
                                    onDeleteItem: (value) async {
                                      try {
                                        await JapApiService.deleteExecutor(token: widget.token, executorName: value);
                                        return true;
                                      } catch (e) {
                                        if (dialogContext.mounted) {
                                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                                            SnackBar(content: Text('Uitvoerder verwijderen mislukt: $e')),
                                          );
                                        }
                                        return false;
                                      }
                                    },
                                  ),
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
                                  final goal = goalController.text.trim();
                                  if (goal.isEmpty) return;
                                  // Use full dates; also send startJaar/eindJaar as years for indexing
                                  final startYear = startDate.year;
                                  final endYear = endDate.year;
                                  final startIso = startDate.toIso8601String().split('T')[0];
                                  final endIso = endDate.toIso8601String().split('T')[0];

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
                                        'startdatum': startIso,
                                        'einddatum': endIso,
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
    // date pickers replaced year text controllers

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
            onPressed: _openFilterDialog,
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
