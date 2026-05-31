import 'dart:math' as math;

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
import '../widgets/design/app_breadcrumb.dart';
import '../widgets/design/app_inline_filter_panel.dart';
import '../widgets/design/app_toolbar_controls.dart';
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
  bool _filtersExpanded = false;

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
          inspection.branches.any(
            (branch) => branch.toLowerCase().contains(query),
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
            orElse: () => Branch(id: -1, name: ''),
          );
          return inspection.branches.contains(branch.name);
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
      barrierDismissible: true,
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
    }.where((type) => type.isNotEmpty).toList()..sort();

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
    }.where((type) => type.isNotEmpty).toList()..sort();

    await _persistCustomInspectionTypes(types);
  }

  Future<void> _deleteCustomInspectionType(String type) async {
    final trimmedType = type.trim();
    final types =
        customInspectionTypes
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

  int get _activeFilterCount {
    var count = 0;
    if (selectedStatus != null && selectedStatus != 'all') count++;
    if (selectedInspectionType != null) count++;
    if (selectedFilterBranches.isNotEmpty) count++;
    if (filterDateFrom != null || filterDateTo != null) count++;
    return count;
  }

  void _clearFilters() {
    setState(() {
      selectedStatus = null;
      selectedInspectionType = null;
      selectedFilterBranches.clear();
      filterDateFrom = null;
      filterDateTo = null;
    });
    _filterInspections();
  }

  Widget _buildInlineFilters() {
    final showActiveFilters = _activeFilterCount > 0;
    if (!showActiveFilters && !_filtersExpanded) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showActiveFilters) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if ((selectedStatus ?? '').isNotEmpty)
                AppActiveFilterChip(
                  label: 'Status: $selectedStatus',
                  onRemove: () {
                    setState(() => selectedStatus = null);
                    _filterInspections();
                  },
                ),
              if ((selectedInspectionType ?? '').isNotEmpty)
                AppActiveFilterChip(
                  label: 'Type: $selectedInspectionType',
                  onRemove: () {
                    setState(() => selectedInspectionType = null);
                    _filterInspections();
                  },
                ),
              ...selectedFilterBranches.map((branchId) {
                final branch = availableBranches.where((b) => b.id == branchId);
                final label = branch.isEmpty ? '$branchId' : branch.first.name;
                return AppActiveFilterChip(
                  label: 'Vestiging: $label',
                  onRemove: () {
                    setState(() => selectedFilterBranches.remove(branchId));
                    _filterInspections();
                  },
                );
              }),
            ],
          ),
        ],
        if (_filtersExpanded) ...[
          const SizedBox(height: 14),
          _buildInlineFilterPanel(),
        ],
      ],
    );
  }

  Widget _buildInlineFilterPanel() {
    final inspectionTypes = _inspectionTypes();
    final selectedBranchId = selectedFilterBranches.length == 1
        ? selectedFilterBranches.first
        : null;

    return AppInlineFilterPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fieldWidth = constraints.maxWidth < 760
              ? constraints.maxWidth
              : (constraints.maxWidth - 42) / 4;

          return Wrap(
            spacing: 14,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              AppInlineFilterSelectField<String>(
                width: fieldWidth,
                label: 'Status',
                value: selectedStatus,
                options: const [
                  AppInlineFilterOption(value: null, label: 'Alle statussen'),
                  AppInlineFilterOption(
                    value: 'In uitvoering',
                    label: 'In uitvoering',
                  ),
                  AppInlineFilterOption(
                    value: 'Nog niet uitgevoerd',
                    label: 'Nog niet uitgevoerd',
                  ),
                  AppInlineFilterOption(
                    value: 'Uitgevoerd',
                    label: 'Uitgevoerd',
                  ),
                ],
                onChanged: (value) {
                  setState(() => selectedStatus = value);
                  _filterInspections();
                },
              ),
              AppInlineFilterSelectField<String>(
                width: fieldWidth,
                label: 'Keuringstype',
                value: selectedInspectionType,
                options: [
                  const AppInlineFilterOption(value: null, label: 'Alle types'),
                  ...inspectionTypes.map(
                    (type) => AppInlineFilterOption(value: type, label: type),
                  ),
                ],
                onChanged: (value) {
                  setState(() => selectedInspectionType = value);
                  _filterInspections();
                },
              ),
              AppInlineFilterSelectField<int>(
                width: fieldWidth,
                label: 'Vestiging',
                value: selectedBranchId,
                options: [
                  const AppInlineFilterOption(
                    value: null,
                    label: 'Alle vestigingen',
                  ),
                  ...availableBranches.map(
                    (branch) => AppInlineFilterOption(
                      value: branch.id,
                      label: branch.name,
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedFilterBranches.clear();
                    if (value != null) selectedFilterBranches.add(value);
                  });
                  _filterInspections();
                },
              ),
              if (_activeFilterCount > 0)
                AppInlineFilterClearButton(onPressed: _clearFilters),
            ],
          );
        },
      ),
    );
  }

  static const double _maintenanceTableColumnGap = 10;
  static const int _equipmentFlex = 23;
  static const int _institutionFlex = 20;
  static const int _branchesFlex = 20;
  static const int _frequencyFlex = 12;
  static const int _statusFlex = 13;
  static const int _dueDateFlex = 14;
  static const double _minMaintenanceTableWidth = 1080;

  Widget _buildInspectionTable({double minHeight = 0, double minWidth = 0}) {
    const bottomGap = 16.0;
    const headerHeight = 48.0;
    const footerHeight = 40.0;
    final tableHeight = minHeight > (headerHeight + footerHeight + bottomGap)
        ? minHeight - bottomGap
        : 420.0;

    return Container(
      margin: const EdgeInsets.only(bottom: bottomGap),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E6DD)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: LayoutBuilder(
          builder: (context, c) {
            final width = math
                .max(c.maxWidth, _minMaintenanceTableWidth)
                .toDouble();

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                height: tableHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _MaintenanceTableHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: List<Widget>.generate(
                            filteredInspections.length,
                            (index) {
                              final inspection = filteredInspections[index];
                              return _MaintenanceTableRow(
                                striped: index.isOdd,
                                onTap: () => _openInspectionDetail(inspection),
                                cells: [
                                  _MaintenanceCellData(
                                    flex: _equipmentFlex,
                                    child: _MaintenanceCellText(
                                      inspection.equipment,
                                      emphasized: true,
                                    ),
                                  ),
                                  _MaintenanceCellData(
                                    flex: _institutionFlex,
                                    child: _MaintenanceCellText(
                                      inspection.inspectionInstitution,
                                    ),
                                  ),
                                  _MaintenanceCellData(
                                    flex: _branchesFlex,
                                    child: _MaintenanceCellText(
                                      inspection.branches.join(', '),
                                    ),
                                  ),
                                  _MaintenanceCellData(
                                    flex: _frequencyFlex,
                                    child: _MaintenanceCellText(
                                      inspection.frequency,
                                    ),
                                  ),
                                  _MaintenanceCellData(
                                    flex: _statusFlex,
                                    child: _MaintenanceStatusChip(
                                      label: _getStatusLabel(inspection.status),
                                    ),
                                  ),
                                  _MaintenanceCellData(
                                    flex: _dueDateFlex,
                                    child: _MaintenanceCellText(
                                      _formatDate(inspection.dueDate),
                                      color: _getDateColor(inspection.dueDate),
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFBFCF8),
                        border: Border(
                          top: BorderSide(color: Color(0xFFE8ECE3)),
                        ),
                      ),
                      child: const Text(
                        'Klik op een rij om alle details en de planning te openen.',
                        style: TextStyle(
                          color: Color(0xFF6B7367),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBreadcrumb() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: AppBreadcrumb(segments: ['Dashboard', 'Onderhoud & Keuringen']),
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
                        AppToolbarSearchField(
                          hintText: 'Zoeken',
                          width: 260,
                          onChanged: (value) {
                            searchQuery = value;
                            _filterInspections();
                          },
                        ),
                        const SizedBox(width: 8),
                        AppToolbarFilterButton(
                          onPressed: () => setState(
                            () => _filtersExpanded = !_filtersExpanded,
                          ),
                          expanded: _filtersExpanded,
                          activeCount: _activeFilterCount,
                        ),
                        const SizedBox(width: 8),
                        AppToolbarPrimaryButton(
                          onPressed: isLoading ? null : _showAddDialog,
                          label: 'Nieuw',
                        ),
                      ],
                    ),
                    _buildInlineFilters(),
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

class _MaintenanceTableHeader extends StatelessWidget {
  const _MaintenanceTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F7F2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: _withMaintenanceTableColumnGaps(const [
          _MaintenanceHeaderColumn(
            label: 'Toestel/Instalatie',
            flex: _MaintenanceInspectionsScreenState._equipmentFlex,
          ),
          _MaintenanceHeaderColumn(
            label: 'Keurinstelling',
            flex: _MaintenanceInspectionsScreenState._institutionFlex,
          ),
          _MaintenanceHeaderColumn(
            label: 'Vestigingen',
            flex: _MaintenanceInspectionsScreenState._branchesFlex,
          ),
          _MaintenanceHeaderColumn(
            label: 'Frequentie',
            flex: _MaintenanceInspectionsScreenState._frequencyFlex,
          ),
          _MaintenanceHeaderColumn(
            label: 'Status',
            flex: _MaintenanceInspectionsScreenState._statusFlex,
          ),
          _MaintenanceHeaderColumn(
            label: 'Keuren voor',
            flex: _MaintenanceInspectionsScreenState._dueDateFlex,
          ),
        ]),
      ),
    );
  }
}

class _MaintenanceHeaderColumn extends StatelessWidget {
  const _MaintenanceHeaderColumn({required this.label, required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF545C50),
        ),
      ),
    );
  }
}

class _MaintenanceTableRow extends StatefulWidget {
  const _MaintenanceTableRow({
    required this.cells,
    required this.onTap,
    required this.striped,
  });

  final List<_MaintenanceCellData> cells;
  final VoidCallback onTap;
  final bool striped;

  @override
  State<_MaintenanceTableRow> createState() => _MaintenanceTableRowState();
}

class _MaintenanceTableRowState extends State<_MaintenanceTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.striped ? const Color(0xFFF9FAF6) : Colors.white;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: _hovered ? kSurfaceHover : baseColor,
        child: InkWell(
          onTap: widget.onTap,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE8ECE3))),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: _withMaintenanceTableColumnGaps(
                widget.cells.map((cell) {
                  return Expanded(
                    flex: cell.flex,
                    child: Align(alignment: cell.alignment, child: cell.child),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<Widget> _withMaintenanceTableColumnGaps(List<Widget> children) {
  final spacedChildren = <Widget>[];

  for (var index = 0; index < children.length; index += 1) {
    if (index > 0) {
      spacedChildren.add(
        const SizedBox(
          width: _MaintenanceInspectionsScreenState._maintenanceTableColumnGap,
        ),
      );
    }

    spacedChildren.add(children[index]);
  }

  return spacedChildren;
}

class _MaintenanceCellData {
  const _MaintenanceCellData({required this.flex, required this.child})
    : alignment = Alignment.centerLeft;

  final int flex;
  final Widget child;
  final Alignment alignment;
}

class _MaintenanceCellText extends StatelessWidget {
  const _MaintenanceCellText(
    this.value, {
    this.color,
    this.emphasized = false,
    this.weight,
  });

  final String value;
  final Color? color;
  final bool emphasized;
  final FontWeight? weight;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: value,
      waitDuration: const Duration(milliseconds: 450),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color ?? const Color(0xFF2F382E),
          fontWeight:
              weight ?? (emphasized ? FontWeight.w600 : FontWeight.w500),
        ),
      ),
    );
  }
}

