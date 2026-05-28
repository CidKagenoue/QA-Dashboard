import 'package:flutter/material.dart';
import '../models/jap_gpp_entry.dart';
import '../services/jap_gpp_api_service.dart';
import '../widgets/design/design_system.dart';
import '../widgets/manage_dropdown_field.dart';

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
  late List<String> _availableExecutors;
  bool _loadingExecutors = true;
  bool _editing = false;
  bool _saving = false;
  bool _loadingDomains = true;
  late DateTime? _editStartDate;
  late DateTime? _editEndDate;
  final GlobalKey _primaryColumnKey = GlobalKey();
  double? _primaryColumnHeight;

  bool get _isJap => widget.japEntry != null;

  JapEntry get _jap => widget.japEntry!;
  GppEntry get _gpp => widget.gppEntry!;
  int get _entryId => _isJap ? _jap.id : _gpp.id;
  String get _periodText =>
      _isJap ? 'Jaar ${_jap.year}' : '${_gpp.startYear} - ${_gpp.endYear}';
  DateTime get _defaultStartDate =>
      _isJap ? DateTime(_jap.year, 1, 1) : DateTime(_gpp.startYear, 1, 1);
  DateTime get _defaultEndDate =>
      _isJap ? DateTime(_jap.year, 12, 31) : DateTime(_gpp.endYear, 12, 31);
  String get _safePriority {
    const values = {'hoog', 'middel', 'laag'};
    return values.contains(_priority) ? _priority : 'laag';
  }

  String get _safeRealisation {
    const values = {
      'in_uitvoering',
      'uitgevoerd',
      'neg_niet_uitgevoerd',
      'vul_aan',
    };
    return values.contains(_realisation) ? _realisation : 'vul_aan';
  }

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
    _priority = _isJap ? _priorityValue(_jap.priority) : _gpp.priority;
    if (_isJap) {
      switch (_jap.realisation) {
        case JapRealisation.inProgress:
          _realisation = 'in_uitvoering';
          break;
        case JapRealisation.completed:
          _realisation = 'uitgevoerd';
          break;
        case JapRealisation.notYetCompleted:
          _realisation = 'neg_niet_uitgevoerd';
          break;
        case JapRealisation.fillIn:
          _realisation = 'vul_aan';
          break;
      }
    } else {
      _realisation = _gpp.realisation;
    }
    _selectedDomain = initialDomain;
    _editStartDate = _isJap ? _jap.startDate : _gpp.startDate;
    _editEndDate = _isJap ? _jap.endDate : _gpp.endDate;

    _loadDomains();
    _loadExecutors();
  }

  Future<void> _loadExecutors() async {
    try {
      final list = await JapApiService.fetchExecutors(token: widget.token);
      if (!mounted) return;
      setState(() {
        _availableExecutors = list;
        _loadingExecutors = false;
        final current = _executorController.text.trim();
        if (current.isNotEmpty && !_availableExecutors.contains(current)) {
          _availableExecutors.add(current);
          _availableExecutors.sort();
        }
      });
    } catch (e) {
      if (!mounted) return;
      final current = _executorController.text.trim();
      setState(() {
        if (current.isNotEmpty) {
          _availableExecutors = [current];
          _availableExecutors.sort();
        } else {
          _availableExecutors = <String>[];
        }
        _loadingExecutors = false;
      });
    }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Domeinen laden mislukt: $e')));
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
            'startdatum': _editStartDate != null
                ? _editStartDate!.toIso8601String().split('T')[0]
                : '$year.01.01',
            'einddatum': _editEndDate != null
                ? _editEndDate!.toIso8601String().split('T')[0]
                : '$year.12.31',
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
            'startdatum': _editStartDate != null
                ? _editStartDate!.toIso8601String().split('T')[0]
                : '$startYear.01.01',
            'einddatum': _editEndDate != null
                ? _editEndDate!.toIso8601String().split('T')[0]
                : '$endYear.12.31',
            'opmerking': _remarkController.text.trim(),
          },
        );
      }

      if (!mounted) return;
      setState(() => _editing = false);
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Opgeslagen.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Opslaan mislukt: $e')));
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
          content: const Text(
            'Weet je zeker dat je dit item wilt verwijderen?',
          ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Item verwijderd.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Verwijderen mislukt: $e')));
    }
  }

  Widget _buildReadOnlyBox(String value) {
    return _ReadOnlyValue(value: _displayValue(value));
  }

  Widget _buildTextField(TextEditingController controller, {int maxLines = 1}) {
    if (!_editing) {
      return _buildReadOnlyBox(controller.text.trim());
    }

    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: _fieldDecoration(),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    String? displayValue,
  }) {
    if (!_editing) {
      return _buildReadOnlyBox(displayValue ?? value);
    }

    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      borderRadius: BorderRadius.circular(kRadiusMd),
      dropdownColor: kSurface,
      decoration: _fieldDecoration(),
      items: items,
      onChanged: onChanged,
    );
  }

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: kSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        borderSide: const BorderSide(color: kBrandGreen, width: 1.6),
      ),
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
    final safeInitialDomain = uniqueDomains.contains(_selectedDomain)
        ? _selectedDomain
        : '';

    return ManageDropdownField(
      items: uniqueDomains,
      value: safeInitialDomain,
      hint: '',
      title: 'Domeinen beheren',
      addLabel: 'Nieuw domein',
      addHint: 'Voer domeinnaam in',
      onChanged: (v) => setState(
        () => _selectedDomain = v.isEmpty
            ? (uniqueDomains.isNotEmpty ? uniqueDomains.first : '')
            : v,
      ),
      onItemsChanged: (items) => setState(() => _availableDomains = items),
      onAddItem: (value) async {
        try {
          return await JapApiService.createDomain(
            token: widget.token,
            name: value,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Domein toevoegen mislukt: $e')),
            );
          }
          return null;
        }
      },
      onDeleteItem: (value) async {
        try {
          await JapApiService.deleteDomain(
            token: widget.token,
            domainName: value,
          );
          return true;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Domein verwijderen mislukt: $e')),
            );
          }
          return false;
        }
      },
    );
  }

  Widget _buildExecutorDropdown() {
    if (!_editing) return _buildReadOnlyBox(_executorController.text.trim());

    if (_loadingExecutors) {
      return const Center(child: CircularProgressIndicator());
    }

    final uniqueExecutors = <String>[];
    for (final d in _availableExecutors) {
      if (d.trim().isEmpty) continue;
      if (!uniqueExecutors.contains(d)) uniqueExecutors.add(d);
    }

    return ManageDropdownField(
      items: uniqueExecutors,
      value: _executorController.text.trim(),
      hint: '',
      title: 'Uitvoerders beheren',
      addLabel: 'Nieuwe uitvoerder',
      addHint: 'Voer naam uitvoerder in',
      onChanged: (v) => setState(() => _executorController.text = v),
      onItemsChanged: (items) => setState(() => _availableExecutors = items),
      onAddItem: (value) async {
        return JapApiService.createExecutor(token: widget.token, name: value);
      },
      onDeleteItem: (value) async {
        try {
          await JapApiService.deleteExecutor(
            token: widget.token,
            executorName: value,
          );
          return true;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Uitvoerder verwijderen mislukt: $e')),
            );
          }
          return false;
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kBackground,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Container(
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(kRadius2xl),
          border: Border.all(color: kBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppBreadcrumb(segments: ['Dashboard', 'JAP & GPP']),
              const SizedBox(height: 16),
              _buildHeader(),
              const SizedBox(height: 20),
              Expanded(child: SingleChildScrollView(child: _buildContent())),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final actions = _buildHeaderActions();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final title = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppBackButton(onTap: widget.onClose),
            const SizedBox(width: 14),
            Expanded(child: _buildHeaderTitleBlock()),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderTitleBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _isJap ? 'JAP item' : 'GPP item',
              style: const TextStyle(
                fontSize: 13,
                color: kTextTertiary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 8),
            _buildRealisationPill(),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '#${_entryId.toString().padLeft(4, '0')}',
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: kTextPrimary,
            height: 1.1,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _periodText,
          style: const TextStyle(
            fontSize: 13,
            color: kTextTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildHeaderActions() {
    return [
      if (_editing)
        OutlinedButton(
          onPressed: _saving ? null : () => setState(() => _editing = false),
          child: const Text('Annuleren'),
        ),
      OutlinedButton.icon(
        onPressed: _saving ? null : _delete,
        icon: const Icon(Icons.delete_outline_rounded, size: 18),
        label: const Text('Verwijderen'),
        style: OutlinedButton.styleFrom(
          foregroundColor: kDanger,
          side: const BorderSide(color: kDangerBorder),
        ),
      ),
      ElevatedButton.icon(
        onPressed: _saving
            ? null
            : (_editing ? _save : () => setState(() => _editing = true)),
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                _editing ? Icons.save_rounded : Icons.edit_outlined,
                size: 18,
              ),
        label: Text(_editing ? 'Opslaan' : 'Bewerken'),
      ),
    ];
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1040;
        if (wide) {
          _schedulePrimaryColumnHeightMeasure();

          final sideColumnWidth = (constraints.maxWidth * 0.34).clamp(
            420.0,
            540.0,
          );

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: KeyedSubtree(
                  key: _primaryColumnKey,
                  child: _buildPrimaryColumn(),
                ),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: sideColumnWidth,
                child: _buildSideColumn(fillHeight: true),
              ),
            ],
          );
        }

        if (_primaryColumnHeight != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _primaryColumnHeight = null);
            }
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPrimaryColumn(),
            const SizedBox(height: 18),
            _buildSideColumn(),
          ],
        );
      },
    );
  }

  void _schedulePrimaryColumnHeightMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final renderBox =
          _primaryColumnKey.currentContext?.findRenderObject() as RenderBox?;
      final height = renderBox?.size.height;
      if (height == null || height <= 0) return;

      final current = _primaryColumnHeight;
      if (current != null && (current - height).abs() < 0.5) return;

      setState(() {
        _primaryColumnHeight = height;
      });
    });
  }

  Widget _buildPrimaryColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGoalPanel(),
        const SizedBox(height: 16),
        _buildContextPanel(),
        const SizedBox(height: 16),
        _buildPlanningPanel(),
      ],
    );
  }

  Widget _buildSideColumn({bool fillHeight = false}) {
    final remarkPanel = _buildRemarkPanel();
    final height = _primaryColumnHeight;

    if (fillHeight && height != null && height > 0) {
      return SizedBox(height: height, child: remarkPanel);
    }

    return remarkPanel;
  }

  Widget _buildGoalPanel() {
    return AppSectionPanel(
      title: 'Doelstelling / maatregel',
      icon: Icons.track_changes_outlined,
      child: _editing
          ? _buildTextField(_goalController, maxLines: 6)
          : _ReadOnlyValue(value: _displayValue(_goalController.text)),
    );
  }

  Widget _buildContextPanel() {
    return AppSectionPanel(
      title: 'Context',
      icon: Icons.account_tree_outlined,
      child: _detailGrid([
        _DetailField(
          label: 'Domein',
          readValue: _displayValue(_selectedDomain),
          editor: _buildDomainDropdown(),
        ),
        _DetailField(
          label: 'Risicoveld',
          readValue: _displayValue(_riskController.text),
          editor: _buildTextField(_riskController),
        ),
        _DetailField(
          label: 'Uitvoerder',
          readValue: _displayValue(_executorController.text),
          editor: _buildExecutorDropdown(),
        ),
        _DetailField(
          label: 'Middelen / Budget / Werkuren',
          readValue: _displayValue(_budgetController.text),
          editor: _buildTextField(_budgetController),
          wide: true,
        ),
      ]),
    );
  }

  Widget _buildPlanningPanel() {
    return AppSectionPanel(
      title: 'Planning & voortgang',
      icon: Icons.event_note_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailGrid([
            _DetailField(
              label: _isJap ? 'Jaar' : 'Periode',
              readValue: _periodText,
              editor: _ReadOnlyValue(value: _periodText),
            ),
            _DetailField(
              label: 'Startdatum',
              readValue: _formatDate(_editStartDate),
              editor: _buildDateEditor(
                value: _editStartDate,
                fallbackDate: _defaultStartDate,
                onChanged: (date) => setState(() => _editStartDate = date),
              ),
            ),
            _DetailField(
              label: 'Einddatum',
              readValue: _formatDate(_editEndDate),
              editor: _buildDateEditor(
                value: _editEndDate,
                fallbackDate: _defaultEndDate,
                onChanged: (date) => setState(() => _editEndDate = date),
              ),
            ),
          ], minItemWidth: 160),
          const SizedBox(height: 16),
          _detailGrid([
            _DetailField(
              label: 'Prioriteit',
              readValue: _priorityLabel(_priority),
              editor: _buildPriorityDropdown(),
            ),
            _DetailField(
              label: 'Realisatie',
              readValue: _getRealisationLabel(_realisation),
              editor: _buildRealisationDropdown(),
            ),
          ], minItemWidth: 160),
        ],
      ),
    );
  }

  Widget _buildRemarkPanel() {
    return AppSectionPanel(
      title: 'Opmerking',
      icon: Icons.notes_outlined,
      child: _editing
          ? _buildTextField(_remarkController, maxLines: 5)
          : _ReadOnlyValue(value: _displayValue(_remarkController.text)),
    );
  }

  Widget _detailGrid(List<_DetailField> fields, {double minItemWidth = 220}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 20.0;
        final columnCount =
            ((constraints.maxWidth + gap) / (minItemWidth + gap)).floor().clamp(
              1,
              3,
            );
        final itemWidth =
            (constraints.maxWidth - (gap * (columnCount - 1))) / columnCount;

        return Wrap(
          spacing: gap,
          runSpacing: 16,
          children: fields.map((field) {
            return SizedBox(
              width: field.wide ? constraints.maxWidth : itemWidth,
              child: _LabeledField(
                label: field.label,
                child: _editing
                    ? field.editor
                    : _ReadOnlyValue(value: field.readValue),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPriorityDropdown() {
    return _buildDropdown(
      value: _safePriority,
      displayValue: _priorityLabel(_priority),
      items: const [
        DropdownMenuItem(value: 'hoog', child: Text('Hoge prioriteit')),
        DropdownMenuItem(value: 'middel', child: Text('Middelhoge prioriteit')),
        DropdownMenuItem(value: 'laag', child: Text('Lage prioriteit')),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _priority = value);
      },
    );
  }

  Widget _buildRealisationDropdown() {
    return _buildDropdown(
      value: _safeRealisation,
      displayValue: _getRealisationLabel(_realisation),
      items: const [
        DropdownMenuItem(value: 'in_uitvoering', child: Text('In uitvoering')),
        DropdownMenuItem(value: 'uitgevoerd', child: Text('Uitgevoerd')),
        DropdownMenuItem(
          value: 'neg_niet_uitgevoerd',
          child: Text('Nog niet uitgevoerd'),
        ),
        DropdownMenuItem(value: 'vul_aan', child: Text('Vul aan')),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _realisation = value);
      },
    );
  }

  Widget _buildDateEditor({
    required DateTime? value,
    required DateTime fallbackDate,
    required ValueChanged<DateTime> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? fallbackDate,
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: InputDecorator(
        decoration: _fieldDecoration().copyWith(
          suffixIcon: const Icon(
            Icons.calendar_today_outlined,
            size: 18,
            color: kTextTertiary,
          ),
        ),
        child: Text(
          _formatDate(value),
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: value == null ? kTextMuted : kTextPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildRealisationPill() {
    return AppStatusPill(
      label: _getRealisationLabel(_realisation),
      tone: _realisationTone(_realisation),
    );
  }

  String _getRealisationLabel(String realisation) {
    switch (realisation.toLowerCase()) {
      case 'in_uitvoering':
        return 'In uitvoering';
      case 'uitgevoerd':
        return 'Uitgevoerd';
      case 'neg_niet_uitgevoerd':
        return 'Nog niet uitgevoerd';
      case 'vul_aan':
        return 'Vul aan';
      default:
        return realisation;
    }
  }

  AppStatusTone _realisationTone(String realisation) {
    switch (realisation.toLowerCase()) {
      case 'in_uitvoering':
        return AppStatusTone.info;
      case 'uitgevoerd':
        return AppStatusTone.success;
      case 'neg_niet_uitgevoerd':
        return AppStatusTone.danger;
      case 'vul_aan':
        return AppStatusTone.neutral;
      default:
        return AppStatusTone.neutral;
    }
  }

  String _priorityValue(JapPriority priority) {
    switch (priority) {
      case JapPriority.high:
        return 'hoog';
      case JapPriority.medium:
        return 'middel';
      case JapPriority.low:
        return 'laag';
    }
  }

  String _priorityLabel(String priority) {
    switch (priority.toLowerCase()) {
      case 'hoog':
      case 'high':
        return 'Hoge prioriteit';
      case 'middel':
      case 'medium':
      case 'middelhoog':
        return 'Middelhoge prioriteit';
      case 'laag':
      case 'low':
        return 'Lage prioriteit';
      default:
        return _displayValue(priority);
    }
  }

  String _displayValue(String? value) {
    final normalized = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized == null || normalized.isEmpty) {
      return '-';
    }
    return normalized;
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Niet ingevuld';
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}

class _DetailField {
  const _DetailField({
    required this.label,
    required this.readValue,
    required this.editor,
    this.wide = false,
  });

  final String label;
  final String readValue;
  final Widget editor;
  final bool wide;
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: kTextTertiary,
            letterSpacing: 0.2,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ReadOnlyValue extends StatelessWidget {
  const _ReadOnlyValue({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.trim() == '-' || value.trim().isEmpty;
    return Text(
      isEmpty ? '-' : value,
      style: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w800,
        color: isEmpty ? kTextMuted : Colors.black,
        height: 1.5,
      ),
    );
  }
}
