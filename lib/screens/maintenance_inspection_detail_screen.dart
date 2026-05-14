import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/branch.dart';
import '../models/maintenance_inspection_form.dart';
import '../models/maintenance_inspections.dart';
import '../services/auth_service.dart';
import '../services/maintenance_api_service.dart';

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

      if (!mounted) {
        return;
      }

      setState(() {
        _inspection = inspection;
        _syncFromInspection(inspection);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

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

      if (!mounted) {
        return;
      }

      setState(() {
        _branches = branches;
        if (_inspection != null) {
          _syncBranchSelection(_inspection!);
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
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
    // Map backend status to frontend Dutch values
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
      if (inspection.locations.contains(branch.name)) {
        _selectedBranchIds.add(branch.id);
      }
    }
  }

  void _startEditing() {
    final inspection = _inspection;
    if (inspection == null) {
      return;
    }

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
    if (inspection == null) {
      return;
    }

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
    // Map frontend Dutch status back to backend English values
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
    if (inspection == null) {
      return <int>[];
    }

    return _branches
        .where((branch) => inspection.locations.contains(branch.name))
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8CC63F),
              foregroundColor: Colors.white,
            ),
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
      ...types.map(
        (type) => DropdownMenuItem(value: type, child: Text(type)),
      ),
      const DropdownMenuItem(
        value: 'new',
        child: Text('+ Nieuw type toevoegen'),
      ),
    ];
  }

  Future<void> _save() async {
    final inspection = _inspection;
    if (inspection == null) {
      return;
    }

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

      if (!mounted) {
        return;
      }

      setState(() {
        _inspection = updated;
        _editing = false;
        _syncFromInspection(updated);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
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
    if (inspection == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Onderhoud/keuring verwijderen'),
        content: const Text(
          'Weet je zeker dat je dit onderhouds- of keuringsitem wilt verwijderen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      final token = await context.read<AuthService>().getValidAccessToken();
      await MaintenanceApiService.deleteInspection(
        token: token,
        id: inspection.id,
      );
      if (!mounted) {
        return;
      }
      widget.onClose();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Onderhoud/keuring verwijderd.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
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

  @override
  Widget build(BuildContext context) {
    final inspection = _inspection;

    return Theme(
      data: Theme.of(context).copyWith(
        highlightColor: const Color(0xFFEAF4D9),
        splashColor: const Color(0x338CC63F),
        hoverColor: const Color(0x228CC63F),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isLoadingBranches
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadInspection,
                            child: const Text('Opnieuw proberen'),
                          ),
                        ],
                      ),
                    ),
                  )
                : inspection == null
                ? const Center(child: Text('Pagina nog niet zichtbaar'))
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    child: SizedBox.expand(
                      child: _buildMainCard(context, inspection),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard(
    BuildContext context,
    MaintenanceInspection inspection,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E9DD)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard > Onderhoud & Keuringen',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9CA39A),
              fontWeight: FontWeight.w500,
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
                    Text(
                      'Onderhoud & Keuringen',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF243022),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Onderhoud & Keuringen-detail',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7A62),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID ${inspection.id.toString().padLeft(4, '0')}',
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
                      onPressed: _isSaving ? null : _cancelEditing,
                      child: const Text('Annuleren'),
                    ),
                  TextButton.icon(
                    onPressed: (_isDeleting || _isSaving)
                        ? null
                        : _confirmDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Verwijderen'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFD32F2F),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isDeleting
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
                            _editing
                                ? Icons.save_outlined
                                : Icons.edit_outlined,
                            size: 18,
                          ),
                    label: Text(_editing ? 'Opslaan' : 'Bewerken'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8CC63F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBFCF8),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE4E9DD)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Toestel / Installatie',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7A62),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildEditableField(_equipmentController),
                        const SizedBox(height: 10),
                        _Pill(
                          label: _statusLabel(inspection),
                          background: _statusColor(
                            inspection,
                          ).withValues(alpha: 0.12),
                          foreground: _statusColor(inspection),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE4E9DD), height: 1),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 760;
                        // On wide screens show three fields per row, otherwise full width
                        final columnWidth = wide
                            ? (constraints.maxWidth - 40) / 3
                            : constraints.maxWidth;

                        Widget field(
                          String label,
                          Widget child, {
                          double? width,
                        }) {
                          return SizedBox(
                            width: width ?? columnWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF9CA39A),
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                child,
                                if (label == 'Vestigingen' &&
                                    _branchesError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      _branchesError!,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          );
                        }

                        return Wrap(
                          spacing: 20,
                          runSpacing: 6,
                          children: [
                            // First row: Keurinstelling | Vestigingen | Frequentie
                            field(
                              'Keurinstelling',
                              _buildEditableField(
                                _inspectionInstitutionController,
                              ),
                              width: columnWidth,
                            ),
                            field(
                              'Vestigingen',
                              _buildBranchField(),
                              width: columnWidth,
                            ),
                            field(
                              'Frequentie',
                              _buildFrequencyField(),
                              width: columnWidth,
                            ),

                            // Second row: Laatste keuring | Keuren voor | Keurtype
                            field(
                              'Laatste keuring',
                              _buildDateField(
                                value: _lastInspectionDate,
                                onChanged: (date) =>
                                    setState(() => _lastInspectionDate = date),
                              ),
                              width: columnWidth,
                            ),
                            field(
                              'Keuren voor',
                              _buildDateField(
                                value: _dueDate,
                                onChanged: (date) =>
                                    setState(() => _dueDate = date),
                              ),
                              width: columnWidth,
                            ),
                            field(
                              'Keurtype',
                              _buildInspectionTypeField(),
                              width: columnWidth,
                            ),

                            // Third row: Contactinfo | Zelf contact | Status
                            field(
                              'Contactinfo',
                              _buildEditableField(_contactInfoController),
                              width: columnWidth,
                            ),
                            field(
                              'Zelf contact',
                              _buildSelfContactField(),
                              width: columnWidth,
                            ),
                            field(
                              'Status',
                              _buildStatusField(),
                              width: columnWidth,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Opmerkingen',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF9CA39A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    _buildNotesField(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    if (!_editing) {
      return _buildReadOnlyBox(controller.text);
    }

    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration:
          InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDDE3D2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF8CC63F)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ).copyWith(
            errorText: controller == _equipmentController
                ? _equipmentError
                : (controller == _inspectionInstitutionController
                      ? _inspectionInstitutionError
                      : null),
          ),
    );
  }

  Widget _buildInspectionTypeField() {
    if (!_editing) {
      return _buildReadOnlyBox(_inspectionType);
    }

    return DropdownButtonFormField<String>(
      initialValue: _inspectionType,
      isExpanded: true,
      borderRadius: BorderRadius.circular(16),
      dropdownColor: Colors.white,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF8CC63F)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF8CC63F)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      items: _inspectionTypeItems(),
      onChanged: (value) {
        if (value == null) {
          return;
        }
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

  Widget _buildFrequencyField() {
    if (!_editing) {
      return _buildReadOnlyBox(_formatFrequencyLabel());
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _frequencyValueController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDDE3D2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF8CC63F)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            initialValue: _frequencyUnit,
            isExpanded: true,
            borderRadius: BorderRadius.circular(16),
            dropdownColor: Colors.white,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDDE3D2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF8CC63F)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'Jaar', child: Text('Jaar')),
              DropdownMenuItem(value: 'Maand', child: Text('Maand')),
              DropdownMenuItem(value: 'Week', child: Text('Week')),
              DropdownMenuItem(value: 'Dag', child: Text('Dag')),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _frequencyUnit = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required DateTime? value,
    required ValueChanged<DateTime> onChanged,
  }) {
    final displayValue = _formatDate(value);

    if (!_editing) {
      return _buildReadOnlyBox(displayValue);
    }

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
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDE3D2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF8CC63F)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        child: Text(displayValue),
      ),
    );
  }

  Widget _buildBranchField() {
    if (!_editing) {
      return _buildReadOnlyBox(
        _inspection == null ? '-' : _inspection!.locations.join(', '),
      );
    }

    if (_branches.isEmpty) {
      return _buildReadOnlyBox('Geen vestigingen geladen');
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE3D2)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _branches.map((branch) {
          final selected = _selectedBranchIds.contains(branch.id);
          return FilterChip(
            label: Text(branch.name),
            selected: selected,
            selectedColor: const Color(0xFFEAF4D9),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            onSelected: (isSelected) {
              setState(() {
                if (isSelected) {
                  _selectedBranchIds.add(branch.id);
                  if (_branchesError != null && _selectedBranchIds.isNotEmpty)
                    _branchesError = null;
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

  Widget _buildStatusField() {
    if (!_editing) {
      return _buildReadOnlyBox(_getStatusLabel(_status));
    }

    return DropdownButtonFormField<String?>(
      initialValue: _status,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDDE3D2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF8CC63F)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
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

  Widget _buildSelfContactField() {
    if (!_editing) {
      return _buildReadOnlyBox(_selfContact ? 'Ja' : 'Nee');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDE3D2)),
      ),
      child: SwitchListTile.adaptive(
        value: _selfContact,
        contentPadding: EdgeInsets.zero,
        title: const Text('Zelf contact opnemen'),
        onChanged: (value) {
          setState(() {
            _selfContact = value;
          });
        },
      ),
    );
  }

  Widget _buildNotesField() {
    if (!_editing) {
      final notes = _notesController.text.trim();
      return _buildReadOnlyBox(
        notes.isEmpty ? 'Geen opmerkingen toegevoegd.' : notes,
      );
    }

    return TextField(
      controller: _notesController,
      maxLines: 4,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDDE3D2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF8CC63F)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  String _formatFrequencyLabel() {
    final value = _frequencyValueController.text.trim();
    final parsedValue = value.isEmpty ? '1' : value;
    return 'Elke $parsedValue $_frequencyUnit';
  }

  Widget _buildReadOnlyBox(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      child: Text(
        value.isEmpty ? '-' : value,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF243022),
          height: 1.3,
        ),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Niet ingevuld';
    }

    final localValue = value.toLocal();
    final day = localValue.day.toString().padLeft(2, '0');
    final month = localValue.month.toString().padLeft(2, '0');
    return '$day/$month/${localValue.year}';
  }

  String _statusLabel(MaintenanceInspection inspection) {
    // Map backend English status to Dutch for display
    final mappedStatus = _mapBackendStatusToFrontend(inspection.status);
    if (mappedStatus != null && mappedStatus.isNotEmpty) {
      return mappedStatus;
    }
    return 'Geen';
  }

  String _getStatusLabel(String? status) {
    if (status?.trim().isEmpty ?? true) {
      return 'Geen';
    }

    switch (status!.trim().toLowerCase()) {
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

  /// Map English backend status to Dutch frontend values
  String? _mapBackendStatusToFrontend(String? status) {
    if (status?.trim().isEmpty ?? true) {
      return null;
    }

    final trimmedStatus = status!.trim().toLowerCase();
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
        // If it's already a Dutch value, return it as is
        return status;
    }
  }

  /// Map Dutch frontend status to English backend values
  String? _mapFrontendStatusToBackend(String? status) {
    if (status?.trim().isEmpty ?? true) {
      return null;
    }

    final trimmedStatus = status!.trim();
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

  Color _statusColor(MaintenanceInspection inspection) {
    // Map backend English status to Dutch for color assignment
    final mappedStatus = _mapBackendStatusToFrontend(inspection.status);
    if (mappedStatus == 'Uitgevoerd') {
      return Colors.green;
    }
    if (mappedStatus == 'In uitvoering') {
      return Colors.blue;
    }
    return Colors.grey;
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
        border: Border.all(color: foreground.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
