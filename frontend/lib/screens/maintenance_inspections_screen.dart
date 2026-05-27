import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/branch.dart';
import '../models/maintenance_inspection_form.dart';
import '../models/maintenance_inspections.dart';
import '../services/auth_service.dart';
import '../services/maintenance_api_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'maintenance_inspection_detail_screen.dart';

class MaintenanceInspectionsScreen extends StatefulWidget {
  const MaintenanceInspectionsScreen({super.key, this.initialInspectionId});

  final int? initialInspectionId;

  @override
  State<MaintenanceInspectionsScreen> createState() =>
      _MaintenanceInspectionsScreenState();
}

class _MaintenanceInspectionsScreenState
    extends State<MaintenanceInspectionsScreen> {
  static const String _customInspectionTypesKey = 'customInspectionTypes';
  static const List<String> _defaultInspectionTypes = [
    'Kalibratie',
    'Controle',
    'Revisie',
  ];

  List<MaintenanceInspection> allInspections = [];
  List<MaintenanceInspection> filteredInspections = [];
  List<Branch> availableBranches = [];
  List<String> customInspectionTypes = [];
  MaintenanceInspection? _selectedInspection;
  String searchQuery = '';
  bool isLoading = true;
  String? loadError;
  bool _didRequestLoad = false;
  bool _initialInspectionContextApplied = false;

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
        _loadCustomInspectionTypes(),
      ]);

      if (!mounted) {
        return;
      }

      allInspections = results[0] as List<MaintenanceInspection>;
      availableBranches = results[1] as List<Branch>;
      customInspectionTypes = results[2] as List<String>;
      _filterInspections();
      _applyInitialInspectionContext();
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
      final matchesSearch =
          inspection.equipment.toLowerCase().contains(query) ||
          inspection.inspectionInstitution.toLowerCase().contains(query) ||
          inspection.locations.any(
            (location) => location.toLowerCase().contains(query),
          );

      if (!matchesSearch) return false;

      // Status filter
      if (selectedStatus != null &&
          _getStatusLabel(inspection.status) != selectedStatus) {
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
      if (filterDateFrom != null &&
          inspection.dueDate.isBefore(filterDateFrom!)) {
        return false;
      }
      if (filterDateTo != null && inspection.dueDate.isAfter(filterDateTo!)) {
        return false;
      }

      return true;
    }).toList();
    setState(() {});
  }

  void _applyInitialInspectionContext() {
    if (_initialInspectionContextApplied || !mounted) {
      return;
    }

    final initialInspectionId = widget.initialInspectionId;
    if (initialInspectionId == null) {
      _initialInspectionContextApplied = true;
      return;
    }

    for (final inspection in allInspections) {
      if (inspection.id == initialInspectionId) {
        setState(() {
          _selectedInspection = inspection;
          _initialInspectionContextApplied = true;
        });
        return;
      }
    }

    _initialInspectionContextApplied = true;
  }

  void _openInspectionDetail(MaintenanceInspection inspection) {
    setState(() {
      _selectedInspection = inspection;
    });
  }

  void _closeInspectionDetail() {
    setState(() {
      _selectedInspection = null;
    });
    _loadData();
  }

  void _showAddDialog() {
    final authService = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);

    showDialog<MaintenanceInspectionForm>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MaintenanceInspectionDialog(
        availableBranches: availableBranches,
        inspectionTypes: _inspectionTypes(),
        customInspectionTypes: customInspectionTypes,
        onInspectionTypeAdded: _saveCustomInspectionType,
        onInspectionTypeRenamed: _renameCustomInspectionType,
        onInspectionTypeDeleted: _deleteCustomInspectionType,
      ),
    ).then((result) async {
      if (result == null) {
        return;
      }

      try {
        final token = await authService.getValidAccessToken();
        await MaintenanceApiService.createInspection(
          token: token,
          form: result,
        );
        if (!mounted) {
          return;
        }
        await _loadData();
        await context.read<NotificationService>().loadNotifications(limit: 50);
        await context.read<NotificationService>().refreshUnreadCount();
        messenger.showSnackBar(
          const SnackBar(content: Text('Onderhoud/keuring aangemaakt.')),
        );
      } catch (error) {
        if (!mounted) {
          return;
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
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

  Color _getStatusColor(String? status) {
    switch (_getStatusLabel(status)) {
      case 'Uitgevoerd':
        return Colors.green;
      case 'In uitvoering':
        return Colors.blue;
      case 'Nog niet uitgevoerd':
        return Colors.red;
      default:
        return Colors.grey[600]!;
    }
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

  List<String> _inspectionTypes() {
    final types = <String>{
      ..._defaultInspectionTypes,
      ...allInspections
          .map((inspection) => inspection.inspectionType.trim())
          .where((type) => type.isNotEmpty),
    };
    for (final type in customInspectionTypes) {
      final t = type.trim();
      if (t.isNotEmpty) types.add(t);
    }
    final list = types.toList()..sort();
    return list;
  }

  Future<List<String>> _loadCustomInspectionTypes() async {
    final preferences = await SharedPreferences.getInstance();
    final types = preferences.getStringList(_customInspectionTypesKey) ?? [];
    return types
        .map((type) => type.trim())
        .where((type) => type.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Future<void> _saveCustomInspectionType(String type) async {
    final trimmedType = type.trim();
    if (trimmedType.isEmpty) {
      return;
    }

    final types = {
      ...customInspectionTypes.map((type) => type.trim()),
      trimmedType,
    }.where((type) => type.isNotEmpty).toList()
      ..sort();

    await _persistCustomInspectionTypes(types);
  }

  Future<void> _renameCustomInspectionType(
    String oldType,
    String newType,
  ) async {
    final trimmedOldType = oldType.trim();
    final trimmedNewType = newType.trim();
    if (trimmedOldType.isEmpty || trimmedNewType.isEmpty) {
      return;
    }

    final types = {
      ...customInspectionTypes.map(
        (type) => type.trim() == trimmedOldType ? trimmedNewType : type.trim(),
      ),
      trimmedNewType,
    }.where((type) => type.isNotEmpty).toList()
      ..sort();

    await _persistCustomInspectionTypes(types);
  }

  Future<void> _deleteCustomInspectionType(String type) async {
    final trimmedType = type.trim();
    final types = customInspectionTypes
        .map((type) => type.trim())
        .where((type) => type.isNotEmpty && type != trimmedType)
        .toSet()
        .toList()
      ..sort();

    await _persistCustomInspectionTypes(types);
  }

  Future<void> _persistCustomInspectionTypes(List<String> types) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_customInspectionTypesKey, types);

    if (!mounted) {
      return;
    }
    setState(() {
      customInspectionTypes = types;
    });
  }

  void _showFilterSheet() {
    final inspectionTypes = _inspectionTypes();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void syncAndApply() {
              setState(() {});
              _filterInspections();
              setSheetState(() {});
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filteren',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF243022),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            selectedStatus = null;
                            selectedInspectionType = null;
                            selectedFilterBranches.clear();
                            filterDateFrom = null;
                            filterDateTo = null;
                          });
                          _filterInspections();
                          setSheetState(() {});
                        },
                        child: const Text(
                          'Wis filters',
                          style: TextStyle(color: Color(0xFF6B7A62)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4D5548),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(
                        label: 'Geen',
                        selected: selectedStatus == 'Geen',
                        onTap: () {
                          setState(
                            () => selectedStatus =
                                selectedStatus == 'Geen' ? null : 'Geen',
                          );
                          syncAndApply();
                        },
                      ),
                      _FilterChip(
                        label: 'In uitvoering',
                        selected: selectedStatus == 'In uitvoering',
                        onTap: () {
                          setState(() {
                            selectedStatus = selectedStatus == 'In uitvoering' ? null : 'In uitvoering';
                          });
                          syncAndApply();
                        },
                      ),
                      _FilterChip(
                        label: 'Nog niet uitgevoerd',
                        selected: selectedStatus == 'Nog niet uitgevoerd',
                        onTap: () {
                          setState(() {
                            selectedStatus = selectedStatus == 'Nog niet uitgevoerd' ? null : 'Nog niet uitgevoerd';
                          });
                          syncAndApply();
                        },
                      ),
                      _FilterChip(
                        label: 'Uitgevoerd',
                        selected: selectedStatus == 'Uitgevoerd',
                        onTap: () {
                          setState(
                            () => selectedStatus =
                                selectedStatus == 'Uitgevoerd'
                                ? null
                                : 'Uitgevoerd',
                          );
                          syncAndApply();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Keuringstype',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4D5548),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: inspectionTypes.map((type) {
                      return _FilterChip(
                        label: type,
                        selected: selectedInspectionType == type,
                        onTap: () {
                          setState(
                            () => selectedInspectionType =
                                selectedInspectionType == type ? null : type,
                          );
                          syncAndApply();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Vestigingen',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4D5548),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableBranches.map((branch) {
                      return _FilterChip(
                        label: branch.name,
                        selected: selectedFilterBranches.contains(branch.id),
                        onTap: () {
                          setState(() {
                            if (selectedFilterBranches.contains(branch.id)) {
                              selectedFilterBranches.remove(branch.id);
                            } else {
                              selectedFilterBranches.add(branch.id);
                            }
                          });
                          syncAndApply();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBrandGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text('Toepassen'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInspectionTable({double minHeight = 0, double minWidth = 0}) {
    final rows = filteredInspections
        .map((i) => _buildInspectionDataRow(i))
        .toList();
    final availableWidth = minWidth > 0 ? minWidth - 32 : 980.0;
    final tableWidth = availableWidth > 980 ? availableWidth : 980.0;
    const bottomGap = 16.0;
    final tableHeight = minHeight > 44 ? minHeight - 44 : 384.0;
    const Map<int, TableColumnWidth> columnWidths = {
      0: FlexColumnWidth(2.3),
      1: FlexColumnWidth(2.0),
      2: FlexColumnWidth(2.0),
      3: FlexColumnWidth(1.5),
      4: FlexColumnWidth(1.3),
      5: FlexColumnWidth(1.4),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: bottomGap),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9DD)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              height: tableHeight,
              child: Column(
                children: [
                  Table(
                    columnWidths: columnWidths,
                    children: [_buildInspectionHeaderRow()],
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Table(
                          columnWidths: columnWidths,
                          children: rows,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TableRow _buildInspectionHeaderRow() {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE4E9DD))),
      ),
      children: const [
        _MaintenanceHeaderCell(label: 'Toestel/Instalatie'),
        _MaintenanceHeaderCell(label: 'Keurinstelling'),
        _MaintenanceHeaderCell(label: 'Vestigingen'),
        _MaintenanceHeaderCell(label: 'Frequentie'),
        _MaintenanceHeaderCell(label: 'Status'),
        _MaintenanceHeaderCell(label: 'Keuren voor', isLast: true),
      ],
    );
  }

  TableRow _buildInspectionDataRow(MaintenanceInspection inspection) {
    void openDetail() {
      _openInspectionDetail(inspection);
    }

    Widget tappable(Widget child) {
      return GestureDetector(onTap: openDetail, child: child);
    }

    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F2EC))),
      ),
      children: [
        tappable(_buildInspectionTextCell(inspection.equipment)),
        tappable(_buildInspectionTextCell(inspection.inspectionInstitution)),
        tappable(_buildInspectionTextCell(inspection.locations.join(', '))),
        tappable(_buildInspectionTextCell(inspection.frequency)),
        tappable(
          _buildInspectionTextCell(
            _getStatusLabel(inspection.status),
            color: _getStatusColor(inspection.status),
            weight: FontWeight.w500,
          ),
        ),
        tappable(
          _buildInspectionTextCell(
            _formatDate(inspection.dueDate),
            color: _getDateColor(inspection.dueDate),
            weight: FontWeight.w500,
            isLast: true,
          ),
        ),
      ],
    );
  }

  Widget _buildInspectionTextCell(
    String value, {
    Color? color,
    FontWeight weight = FontWeight.w400,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: isLast ? 20 : 16,
        top: 16,
        bottom: 16,
      ),
      child: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          color: color ?? const Color(0xFF4D5548),
          fontWeight: weight,
        ),
      ),
    );
  }

  Widget _buildBreadcrumb() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          Text(
            'Dashboard',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.chevron_right, size: 14, color: Colors.grey[400]),
          ),
          Text(
            'Onderhoud & Keuringen',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedInspection != null) {
      return MaintenanceInspectionDetailScreen(
        inspection: _selectedInspection,
        onClose: _closeInspectionDetail,
      );
    }

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
            _buildBreadcrumb(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                'Onderhoud & Keuringen',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Spacer(),
                        SizedBox(
                          width: 260,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Zoeken',
                              hintStyle: const TextStyle(fontSize: 14),
                              prefixIcon: const Icon(Icons.search, size: 20),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD7DBD2),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD7DBD2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: const BorderSide(
                                  color: kBrandGreen,
                                  width: 1.5,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onChanged: (value) {
                              searchQuery = value;
                              _filterInspections();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _showFilterSheet,
                          icon: const Icon(Icons.filter_alt_outlined),
                          tooltip: 'Filteren',
                          color: const Color(0xFF6B7A62),
                        ),
                        const SizedBox(width: 4),
                        ElevatedButton.icon(
                          onPressed: isLoading ? null : _showAddDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Nieuw'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kBrandGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                return _buildInspectionTable(
                                  minHeight: constraints.maxHeight,
                                  minWidth: constraints.maxWidth,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceHeaderCell extends StatelessWidget {
  const _MaintenanceHeaderCell({required this.label, this.isLast = false});

  final String label;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: isLast ? 20 : 16,
        top: 14,
        bottom: 14,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7A62),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? kBrandGreen : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? kBrandGreen : const Color(0xFFD7DBD2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF4D5548),
          ),
        ),
      ),
    );
  }
}

