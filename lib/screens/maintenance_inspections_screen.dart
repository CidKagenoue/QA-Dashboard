import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/branch.dart';
import '../models/maintenance_inspection_form.dart';
import '../models/maintenance_inspections.dart';
import '../services/auth_service.dart';
import '../services/maintenance_api_service.dart';

class MaintenanceInspectionsScreen extends StatefulWidget {
  const MaintenanceInspectionsScreen({super.key});

  @override
  State<MaintenanceInspectionsScreen> createState() =>
      _MaintenanceInspectionsScreenState();
}

class _MaintenanceInspectionsScreenState
    extends State<MaintenanceInspectionsScreen> {
  List<MaintenanceInspection> allInspections = [];
  List<MaintenanceInspection> filteredInspections = [];
  List<Branch> availableBranches = [];
  String searchQuery = '';
  bool showFilters = false;
  bool isLoading = true;
  String? loadError;
  bool _didRequestLoad = false;

  // Filter state
  String? selectedStatus;
  String? selectedInspectionType;
  Set<int> selectedFilterBranches = {};
  DateTime? filterDateFrom;
  DateTime? filterDateTo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didRequestLoad) {
      _didRequestLoad = true;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final authService = context.read<AuthService>();
      final token = await authService.getValidAccessToken();

      final results = await Future.wait([
        MaintenanceApiService.getInspections(token: token),
        MaintenanceApiService.getAvailableBranches(token: token),
      ]);

      if (!mounted) {
        return;
      }

      allInspections = results[0] as List<MaintenanceInspection>;
      availableBranches = results[1] as List<Branch>;
      _filterInspections();
    } catch (error) {
      if (!mounted) {
        return;
      }

      loadError = error.toString().replaceFirst('Exception: ', '');
      filteredInspections = [];
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _filterInspections() {
    filteredInspections = allInspections.where((inspection) {
      final query = searchQuery.toLowerCase();
      
      // Search filter
      final matchesSearch = inspection.equipment.toLowerCase().contains(query) ||
          inspection.inspectionInstitution.toLowerCase().contains(query) ||
          inspection.locations.any((location) => location.toLowerCase().contains(query));
      
      if (!matchesSearch) return false;

      // Status filter
      if (selectedStatus != null && inspection.status != selectedStatus) {
        return false;
      }

      // Inspection type filter
      if (selectedInspectionType != null && 
          inspection.inspectionType != selectedInspectionType) {
        return false;
      }

      // Branch filter
      if (selectedFilterBranches.isNotEmpty) {
        final hasBranch = selectedFilterBranches.any((branchId) {
          final branch = availableBranches.firstWhere(
            (b) => b.id == branchId,
            orElse: () => Branch(id: -1, name: '', locations: []),
          );
          return inspection.locations.contains(branch.name);
        });
        if (!hasBranch) return false;
      }

      // Date range filter
      if (filterDateFrom != null && inspection.dueDate.isBefore(filterDateFrom!)) {
        return false;
      }
      if (filterDateTo != null && inspection.dueDate.isAfter(filterDateTo!)) {
        return false;
      }

      return true;
    }).toList();
    setState(() {});
  }

  void _showAddDialog() {
    final authService = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);

    showDialog<MaintenanceInspectionForm>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MaintenanceInspectionDialog(
        availableBranches: availableBranches,
      ),
    ).then((result) async {
      if (result == null) {
        return;
      }

      try {
        final token = await authService.getValidAccessToken();
        await MaintenanceApiService.createInspection(token: token, form: result);
        if (!mounted) {
          return;
        }
        await _loadData();
        messenger.showSnackBar(
          const SnackBar(content: Text('Onderhoud/keuring aangemaakt.')),
        );
      } catch (error) {
        if (!mounted) {
          return;
        }
        messenger.showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Color _getDateColor(DateTime date) {
    final now = DateTime.now();
    final daysUntilDue = date.difference(now).inDays;

    if (daysUntilDue < 0) {
      return Colors.red;
    } else if (daysUntilDue < 30) {
      return Colors.orange;
    }
    return Colors.grey[600]!;
  }

  @override
  Widget build(BuildContext context) {
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
                'Onderhoud & Keuringen',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: isLoading ? null : _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Nieuw'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8BC34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () => setState(() => showFilters = !showFilters),
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onChanged: (value) {
                        searchQuery = value;
                        _filterInspections();
                      },
                    ),
                  ),
                ],
              ),
              if (showFilters) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Status',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                   initialValue: selectedStatus,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text('Alle'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Open',
                                      child: Text('Open'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Closed',
                                      child: Text('Gesloten'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() => selectedStatus = value);
                                    _filterInspections();
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Keuringstype',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                   initialValue: selectedInspectionType,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text('Alle'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Kalibratie',
                                      child: Text('Kalibratie'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Controle',
                                      child: Text('Controle'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Revisie',
                                      child: Text('Revisie'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() => selectedInspectionType = value);
                                    _filterInspections();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Vestigingen',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableBranches.map((branch) {
                          final isSelected = selectedFilterBranches.contains(branch.id);
                          return FilterChip(
                            label: Text(branch.name),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  selectedFilterBranches.add(branch.id);
                                } else {
                                  selectedFilterBranches.remove(branch.id);
                                }
                              });
                              _filterInspections();
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      if (selectedStatus != null ||
                          selectedInspectionType != null ||
                          selectedFilterBranches.isNotEmpty ||
                          filterDateFrom != null ||
                          filterDateTo != null)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              selectedStatus = null;
                              selectedInspectionType = null;
                              selectedFilterBranches.clear();
                              filterDateFrom = null;
                              filterDateTo = null;
                            });
                            _filterInspections();
                          },
                          icon: const Icon(Icons.clear, size: 18),
                          label: const Text('Filters wissen'),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Expanded(
                child: loadError != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              loadError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.red[700]),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadData,
                              child: const Text('Opnieuw proberen'),
                            ),
                          ],
                        ),
                      )
                    : isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SizedBox(
                              width: double.infinity,
                              child: DataTable(
                                headingRowHeight: 56,
                                dataRowMinHeight: 54,
                                dataRowMaxHeight: 62,
                                columnSpacing: 32,
                                horizontalMargin: 24,
                                headingRowColor: WidgetStateColor.resolveWith(
                                  (states) => const Color(0xFFF5F5F5),
                                ),
                                columns: const [
                                  DataColumn(label: Text('Toestel/Instalatie')),
                                  DataColumn(label: Text('Keurinstelling')),
                                  DataColumn(label: Text('Vestigingen')),
                                  DataColumn(label: Text('Frequentie')),
                                  DataColumn(label: Text('Keuren voor')),
                                ],
                                rows: filteredInspections.map((inspection) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(inspection.equipment)),
                                      DataCell(Text(inspection.inspectionInstitution)),
                                      DataCell(Text(inspection.locations.join(', '))),
                                      DataCell(Text(inspection.frequency)),
                                      DataCell(
                                        Text(
                                          _formatDate(inspection.dueDate),
                                          style: TextStyle(
                                            color: _getDateColor(inspection.dueDate),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
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
}

class _MaintenanceInspectionDialog extends StatefulWidget {
  const _MaintenanceInspectionDialog({required this.availableBranches});

  final List<Branch> availableBranches;

  @override
  State<_MaintenanceInspectionDialog> createState() =>
      _MaintenanceInspectionDialogState();
}

class _MaintenanceInspectionDialogState
    extends State<_MaintenanceInspectionDialog> {
  final TextEditingController equipmentController = TextEditingController();
  final TextEditingController institutionController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController lastInspectionController = TextEditingController();
  final TextEditingController dueDateController = TextEditingController();

  String inspectionType = 'Kalibratie';
  int frequencyValue = 5;
  String frequencyUnit = 'Jaar';
  bool selfContact = false;
  final Set<int> selectedLocationIds = {};
  final ScrollController _locationsScrollController = ScrollController();
  DateTime? lastInspectionDate;
  DateTime? dueDate;

  List<Branch> get branches => widget.availableBranches;

  @override
  void initState() {
    super.initState();
    if (branches.isNotEmpty) {
      selectedLocationIds.add(branches.first.id);
    }
  }

  @override
  void dispose() {
    equipmentController.dispose();
    institutionController.dispose();
    contactController.dispose();
    lastInspectionController.dispose();
    dueDateController.dispose();
    _locationsScrollController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2025, 10, 26),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        if (controller == lastInspectionController) {
          lastInspectionDate = pickedDate;
        } else {
          dueDate = pickedDate;
        }
      });
      controller.text =
          '${pickedDate.day.toString().padLeft(2, '0')}/${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
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
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Nieuwe Onderhoud/Keuring Aanmaken',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vul de onderstaande gegevens in om een nieuwe onderhouds- of keuringslijn toe te voegen.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
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
                                  _buildLabel('Toestel/Instalatie *'),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: equipmentController,
                                    decoration: _inputDecoration('Drukvat compressor'),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildLabel('Naam Keurinstelling *'),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: institutionController,
                                    decoration: _inputDecoration('Vinçotte'),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildLabel('Contactgegevens'),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: contactController,
                                    decoration: _inputDecoration('buildingsalesnorth@vincotte.be'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Type Keuring *'),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue: inspectionType,
                                    isExpanded: true,
                                    items: const [
                                      DropdownMenuItem(value: 'Kalibratie', child: Text('Kalibratie')),
                                      DropdownMenuItem(value: 'Controle', child: Text('Controle')),
                                      DropdownMenuItem(value: 'Revisie', child: Text('Revisie')),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => inspectionType = value);
                                      }
                                    },
                                    decoration: _dropdownDecoration(),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildLabel('Frequentie'),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(minWidth: 64, maxWidth: 120),
                                        child: DropdownButtonFormField<int>(
                                          isExpanded: true,
                                          initialValue: frequencyValue,
                                          items: List.generate(
                                            12,
                                            (index) => DropdownMenuItem(
                                              value: index + 1,
                                              child: Text('${index + 1}'),
                                            ),
                                          ),
                                          onChanged: (value) {
                                            if (value != null) {
                                              setState(() => frequencyValue = value);
                                            }
                                          },
                                          decoration: _dropdownDecoration(),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          initialValue: frequencyUnit,
                                          items: const [
                                            DropdownMenuItem(value: 'Jaar', child: Text('Jaar')),
                                            DropdownMenuItem(value: 'Maand', child: Text('Maand')),
                                            DropdownMenuItem(value: 'Dag', child: Text('Dag')),
                                          ],
                                          onChanged: (value) {
                                            if (value != null) {
                                              setState(() => frequencyUnit = value);
                                            }
                                          },
                                          decoration: _dropdownDecoration(),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildLabel('Zelf Contacteren?'),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      ChoiceChip(
                                        label: const Text('Ja'),
                                        selected: selfContact,
                                        onSelected: (_) => setState(() => selfContact = true),
                                      ),
                                      ChoiceChip(
                                        label: const Text('Nee'),
                                        selected: !selfContact,
                                        onSelected: (_) => setState(() => selfContact = false),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      // single column layout for narrow widths
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Toestel/Instalatie *'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: equipmentController,
                            decoration: _inputDecoration('Drukvat compressor'),
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('Type Keuring *'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: inspectionType,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 'Kalibratie', child: Text('Kalibratie')),
                              DropdownMenuItem(value: 'Controle', child: Text('Controle')),
                              DropdownMenuItem(value: 'Revisie', child: Text('Revisie')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => inspectionType = value);
                              }
                            },
                            decoration: _dropdownDecoration(),
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('Naam Keurinstelling *'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: institutionController,
                            decoration: _inputDecoration('Vinçotte'),
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('Contactgegevens'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: contactController,
                            decoration: _inputDecoration('buildingsalesnorth@vincotte.be'),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildLabel('Vestigingen *'),
                  const SizedBox(height: 8),
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFD8D8D8)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: branches.isEmpty
                        ? const Center(
                            child: Text('Geen vestigingen beschikbaar.'),
                          )
                        : Scrollbar(
                            controller: _locationsScrollController,
                            child: ListView(
                              controller: _locationsScrollController,
                              padding: EdgeInsets.zero,
                              children: branches.map((branch) {
                                final selected = selectedLocationIds.contains(branch.id);
                                return CheckboxListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                  title: Text(
                                    branch.name,
                                    style: TextStyle(
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                  value: selected,
                                  onChanged: (isChecked) {
                                    setState(() {
                                      if (isChecked == true) {
                                        selectedLocationIds.add(branch.id);
                                      } else {
                                        selectedLocationIds.remove(branch.id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Datum laatste keuring'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: lastInspectionController,
                              readOnly: true,
                              decoration: _dateDecoration(
                                onTap: () => _pickDate(lastInspectionController),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Keuren vóór'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: dueDateController,
                              readOnly: true,
                              decoration: _dateDecoration(
                                onTap: () => _pickDate(dueDateController),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Annuleren', style: TextStyle(color: Colors.grey[800])),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8BC34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                        onPressed: () {
                          // Parse dates from text fields if not already set
                          DateTime? parsedLastInspection = lastInspectionDate;
                          DateTime? parsedDueDate = dueDate;

                          if (parsedLastInspection == null &&
                              lastInspectionController.text.trim().isNotEmpty) {
                            try {
                              final parts = lastInspectionController.text.split('/');
                              if (parts.length == 3) {
                                parsedLastInspection = DateTime(
                                  int.parse(parts[2]),
                                  int.parse(parts[1]),
                                  int.parse(parts[0]),
                                );
                              }
                            } catch (_) {}
                          }

                          if (parsedDueDate == null &&
                              dueDateController.text.trim().isNotEmpty) {
                            try {
                              final parts = dueDateController.text.split('/');
                              if (parts.length == 3) {
                                parsedDueDate = DateTime(
                                  int.parse(parts[2]),
                                  int.parse(parts[1]),
                                  int.parse(parts[0]),
                                );
                              }
                            } catch (_) {}
                          }

                          if (equipmentController.text.trim().isEmpty ||
                              institutionController.text.trim().isEmpty ||
                              selectedLocationIds.isEmpty ||
                              parsedLastInspection == null ||
                              parsedDueDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Vul alle verplichte velden in en kies minstens één vestiging.'),
                              ),
                            );
                            return;
                          }
                          final form = MaintenanceInspectionForm()
                            ..equipment = equipmentController.text.trim()
                            ..inspectionType = inspectionType
                            ..inspectionInstitution = institutionController.text.trim()
                            ..contactInfo = contactController.text.trim()
                            ..frequencyValue = frequencyValue
                            ..frequencyUnit = frequencyUnit
                            ..selfContact = selfContact
                            ..selectedBranchIds = selectedLocationIds.toList()
                            ..lastInspectionDate = parsedLastInspection
                            ..nextInspectionDate = parsedDueDate;

                          Navigator.pop(context, form);
                        },
                        child: const Text('Aanmaken'),
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
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD8D8D8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF8BC34A)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD8D8D8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF8BC34A)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  InputDecoration _dateDecoration({required VoidCallback onTap}) {
    return InputDecoration(
      hintText: '26/10/2025',
      filled: true,
      fillColor: Colors.white,
      suffixIcon: IconButton(
        icon: const Icon(Icons.calendar_month_outlined),
        onPressed: onTap,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD8D8D8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF8BC34A)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