class _MaintenanceStatusChip extends StatelessWidget {
  const _MaintenanceStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.trim().toLowerCase();
    late final Color backgroundColor;
    late final Color textColor;

    if (normalized == 'uitgevoerd') {
      backgroundColor = kSuccessBg;
      textColor = kSuccess;
    } else if (normalized == 'in uitvoering') {
      backgroundColor = kInfoBg;
      textColor = kInfo;
    } else if (normalized == 'nog niet uitgevoerd') {
      backgroundColor = kDangerBg;
      textColor = kDanger;
    } else {
      backgroundColor = kSurfaceMuted;
      textColor = kTextTertiary;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(kRadiusPill),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w800,
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
  final Set<int> selectedBranchIds = {};
  final ScrollController _branchesScrollController = ScrollController();
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
      selectedBranchIds.add(branches.first.id);
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
    _branchesScrollController.dispose();
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
        title: const Text('Keuringstype verwijderen?'),
        content: Text(
          '"$type" wordt definitief uit de keuzelijst verwijderd. Dit kun je niet ongedaan maken.',
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
          color: kTextSecondary,
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
          color: kDanger,
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
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.9;

    return Dialog(
      backgroundColor: kSurface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
        side: const BorderSide(color: kBorder),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 640, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDialogHeader(context),
            const Divider(height: 1, color: kBorderSubtle),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                                        'Naam toestel of installatie',
                                      ).copyWith(errorText: _equipmentError),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildLabel('Naam Keurinstelling *'),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: institutionController,
                                      decoration: _inputDecoration(
                                        'Naam keurinstelling',
                                      ).copyWith(errorText: _institutionError),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildLabel('Contactgegevens'),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: contactController,
                                      decoration: _inputDecoration(
                                        'E-mail of telefoon',
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
                                      borderRadius: BorderRadius.circular(
                                        kRadiusMd,
                                      ),
                                      dropdownColor: kSurface,
                                      items: _inspectionTypeItems(),
                                      selectedItemBuilder: (_) =>
                                          _inspectionTypeSelectedItems(),
                                      onChanged: (value) {
                                        if (value == 'new') {
                                          _showAddInspectionTypeDialog();
                                        } else if (value != null) {
                                          setState(
                                            () => inspectionType = value,
                                          );
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
                                            borderRadius: BorderRadius.circular(
                                              kRadiusMd,
                                            ),
                                            dropdownColor: kSurface,
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
                                          child:
                                              DropdownButtonFormField<String>(
                                                isExpanded: true,
                                                initialValue: frequencyUnit,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      kRadiusMd,
                                                    ),
                                                dropdownColor: kSurface,
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
                                                      () =>
                                                          frequencyUnit = value,
                                                    );
                                                  }
                                                },
                                                decoration:
                                                    _dropdownDecoration(),
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    _buildLabel('Zelf Contacteren?'),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 48,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: _buildYesNoOption(
                                              label: 'Ja',
                                              selected: selfContact,
                                              onTap: () => setState(
                                                () => selfContact = true,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _buildYesNoOption(
                                              label: 'Nee',
                                              selected: !selfContact,
                                              onTap: () => setState(
                                                () => selfContact = false,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
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
                                'Naam toestel of installatie',
                              ).copyWith(errorText: _equipmentError),
                            ),
                            const SizedBox(height: 16),
                            _buildLabel('Type Keuring *'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: inspectionType,
                              isExpanded: true,
                              borderRadius: BorderRadius.circular(kRadiusMd),
                              dropdownColor: kSurface,
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
                                'Naam keurinstelling',
                              ).copyWith(errorText: _institutionError),
                            ),
                            const SizedBox(height: 16),
                            _buildLabel('Contactgegevens'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: contactController,
                              decoration: _inputDecoration(
                                'E-mail of telefoon',
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
                      borderRadius: BorderRadius.circular(kRadiusMd),
                      dropdownColor: kSurface,
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
                        color: kSurface,
                        border: Border.all(color: kBorder),
                        borderRadius: BorderRadius.circular(kRadiusMd),
                      ),
                      child: branches.isEmpty
                          ? const Center(
                              child: Text(
                                'Geen vestigingen beschikbaar.',
                                style: TextStyle(
                                  color: kTextMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          : Scrollbar(
                              controller: _branchesScrollController,
                              child: ListView(
                                controller: _branchesScrollController,
                                padding: EdgeInsets.zero,
                                children: branches.map((branch) {
                                  final selected = selectedBranchIds.contains(
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
                                          selectedBranchIds.add(branch.id);
                                          if (_branchesError != null &&
                                              selectedBranchIds.isNotEmpty) {
                                            _branchesError = null;
                                          }
                                        } else {
                                          selectedBranchIds.remove(branch.id);
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
                            color: kDanger,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: kBorderSubtle),
            _buildDialogFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 12, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kBrandGreenSubtle,
              borderRadius: BorderRadius.circular(kRadiusSm),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.fact_check_outlined,
              color: kBrandGreenDeep,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Nieuwe onderhouds- of keuringslijn',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Vul de gegevens hieronder in om een nieuwe lijn toe te voegen.',
                  style: TextStyle(
                    fontSize: 13,
                    color: kTextTertiary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sluiten',
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Aanmaken'),
            onPressed: _submitForm,
          ),
        ],
      ),
    );
  }

  void _submitForm() {
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

    if (parsedDueDate == null && dueDateController.text.trim().isNotEmpty) {
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
    if (selectedBranchIds.isEmpty) {
      missing.add('Vestiging');
    }

    if (missing.isNotEmpty) {
      setState(() {
        _equipmentError = missing.contains('Toestel/Installatie')
            ? 'Verplicht'
            : null;
        _institutionError = missing.contains('Naam keurinstelling')
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
      ..inspectionInstitution = institutionController.text.trim()
      ..contactInfo = contactController.text.trim()
      ..notes = notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim()
      ..frequencyValue = frequencyValue
      ..frequencyUnit = frequencyUnit
      ..selfContact = selfContact
      ..status = _mapFrontendStatusToBackend(status)
      ..selectedBranchIds = selectedBranchIds.toList()
      ..lastInspectionDate = parsedLastInspection
      ..nextInspectionDate = parsedDueDate;

    Navigator.pop(context, form);
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: kTextSecondary,
        letterSpacing: 0.1,
        height: 1.25,
      ),
    );
  }

  Widget _buildYesNoOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final radius = BorderRadius.circular(kRadiusMd);
    return Material(
      color: selected ? kBrandGreenSoft : kSurface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? kBrandGreenDark : kBorder,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? kBrandGreenDeep : kTextSecondary,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hintText) {
    return _baseInputDecoration().copyWith(hintText: hintText);
  }

  InputDecoration _dropdownDecoration() {
    return _baseInputDecoration().copyWith(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  InputDecoration _dateDecoration({required VoidCallback onTap}) {
    final now = DateTime.now();
    return _baseInputDecoration().copyWith(
      hintText:
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
      suffixIcon: IconButton(
        icon: const Icon(
          Icons.calendar_today_outlined,
          size: 18,
          color: kTextTertiary,
        ),
        onPressed: onTap,
      ),
    );
  }

  InputDecoration _baseInputDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: kSurface,
      hintStyle: const TextStyle(
        color: kTextMuted,
        fontWeight: FontWeight.w500,
      ),
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
}