class _MaintenanceInspectionDialog extends StatefulWidget {
  const _MaintenanceInspectionDialog({
    required this.availableBranches,
    required this.inspectionTypes,
    required this.customInspectionTypes,
    required this.onInspectionTypeAdded,
    required this.onInspectionTypeRenamed,
    required this.onInspectionTypeDeleted,
  });

  final List<Branch> availableBranches;
  final List<String> inspectionTypes;
  final List<String> customInspectionTypes;
  final Future<void> Function(String type) onInspectionTypeAdded;
  final Future<void> Function(String oldType, String newType)
      onInspectionTypeRenamed;
  final Future<void> Function(String type) onInspectionTypeDeleted;

  @override
  State<_MaintenanceInspectionDialog> createState() =>
      _MaintenanceInspectionDialogState();
}

class _MaintenanceInspectionDialogState
    extends State<_MaintenanceInspectionDialog> {
  final TextEditingController equipmentController = TextEditingController();
  final TextEditingController institutionController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController lastInspectionController =
      TextEditingController();
  final TextEditingController dueDateController = TextEditingController();

  String inspectionType = 'Kalibratie';
  late List<String> _inspectionTypes;
  late Set<String> _customInspectionTypes;
  int frequencyValue = 5;
  String frequencyUnit = 'Jaar';
  bool selfContact = false;
  String? status;
  final Set<int> selectedLocationIds = {};
  final ScrollController _locationsScrollController = ScrollController();
  DateTime? lastInspectionDate;
  DateTime? dueDate;
  String? _equipmentError;
  String? _institutionError;
  String? _branchesError;

  List<Branch> get branches => widget.availableBranches;

  @override
  void initState() {
    super.initState();
    _inspectionTypes = [...widget.inspectionTypes];
    _customInspectionTypes = widget.customInspectionTypes
        .map((type) => type.trim())
        .where((type) => type.isNotEmpty)
        .toSet();
    _customInspectionTypes.addAll(
      widget.inspectionTypes
          .map((type) => type.trim())
          .where((type) => type.isNotEmpty),
    );
    if (branches.isNotEmpty) {
      selectedLocationIds.add(branches.first.id);
    }
    equipmentController.addListener(() {
      if (_equipmentError != null &&
          equipmentController.text.trim().isNotEmpty) {
        setState(() => _equipmentError = null);
      }
    });
    institutionController.addListener(() {
      if (_institutionError != null &&
          institutionController.text.trim().isNotEmpty) {
        setState(() => _institutionError = null);
      }
    });
  }

  @override
  void dispose() {
    equipmentController.dispose();
    institutionController.dispose();
    contactController.dispose();
    notesController.dispose();
    lastInspectionController.dispose();
    dueDateController.dispose();
    _locationsScrollController.dispose();
    super.dispose();
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
              backgroundColor: kBrandGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Toevoegen'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await widget.onInspectionTypeAdded(result);
      if (!mounted) {
        return;
      }
      setState(() {
        _addLocalInspectionType(result);
        _customInspectionTypes.add(result.trim());
        inspectionType = result;
      });
    }
    controller.dispose();
  }

  Future<void> _showEditInspectionTypeDialog(String currentType) async {
    final controller = TextEditingController(text: currentType);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keuringstype bewerken'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Naam keuringstype',
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
              backgroundColor: kBrandGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Opslaan'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result == null || result.isEmpty || result == currentType) {
      return;
    }

    await widget.onInspectionTypeRenamed(currentType, result);
    if (!mounted) {
      return;
    }
    setState(() {
      _inspectionTypes
        ..removeWhere((type) => type.trim() == currentType.trim())
        ..add(result.trim())
        ..sort();
      _customInspectionTypes
        ..remove(currentType.trim())
        ..add(result.trim());
      if (inspectionType == currentType) {
        inspectionType = result.trim();
      }
    });
  }

  Future<void> _deleteInspectionType(String type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keuringstype verwijderen'),
        content: Text('Wil je "$type" verwijderen uit de keuzelijst?'),
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

    await widget.onInspectionTypeDeleted(type);
    if (!mounted) {
      return;
    }
    setState(() {
      _inspectionTypes.removeWhere((item) => item.trim() == type.trim());
      _customInspectionTypes.remove(type.trim());
      if (inspectionType == type) {
        inspectionType = 'Kalibratie';
      }
    });
  }

  void _addLocalInspectionType(String type) {
    final trimmedType = type.trim();
    if (trimmedType.isEmpty ||
        _inspectionTypes.any((item) => item.trim() == trimmedType)) {
      return;
    }
    _inspectionTypes.add(trimmedType);
    _inspectionTypes.sort();
  }

  List<DropdownMenuItem<String>> _inspectionTypeItems() {
    return _inspectionTypeValues().map((type) {
      if (type == 'new') {
        return const DropdownMenuItem(
          value: 'new',
          child: Text('+ Nieuw type toevoegen'),
        );
      }

      return DropdownMenuItem(
        value: type,
        child: _buildInspectionTypeMenuItem(type),
      );
    }).toList();
  }

  List<Widget> _inspectionTypeSelectedItems() {
    return _inspectionTypeValues()
        .map(
          (type) => Align(
            alignment: Alignment.centerLeft,
            child: Text(type == 'new' ? '+ Nieuw type toevoegen' : type),
          ),
        )
        .toList();
  }

  List<String> _inspectionTypeValues() {
    final values = <String>[];

    void addType(String type) {
      final trimmedType = type.trim();
      if (trimmedType.isNotEmpty && !values.contains(trimmedType)) {
        values.add(trimmedType);
      }
    }

    for (final type in _inspectionTypes) {
      addType(type);
    }
    addType(inspectionType);
    values.add('new');
    return values;
  }

  Widget _buildInspectionTypeMenuItem(String type) {
    return Row(
      children: [
        Expanded(child: Text(type)),
        IconButton(
          tooltip: 'Bewerken',
          icon: const Icon(Icons.edit_outlined, size: 18),
          color: const Color(0xFF6B7A62),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            Navigator.pop(context);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showEditInspectionTypeDialog(type);
              }
            });
          },
        ),
        IconButton(
          tooltip: 'Verwijderen',
          icon: const Icon(Icons.delete_outline, size: 18),
          color: const Color(0xFFD32F2F),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            Navigator.pop(context);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _deleteInspectionType(type);
              }
            });
          },
        ),
      ],
    );
  }

  String? _mapFrontendStatusToBackend(String? status) {
    if (status?.trim().isEmpty ?? true) {
      return null;
    }

    switch (status!.trim()) {
      case 'In uitvoering':
        return 'Open';
      case 'Uitgevoerd':
        return 'Closed';
      case 'Nog niet uitgevoerd':
        return 'Pending';
      default:
        return status.trim();
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final pickedDate = await showDatePicker(
      context: context,
      // initialDate: DateTime(2025, 10, 26),
      initialDate: DateTime.now(),
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
    return Theme(
      data: Theme.of(context).copyWith(
        highlightColor: kBrandGreen,
        focusColor: const Color(0xFFEAF4D9),
        splashColor: const Color(0x338CC63F),
        hoverColor: const Color(0x228CC63F),
      ),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F2EA),
                borderRadius: BorderRadius.circular(18),
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
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
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
                                    decoration: _inputDecoration(
                                      'Drukvat compressor',
                                    ).copyWith(errorText: _equipmentError),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildLabel('Naam Keurinstelling *'),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: institutionController,
                                    decoration: _inputDecoration(
                                      'Vinçotte',
                                    ).copyWith(errorText: _institutionError),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildLabel('Contactgegevens'),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: contactController,
                                    decoration: _inputDecoration(
                                      'buildingsalesnorth@vincotte.be',
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
                                  _buildLabel('Type Keuring *'),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue: inspectionType,
                                    isExpanded: true,
                                    focusColor: const Color(0xFFEAF4D9),
                                    borderRadius: BorderRadius.circular(16),
                                    dropdownColor: Colors.white,
                                    items: _inspectionTypeItems(),
                                    selectedItemBuilder: (_) =>
                                        _inspectionTypeSelectedItems(),
                                    onChanged: (value) {
                                      if (value == 'new') {
                                        _showAddInspectionTypeDialog();
                                      } else if (value != null) {
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
                                        constraints: const BoxConstraints(
                                          minWidth: 64,
                                          maxWidth: 120,
                                        ),
                                        child: DropdownButtonFormField<int>(
                                          isExpanded: true,
                                          initialValue: frequencyValue,
                                          focusColor: const Color(0xFFEAF4D9),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          dropdownColor: Colors.white,
                                          items: List.generate(
                                            12,
                                            (index) => DropdownMenuItem(
                                              value: index + 1,
                                              child: Text('${index + 1}'),
                                            ),
                                          ),
                                          onChanged: (value) {
                                            if (value != null) {
                                              setState(
                                                () => frequencyValue = value,
                                              );
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
                                          focusColor: const Color(0xFFEAF4D9),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          dropdownColor: Colors.white,
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'Jaar',
                                              child: Text('Jaar'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Maand',
                                              child: Text('Maand'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Dag',
                                              child: Text('Dag'),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            if (value != null) {
                                              setState(
                                                () => frequencyUnit = value,
                                              );
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
                                        selectedColor:
                                            const Color(0xFFEAF4D9),
                                        backgroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        onSelected: (_) =>
                                            setState(() => selfContact = true),
                                      ),
                                      ChoiceChip(
                                        label: const Text('Nee'),
                                        selected: !selfContact,
                                        selectedColor:
                                            const Color(0xFFEAF4D9),
                                        backgroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        onSelected: (_) =>
                                            setState(() => selfContact = false),
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
                            decoration: _inputDecoration(
                              'Drukvat compressor',
                            ).copyWith(errorText: _equipmentError),
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('Type Keuring *'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: inspectionType,
                            isExpanded: true,
                            focusColor: const Color(0xFFEAF4D9),
                            borderRadius: BorderRadius.circular(16),
                            dropdownColor: Colors.white,
                            items: _inspectionTypeItems(),
                            selectedItemBuilder: (_) =>
                                _inspectionTypeSelectedItems(),
                            onChanged: (value) {
                              if (value == 'new') {
                                _showAddInspectionTypeDialog();
                              } else if (value != null) {
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
                            decoration: _inputDecoration(
                              'Vinçotte',
                            ).copyWith(errorText: _institutionError),
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('Contactgegevens'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: contactController,
                            decoration: _inputDecoration(
                              'buildingsalesnorth@vincotte.be',
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildLabel('Status'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    isExpanded: true,
                    focusColor: const Color(0xFFEAF4D9),
                    borderRadius: BorderRadius.circular(16),
                    dropdownColor: Colors.white,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Geen')),
                      DropdownMenuItem(
                        value: 'In uitvoering',
                        child: Text('In uitvoering'),
                      ),
                      DropdownMenuItem(
                        value: 'Nog niet uitgevoerd',
                        child: Text('Nog niet uitgevoerd'),
                      ),
                      DropdownMenuItem(
                        value: 'Uitgevoerd',
                        child: Text('Uitgevoerd'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => status = value);
                      } else {
                        setState(() => status = null);
                      }
                    },
                    decoration: _dropdownDecoration(),
                  ),
                  const SizedBox(height: 16),
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
                                final selected = selectedLocationIds.contains(
                                  branch.id,
                                );
                                return CheckboxListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
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
                                        if (_branchesError != null &&
                                            selectedLocationIds.isNotEmpty) {
                                          _branchesError = null;
                                        }
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
                  Visibility(
                    visible: _branchesError != null,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                      child: Text(
                        _branchesError ?? '',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Opmerkingen'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    maxLines: 4,
                    minLines: 3,
                    decoration: _inputDecoration(
                      'Extra opmerkingen of aandachtspunten',
                    ).copyWith(alignLabelWithHint: true),
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
                                onTap: () =>
                                    _pickDate(lastInspectionController),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: kBrandGreen,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annuleren'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBrandGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: () {
                          // Parse dates from text fields if not already set
                          DateTime? parsedLastInspection = lastInspectionDate;
                          DateTime? parsedDueDate = dueDate;

                          if (parsedLastInspection == null &&
                              lastInspectionController.text.trim().isNotEmpty) {
                            try {
                              final parts = lastInspectionController.text.split(
                                '/',
                              );
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

                          final missing = <String>[];
                          if (equipmentController.text.trim().isEmpty) {
                            missing.add('Toestel/Installatie');
                          }
                          if (institutionController.text.trim().isEmpty) {
                            missing.add('Naam keurinstelling');
                          }
                          if (selectedLocationIds.isEmpty) {
                            missing.add('Vestiging');
                          }

                          if (missing.isNotEmpty) {
                            setState(() {
                              _equipmentError =
                                  missing.contains('Toestel/Installatie')
                                  ? 'Verplicht'
                                  : null;
                              _institutionError =
                                  missing.contains('Naam keurinstelling')
                                  ? 'Verplicht'
                                  : null;
                              _branchesError = missing.contains('Vestiging')
                                  ? 'Kies minstens één vestiging'
                                  : null;
                            });
                            return;
                          }
                          final form = MaintenanceInspectionForm()
                            ..equipment = equipmentController.text.trim()
                            ..inspectionType = inspectionType
                            ..inspectionInstitution = institutionController.text
                                .trim()
                            ..contactInfo = contactController.text.trim()
                            ..notes = notesController.text.trim().isEmpty
                                ? null
                                : notesController.text.trim()
                            ..frequencyValue = frequencyValue
                            ..frequencyUnit = frequencyUnit
                            ..selfContact = selfContact
                            ..status = _mapFrontendStatusToBackend(status)
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD8D8D8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBrandGreen),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD8D8D8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBrandGreen),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  InputDecoration _dateDecoration({required VoidCallback onTap}) {
    final now = DateTime.now();
    return InputDecoration(
      hintText:
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
      filled: true,
      fillColor: Colors.white,
      suffixIcon: IconButton(
        icon: const Icon(Icons.calendar_month_outlined),
        onPressed: onTap,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD8D8D8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBrandGreen),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
