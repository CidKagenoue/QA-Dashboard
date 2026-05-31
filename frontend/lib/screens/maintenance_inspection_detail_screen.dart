import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/branch.dart';
import '../models/maintenance_inspection_form.dart';
import '../models/maintenance_inspections.dart';
import '../services/auth_service.dart';
import '../services/maintenance_api_service.dart';
import '../widgets/design/design_system.dart';

class MaintenanceInspectionDetailScreen extends StatefulWidget {
  const MaintenanceInspectionDetailScreen({
    super.key,
    this.inspection,
    this.inspectionId,
    required this.onClose,
  }) : assert(inspection != null || inspectionId != null);

  final MaintenanceInspection? inspection;
  final int? inspectionId;
  final VoidCallback onClose;

  @override
  State<MaintenanceInspectionDetailScreen> createState() =>
      _MaintenanceInspectionDetailScreenState();
}

class _MaintenanceInspectionDetailScreenState
    extends State<MaintenanceInspectionDetailScreen> {
  MaintenanceInspection? _inspection;
  List<Branch> _branches = const [];
  bool _editing = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isLoadingBranches = false;
  String? _error;
  String? _equipmentError;
  String? _inspectionInstitutionError;
  String? _branchesError;
  final GlobalKey _maintenancePrimaryColumnKey = GlobalKey();
  double? _maintenancePrimaryColumnHeight;

  final TextEditingController _equipmentController = TextEditingController();
  final TextEditingController _inspectionInstitutionController =
      TextEditingController();
  final TextEditingController _contactInfoController = TextEditingController();
  final TextEditingController _frequencyValueController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _inspectionType = 'Kalibratie';
  String _frequencyUnit = 'Jaar';
  bool _selfContact = false;
  String? _status;
  DateTime? _lastInspectionDate;
  DateTime? _dueDate;
  final Set<int> _selectedBranchIds = <int>{};

  @override
  void initState() {
    super.initState();
    _inspection = widget.inspection;
    if (_inspection == null) {
      _loadInspection();
    } else {
      _syncFromInspection(_inspection!);
    }
    _loadBranches();
    _equipmentController.addListener(() {
      if (_equipmentError != null &&
          _equipmentController.text.trim().isNotEmpty) {
        setState(() => _equipmentError = null);
      }
    });
    _inspectionInstitutionController.addListener(() {
      if (_inspectionInstitutionError != null &&
          _inspectionInstitutionController.text.trim().isNotEmpty) {
        setState(() => _inspectionInstitutionError = null);
      }
    });
  }

  @override
  void dispose() {
    _equipmentController.dispose();
    _inspectionInstitutionController.dispose();
    _contactInfoController.dispose();
    _frequencyValueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Data loading / persistence
  // ───────────────────────────────────────────────────────────────────────

  Future<void> _loadInspection() async {
    final inspectionId = widget.inspectionId;
    if (inspectionId == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await context.read<AuthService>().getValidAccessToken();
      final inspection = await MaintenanceApiService.getInspection(
        token: token,
        id: inspectionId,
      );

      if (!mounted) return;

      setState(() {
        _inspection = inspection;
        _syncFromInspection(inspection);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadBranches() async {
    try {
      setState(() {
        _isLoadingBranches = true;
      });

      final token = await context.read<AuthService>().getValidAccessToken();
      final branches = await MaintenanceApiService.getAvailableBranches(
        token: token,
      );

      if (!mounted) return;

      setState(() {
        _branches = branches;
        if (_inspection != null) {
          _syncBranchSelection(_inspection!);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _branches = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBranches = false;
        });
      }
    }
  }

  void _syncFromInspection(MaintenanceInspection inspection) {
    _equipmentController.text = inspection.equipment;
    _inspectionInstitutionController.text = inspection.inspectionInstitution;
    _contactInfoController.text = inspection.contactInfo ?? '';
    _notesController.text = inspection.notes ?? '';
    _inspectionType = inspection.inspectionType.isNotEmpty
        ? inspection.inspectionType
        : 'Kalibratie';
    _selfContact = inspection.selfContact;
    _status = _mapBackendStatusToFrontend(inspection.status);
    _lastInspectionDate = inspection.lastInspectionDate;
    _dueDate = inspection.dueDate;

    final (frequencyValue, frequencyUnit) = _parseFrequency(
      inspection.frequency,
    );
    _frequencyValueController.text = frequencyValue.toString();
    _frequencyUnit = frequencyUnit;

    _syncBranchSelection(inspection);
  }

  void _syncBranchSelection(MaintenanceInspection inspection) {
    _selectedBranchIds.clear();
    for (final branch in _branches) {
      if (inspection.branches.contains(branch.name)) {
        _selectedBranchIds.add(branch.id);
      }
    }
  }

  void _startEditing() {
    final inspection = _inspection;
    if (inspection == null) return;

    setState(() {
      _editing = true;
      _equipmentError = null;
      _inspectionInstitutionError = null;
      _branchesError = null;
      _syncFromInspection(inspection);
    });
  }

  void _cancelEditing() {
    final inspection = _inspection;
    if (inspection == null) return;

    setState(() {
      _editing = false;
      _equipmentError = null;
      _inspectionInstitutionError = null;
      _branchesError = null;
      _syncFromInspection(inspection);
    });
  }

  MaintenanceInspectionForm _buildForm() {
    final form = MaintenanceInspectionForm();
    form.equipment = _equipmentController.text.trim();
    form.inspectionType = _inspectionType.trim().isEmpty
        ? 'Kalibratie'
        : _inspectionType.trim();
    form.inspectionInstitution = _inspectionInstitutionController.text.trim();
    form.contactInfo = _contactInfoController.text.trim();
    form.frequencyValue =
        int.tryParse(_frequencyValueController.text.trim()) ?? 1;
    form.frequencyUnit = _frequencyUnit;
    form.selfContact = _selfContact;
    form.selectedBranchIds = _resolvedBranchIds();
    form.lastInspectionDate = _lastInspectionDate;
    form.nextInspectionDate = _dueDate;
    form.status = _mapFrontendStatusToBackend(_status);
    form.notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();
    return form;
  }

  List<int> _resolvedBranchIds() {
    if (_selectedBranchIds.isNotEmpty) {
      return _selectedBranchIds.toList();
    }

    final inspection = _inspection;
    if (inspection == null) return <int>[];

    return _branches
        .where((branch) => inspection.branches.contains(branch.name))
        .map((branch) => branch.id)
        .toList();
  }

  (int, String) _parseFrequency(String value) {
    final match = RegExp(
      r'^Elke\s+(\d+)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) {
      return (1, 'Jaar');
    }

    final frequencyValue = int.tryParse(match.group(1) ?? '') ?? 1;
    final frequencyUnit = (match.group(2) ?? 'Jaar').trim();
    return (frequencyValue, frequencyUnit.isEmpty ? 'Jaar' : frequencyUnit);
  }

  Future<void> _showAddInspectionTypeDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nieuw keuringstype toevoegen'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Bijvoorbeeld: Kwaliteitscontrole, Inspectie, etc.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Toevoegen'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        _inspectionType = result;
      });
    }
    controller.dispose();
  }

  List<DropdownMenuItem<String>> _inspectionTypeItems() {
    const defaultTypes = ['Kalibratie', 'Controle', 'Revisie'];
    final types = <String>[
      ...defaultTypes,
      if (_inspectionType.trim().isNotEmpty &&
          !defaultTypes.contains(_inspectionType))
        _inspectionType,
    ];

    return [
      ...types.map((type) => DropdownMenuItem(value: type, child: Text(type))),
      const DropdownMenuItem(
        value: 'new',
        child: Text('+ Nieuw type toevoegen'),
      ),
    ];
  }

  Future<void> _save() async {
    final inspection = _inspection;
    if (inspection == null) return;

    final equipment = _equipmentController.text.trim();
    final inspectionInstitution = _inspectionInstitutionController.text.trim();

    final missing = <String>[];
    if (equipment.isEmpty) missing.add('Toestel / Installatie');
    if (inspectionInstitution.isEmpty) missing.add('Naam keurinstelling');
    if (_resolvedBranchIds().isEmpty) missing.add('Vestiging');

    if (missing.isNotEmpty) {
      setState(() {
        _equipmentError = missing.contains('Toestel / Installatie')
            ? 'Verplicht'
            : null;
        _inspectionInstitutionError = missing.contains('Naam keurinstelling')
            ? 'Verplicht'
            : null;
        _branchesError = missing.contains('Vestiging')
            ? 'Kies minstens één vestiging'
            : null;
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final token = await context.read<AuthService>().getValidAccessToken();
      final updated = await MaintenanceApiService.updateInspection(
        token: token,
        id: inspection.id,
        form: _buildForm(),
      );

      if (!mounted) return;

      setState(() {
        _inspection = updated;
        _editing = false;
        _syncFromInspection(updated);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    final inspection = _inspection;
    if (inspection == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Onderhoud/keuring verwijderen?'),
        content: const Text(
          'Dit onderhouds- of keuringsitem wordt definitief verwijderd. Dit kun je niet ongedaan maken.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Verwijderen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kDanger,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final token = await context.read<AuthService>().getValidAccessToken();
      await MaintenanceApiService.deleteInspection(
        token: token,
        id: inspection.id,
      );
      if (!mounted) return;
      widget.onClose();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Onderhoud/keuring verwijderd.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Build
  // ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final inspection = _inspection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _isLoading || (inspection == null && _isLoadingBranches)
              ? const Center(child: CircularProgressIndicator())
              : _error != null && inspection == null
              ? _ErrorView(message: _error!, onRetry: _loadInspection)
              : inspection == null
              ? const Center(child: Text('Item niet beschikbaar'))
              : Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: SizedBox.expand(
                    child: _buildMainCard(context, inspection),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMainCard(
    BuildContext context,
    MaintenanceInspection inspection,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadius2xl),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppBreadcrumb(segments: ['Dashboard', 'Onderhoud & Keuringen']),
          const SizedBox(height: 16),
          _buildHeader(inspection),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(child: _buildContent(inspection)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(MaintenanceInspection inspection) {
    final actions = _buildHeaderActions();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final title = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppBackButton(onTap: widget.onClose),
            const SizedBox(width: 14),
            Expanded(child: _buildHeaderTitleBlock(inspection)),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
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

  Widget _buildHeaderTitleBlock(MaintenanceInspection inspection) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Onderhoud / Keuring',
              style: TextStyle(
                fontSize: 13,
                color: kTextTertiary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusBadge(inspection),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '#${inspection.id.toString().padLeft(4, '0')}',
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: kTextPrimary,
            height: 1.1,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildHeaderActions() {
    return [
      if (_editing)
        OutlinedButton(
          onPressed: _isSaving ? null : _cancelEditing,
          child: const Text('Annuleren'),
        ),
      ElevatedButton.icon(
        onPressed: (_isDeleting || _isSaving)
            ? null
            : (_editing ? _save : _startEditing),
        icon: _isSaving
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
      OutlinedButton.icon(
        onPressed: (_isDeleting || _isSaving) ? null : _confirmDelete,
        icon: const Icon(Icons.delete_outline_rounded, size: 18),
        label: const Text('Verwijderen'),
        style: OutlinedButton.styleFrom(
          foregroundColor: kDanger,
          side: const BorderSide(color: kDangerBorder),
        ),
      ),
    ];
  }

  Widget _buildContent(MaintenanceInspection inspection) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResponsiveDetailLayout(inspection),
        if (_error != null && _inspection != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kDangerBg,
              borderRadius: BorderRadius.circular(kRadiusMd),
              border: Border.all(color: kDangerBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: kDanger,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: kDanger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResponsiveDetailLayout(MaintenanceInspection inspection) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1040;
        if (wide) {
          _scheduleMaintenancePrimaryColumnHeightMeasure();

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
                  key: _maintenancePrimaryColumnKey,
                  child: _buildPrimaryColumn(inspection),
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

        if (_maintenancePrimaryColumnHeight != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _maintenancePrimaryColumnHeight = null);
            }
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPrimaryColumn(inspection),
            const SizedBox(height: 18),
            _buildSideColumn(),
          ],
        );
      },
    );
  }

  void _scheduleMaintenancePrimaryColumnHeightMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final renderBox =
          _maintenancePrimaryColumnKey.currentContext?.findRenderObject()
              as RenderBox?;
      final height = renderBox?.size.height;
      if (height == null || height <= 0) return;

      final current = _maintenancePrimaryColumnHeight;
      if (current != null && (current - height).abs() < 0.5) return;

      setState(() {
        _maintenancePrimaryColumnHeight = height;
      });
    });
  }

  Widget _buildPrimaryColumn(MaintenanceInspection inspection) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildKeuringPanel(inspection),
        const SizedBox(height: 16),
        _buildPlanningPanel(inspection),
        const SizedBox(height: 16),
        _buildContactPanel(inspection),
      ],
    );
  }

  Widget _buildSideColumn({bool fillHeight = false}) {
    final notesPanel = _buildNotesPanel();
    final height = _maintenancePrimaryColumnHeight;

    if (fillHeight && height != null && height > 0) {
      return SizedBox(height: height, child: notesPanel);
    }

    return notesPanel;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Section panels
  // ───────────────────────────────────────────────────────────────────────

  Widget _buildKeuringPanel(MaintenanceInspection inspection) {
    return AppSectionPanel(
      title: 'Keuring',
      icon: Icons.fact_check_outlined,
      child: _detailGrid([
        _DetailField(
          label: 'Toestel / installatie',
          readValue: _displayValue(_equipmentController.text),
          editor: _buildTextEditor(
            _equipmentController,
            error: _equipmentError,
            hint: 'Bijv. Heftruck, compressor',
          ),
          wide: true,
        ),
        _DetailField(
          label: 'Keurtype',
          readValue: _displayValue(_inspectionType),
          editor: _buildInspectionTypeEditor(),
        ),
        _DetailField(
          label: 'Keurinstelling',
          readValue: _displayValue(_inspectionInstitutionController.text),
          editor: _buildTextEditor(
            _inspectionInstitutionController,
            error: _inspectionInstitutionError,
            hint: 'Bijv. SGS, Vinçotte',
          ),
        ),
        _DetailField(
          label: 'Status',
          readValue: _getStatusLabel(_status),
          editor: _buildStatusEditor(),
        ),
      ]),
    );
  }

  Widget _buildPlanningPanel(MaintenanceInspection inspection) {
    return AppSectionPanel(
      title: 'Planning',
      icon: Icons.event_outlined,
      child: _detailGrid([
        _DetailField(
          label: 'Frequentie',
          readValue: _formatFrequencyLabel(),
          editor: _buildFrequencyEditor(),
        ),
        _DetailField(
          label: 'Laatste keuring',
          readValue: _formatDate(_lastInspectionDate),
          editor: _buildDateEditor(
            value: _lastInspectionDate,
            onChanged: (date) => setState(() => _lastInspectionDate = date),
            hint: 'Niet ingevuld',
          ),
        ),
        _DetailField(
          label: 'Keuren voor',
          readValue: _formatDate(_dueDate),
          editor: _buildDateEditor(
            value: _dueDate,
            onChanged: (date) => setState(() => _dueDate = date),
            hint: 'Niet ingevuld',
          ),
        ),
      ]),
    );
  }

  Widget _buildContactPanel(MaintenanceInspection inspection) {
    return AppSectionPanel(
      title: 'Contact & vestigingen',
      icon: Icons.business_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabeledField(
            label: 'Vestigingen',
            error: _editing ? _branchesError : null,
            child: _editing
                ? _buildBranchEditor()
                : _buildBranchReadOnly(inspection),
          ),
          const SizedBox(height: 16),
          _detailGrid([
            _DetailField(
              label: 'Contactinfo',
              readValue: _displayValue(_contactInfoController.text),
              editor: _buildTextEditor(
                _contactInfoController,
                hint: 'Naam, e-mail of telefoon',
              ),
              wide: true,
            ),
            _DetailField(
              label: 'Zelf contact opnemen',
              readValue: _selfContact ? 'Ja' : 'Nee',
              editor: _buildSelfContactEditor(),
              wide: true,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildNotesPanel() {
    return AppSectionPanel(
      title: 'Opmerkingen',
      icon: Icons.notes_outlined,
      child: _editing
          ? _buildTextEditor(
              _notesController,
              maxLines: 5,
              hint: 'Voeg opmerkingen toe...',
            )
          : _buildNotesReadOnly(),
    );
  }

  Widget _buildNotesReadOnly() {
    final notes = _notesController.text.trim();
    final isEmpty = notes.isEmpty;
    return Text(
      isEmpty ? 'Geen opmerkingen toegevoegd.' : notes,
      style: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w800,
        color: isEmpty ? kTextMuted : Colors.black,
        height: 1.5,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Field editors / read-only renderers
  // ───────────────────────────────────────────────────────────────────────

  Widget _detailGrid(List<_DetailField> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 20.0;
        const minItemWidth = 220.0;
        final columns = ((constraints.maxWidth + gap) / (minItemWidth + gap))
            .floor()
            .clamp(1, 3);
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: 16,
          children: fields.map((field) {
            final width = field.wide ? constraints.maxWidth : itemWidth;
            return SizedBox(
              width: width,
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

  Widget _buildTextEditor(
    TextEditingController controller, {
    int maxLines = 1,
    String? hint,
    String? error,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: _inputDecoration(hint: hint, errorText: error),
    );
  }

  Widget _buildInspectionTypeEditor() {
    return DropdownButtonFormField<String>(
      initialValue: _inspectionType,
      isExpanded: true,
      borderRadius: BorderRadius.circular(kRadiusMd),
      dropdownColor: kSurface,
      decoration: _inputDecoration(),
      items: _inspectionTypeItems(),
      onChanged: (value) {
        if (value == null) return;
        if (value == 'new') {
          _showAddInspectionTypeDialog();
          return;
        }
        setState(() {
          _inspectionType = value;
        });
      },
    );
  }

  Widget _buildStatusEditor() {
    return DropdownButtonFormField<String?>(
      initialValue: _status,
      isExpanded: true,
      borderRadius: BorderRadius.circular(kRadiusMd),
      dropdownColor: kSurface,
      decoration: _inputDecoration(),
      items: const [
        DropdownMenuItem(value: null, child: Text('Geen')),
        DropdownMenuItem(value: 'In uitvoering', child: Text('In uitvoering')),
        DropdownMenuItem(
          value: 'Nog niet uitgevoerd',
          child: Text('Nog niet uitgevoerd'),
        ),
        DropdownMenuItem(value: 'Uitgevoerd', child: Text('Uitgevoerd')),
      ],
      onChanged: (value) {
        setState(() {
          _status = value;
        });
      },
    );
  }

  Widget _buildFrequencyEditor() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _frequencyValueController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration(),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            initialValue: _frequencyUnit,
            isExpanded: true,
            borderRadius: BorderRadius.circular(kRadiusMd),
            dropdownColor: kSurface,
            decoration: _inputDecoration(),
            items: const [
              DropdownMenuItem(value: 'Jaar', child: Text('Jaar')),
              DropdownMenuItem(value: 'Maand', child: Text('Maand')),
              DropdownMenuItem(value: 'Week', child: Text('Week')),
              DropdownMenuItem(value: 'Dag', child: Text('Dag')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _frequencyUnit = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateEditor({
    required DateTime? value,
    required ValueChanged<DateTime> onChanged,
    String? hint,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: InputDecorator(
        decoration: _inputDecoration().copyWith(
          suffixIcon: const Icon(
            Icons.calendar_today_outlined,
            size: 18,
            color: kTextTertiary,
          ),
        ),
        child: Text(
          value != null ? _formatDate(value) : (hint ?? 'Kies datum'),
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            color: value == null ? kTextMuted : kTextPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildBranchEditor() {
    if (_isLoadingBranches) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kSurfaceMuted,
          borderRadius: BorderRadius.circular(kRadiusMd),
          border: Border.all(color: kBorder),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Vestigingen laden...'),
          ],
        ),
      );
    }

    if (_branches.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kSurfaceMuted,
          borderRadius: BorderRadius.circular(kRadiusMd),
          border: Border.all(color: kBorder),
        ),
        child: const Text(
          'Geen vestigingen beschikbaar.',
          style: TextStyle(color: kTextMuted, fontWeight: FontWeight.w500),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: kBorder),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _branches.map((branch) {
          final selected = _selectedBranchIds.contains(branch.id);
          return FilterChip(
            label: Text(branch.name),
            selected: selected,
            selectedColor: kBrandGreenSoft,
            backgroundColor: kSurfaceMuted,
            side: BorderSide(color: selected ? kBrandGreenDark : kBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadiusPill),
            ),
            onSelected: (isSelected) {
              setState(() {
                if (isSelected) {
                  _selectedBranchIds.add(branch.id);
                  if (_branchesError != null && _selectedBranchIds.isNotEmpty) {
                    _branchesError = null;
                  }
                } else {
                  _selectedBranchIds.remove(branch.id);
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBranchReadOnly(MaintenanceInspection inspection) {
    if (inspection.branches.isEmpty) {
      return const _ReadOnlyValue(value: '-');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: inspection.branches
          .map(
            (branch) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: kBrandGreenSubtle,
                borderRadius: BorderRadius.circular(kRadiusPill),
                border: Border.all(color: kBrandGreenSoft),
              ),
              child: Text(
                branch,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kBrandGreenDeep,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSelfContactEditor() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: kBorder),
      ),
      child: SwitchListTile.adaptive(
        value: _selfContact,
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'Zelf contact opnemen',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: kTextPrimary,
          ),
        ),
        activeThumbColor: kBrandGreen,
        onChanged: (value) {
          setState(() {
            _selfContact = value;
          });
        },
      ),
    );
  }

  InputDecoration _inputDecoration({String? errorText, String? hint}) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: kSurface,
      hintText: hint,
      errorText: errorText,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kDanger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: kDanger, width: 1.6),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Formatting & status helpers
  // ───────────────────────────────────────────────────────────────────────

  String _displayValue(String? value) {
    final normalized = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized == null || normalized.isEmpty) {
      return '-';
    }
    return normalized;
  }

  String _formatFrequencyLabel() {
    final value = _frequencyValueController.text.trim();
    final parsedValue = value.isEmpty ? '1' : value;
    return 'Elke $parsedValue $_frequencyUnit';
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Niet ingevuld';

    final localValue = value.toLocal();
    final day = localValue.day.toString().padLeft(2, '0');
    final month = localValue.month.toString().padLeft(2, '0');
    return '$day/$month/${localValue.year}';
  }

  String _getStatusLabel(String? status) {
    if (status == null || status.trim().isEmpty) {
      return 'Geen';
    }

    switch (status.trim().toLowerCase()) {
      case 'none':
      case 'geen':
        return 'Geen';
      case 'open':
        return 'In uitvoering';
      case 'closed':
      case 'executed':
      case 'done':
        return 'Uitgevoerd';
      case 'pending':
      case 'not executed':
      case 'nog niet uitgevoerd':
        return 'Nog niet uitgevoerd';
      default:
        return status.trim();
    }
  }

  String? _mapBackendStatusToFrontend(String? status) {
    if (status == null || status.trim().isEmpty) {
      return null;
    }

    final trimmedStatus = status.trim().toLowerCase();
    switch (trimmedStatus) {
      case 'none':
      case 'geen':
        return 'Geen';
      case 'open':
        return 'In uitvoering';
      case 'closed':
      case 'executed':
      case 'done':
        return 'Uitgevoerd';
      case 'pending':
      case 'not executed':
      case 'nog niet uitgevoerd':
        return 'Nog niet uitgevoerd';
      default:
        return status;
    }
  }

  String? _mapFrontendStatusToBackend(String? status) {
    if (status == null || status.trim().isEmpty) {
      return null;
    }

    final trimmedStatus = status.trim();
    switch (trimmedStatus) {
      case 'In uitvoering':
        return 'Open';
      case 'Uitgevoerd':
        return 'Closed';
      case 'Nog niet uitgevoerd':
        return 'Pending';
      case 'Geen':
        return null;
      default:
        return null;
    }
  }

  Widget _buildStatusBadge(MaintenanceInspection inspection) {
    final mappedStatus = _mapBackendStatusToFrontend(inspection.status);
    if (mappedStatus == null ||
        mappedStatus.isEmpty ||
        mappedStatus == 'Geen') {
      return const AppStatusPill(
        label: 'Geen status',
        tone: AppStatusTone.neutral,
      );
    }

    AppStatusTone tone;
    switch (mappedStatus) {
      case 'Uitgevoerd':
        tone = AppStatusTone.success;
        break;
      case 'In uitvoering':
        tone = AppStatusTone.info;
        break;
      case 'Nog niet uitgevoerd':
        tone = AppStatusTone.danger;
        break;
      default:
        tone = AppStatusTone.neutral;
    }

    return AppStatusPill(label: mappedStatus, tone: tone);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

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
  const _LabeledField({required this.label, required this.child, this.error});

  final String label;
  final Widget child;
  final String? error;

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
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: const TextStyle(
              fontSize: 12,
              color: kDanger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: kDanger, size: 36),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Opnieuw proberen'),
            ),
          ],
        ),
      ),
    );
  }
}
