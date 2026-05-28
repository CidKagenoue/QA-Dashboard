import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qa_dashboard/widgets/app_bars/main_app_bar.dart';
import '../models/ova_sort_option.dart';
import '../models/ova_assigned_action.dart';
import '../models/ova_ticket.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/design/design_system.dart';
import 'ova_action_detail_screen.dart';
import 'ova_ticket_wizard_screen.dart' show formatOvaDate;

enum _ActionScope { mine, all }

enum _ActionStatusFilter { nok, ok, all }

enum _ActionDeadlineFilter { all, overdue, thisWeek, later }

enum _ActionTypeFilter { all, corrective, preventive }

String _formatOvaTicketNumber(int id) => '#${id.toString().padLeft(4, '0')}';

class OvaActionsScreen extends StatefulWidget {
  const OvaActionsScreen({
    super.key,
    this.embedded = false,
    this.onNavigateBack,
  });

  final bool embedded;
  final VoidCallback? onNavigateBack;

  @override
  State<OvaActionsScreen> createState() => _OvaActionsScreenState();
}

class _OvaActionsScreenState extends State<OvaActionsScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  List<OvaAssignedAction> _actions = const [];
  _ActionScope _selectedScope = _ActionScope.mine;
  _ActionStatusFilter _selectedStatusFilter = _ActionStatusFilter.all;
  _ActionDeadlineFilter _selectedDeadlineFilter = _ActionDeadlineFilter.all;
  _ActionTypeFilter _selectedTypeFilter = _ActionTypeFilter.all;
  String? _selectedAssignee;
  bool _filtersExpanded = false;
  bool _scopeInitialized = false;
  bool _canViewAllActions = false;
  final Set<int> _savingActionIds = <int>{};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _loadActions();
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  OvaSortOption _sortOption = const OvaSortOption(
    field: OvaSortField.date,
    direction: OvaSortDirection.descending,
  );

  void _setSortOption(OvaSortOption option) {
    setState(() {
      _sortOption = option;
    });
  }

  List<OvaAssignedAction> get _filteredActions {
    final query = _normalizeValue(_searchController.text);
    Iterable<OvaAssignedAction> actions = _actions;

    if (query.isNotEmpty) {
      actions = actions.where((item) => _matchesSearch(item, query));
    }

    switch (_selectedStatusFilter) {
      case _ActionStatusFilter.nok:
        actions = actions.where((item) => !item.action.isOk);
        break;
      case _ActionStatusFilter.ok:
        actions = actions.where((item) => item.action.isOk);
        break;
      case _ActionStatusFilter.all:
        break;
    }

    switch (_selectedDeadlineFilter) {
      case _ActionDeadlineFilter.overdue:
        actions = actions.where(_isOverdue);
        break;
      case _ActionDeadlineFilter.thisWeek:
        actions = actions.where(_isDueThisWeek);
        break;
      case _ActionDeadlineFilter.later:
        actions = actions.where(_isDueLater);
        break;
      case _ActionDeadlineFilter.all:
        break;
    }

    switch (_selectedTypeFilter) {
      case _ActionTypeFilter.corrective:
        actions = actions.where((item) => item.action.isCorrective);
        break;
      case _ActionTypeFilter.preventive:
        actions = actions.where((item) => !item.action.isCorrective);
        break;
      case _ActionTypeFilter.all:
        break;
    }

    if (_selectedScope == _ActionScope.all &&
        _selectedAssignee != null &&
        _selectedAssignee!.trim().isNotEmpty) {
      actions = actions.where(
        (item) => item.action.assigneeLabel == _selectedAssignee,
      );
    }

    final sorted = actions.toList();
    sorted.sort((a, b) {
      int comparison;
      switch (_sortOption.field) {
        case OvaSortField.date:
          comparison = a.action.dueDate.compareTo(b.action.dueDate);
          break;
        case OvaSortField.status:
          comparison = (a.action.isOk ? 1 : 0).compareTo(b.action.isOk ? 1 : 0);
          break;
        case OvaSortField.type:
          comparison = a.action.typeLabel.compareTo(b.action.typeLabel);
          break;
      }

      return _sortOption.direction == OvaSortDirection.ascending
          ? comparison
          : -comparison;
    });

    return sorted;
  }

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _loadActions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = context.read<AuthService>();
      final token = await authService.getValidAccessToken();
      final user = authService.user;
      final canViewAll = user != null && (user.isAdmin || user.access.ova);
      var requestedScope = _selectedScope;
      if (!_scopeInitialized) {
        requestedScope = canViewAll ? _ActionScope.all : _ActionScope.mine;
      } else if (!canViewAll && requestedScope == _ActionScope.all) {
        requestedScope = _ActionScope.mine;
      }

      final response = await ApiService.fetchOvaActions(
        token: token,
        scope: _scopeApiValue(requestedScope),
      );
      final rawActions = response['actions'];
      if (rawActions is! List) {
        throw Exception('Invalid OVA action list received from the server');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _scopeInitialized = true;
        _canViewAllActions =
            response['canViewAllActions'] == true || canViewAll;
        _selectedScope = response['scope'] == 'all'
            ? _ActionScope.all
            : _ActionScope.mine;
        _actions = rawActions
            .whereType<Map>()
            .map(
              (action) =>
                  OvaAssignedAction.fromJson(Map<String, dynamic>.from(action)),
            )
            .toList();
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

  String _scopeApiValue(_ActionScope scope) {
    switch (scope) {
      case _ActionScope.mine:
        return 'mine';
      case _ActionScope.all:
        return 'all';
    }
  }

  void _selectScope(_ActionScope scope) {
    if (_selectedScope == scope || !_canViewAllActions) {
      return;
    }

    setState(() {
      _selectedScope = scope;
      if (scope == _ActionScope.mine) {
        _selectedAssignee = null;
      }
    });
    _loadActions();
  }

  void _setStatusFilter(_ActionStatusFilter filter) {
    setState(() {
      _selectedStatusFilter = filter;
    });
  }

  void _setDeadlineFilter(_ActionDeadlineFilter filter) {
    setState(() {
      _selectedDeadlineFilter = filter;
    });
  }

  void _setTypeFilter(_ActionTypeFilter filter) {
    setState(() {
      _selectedTypeFilter = filter;
    });
  }

  void _setAssignee(String? assignee) {
    setState(() {
      _selectedAssignee = assignee;
    });
  }

  void _toggleFiltersExpanded() {
    setState(() {
      _filtersExpanded = !_filtersExpanded;
    });
  }

  void _clearFilters() {
    if (!_hasActiveFilters) {
      return;
    }

    _searchController.clear();
    setState(() {
      _selectedStatusFilter = _ActionStatusFilter.all;
      _selectedDeadlineFilter = _ActionDeadlineFilter.all;
      _selectedTypeFilter = _ActionTypeFilter.all;
      _selectedAssignee = null;
    });
  }

  Future<void> _updateActionStatus(OvaAssignedAction item, bool isOk) async {
    if (item.action.isOk == isOk || _savingActionIds.contains(item.action.id)) {
      return;
    }

    setState(() {
      _savingActionIds.add(item.action.id);
    });

    try {
      final token = await context.read<AuthService>().getValidAccessToken();
      final response = await ApiService.updateOvaAction(
        token: token,
        actionId: item.action.id,
        payload: {'status': isOk ? 'ok' : 'nok'},
      );
      if (!mounted) {
        return;
      }

      final updated = OvaFollowUpAction.fromJson(response);
      setState(() {
        _actions = _actions
            .map(
              (entry) => entry.action.id == item.action.id
                  ? OvaAssignedAction(action: updated, ticket: entry.ticket)
                  : entry,
            )
            .toList();
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
          _savingActionIds.remove(item.action.id);
        });
      }
    }
  }

  Future<void> _openActionDetail(OvaAssignedAction item) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OvaActionDetailScreen(initialAction: item),
      ),
    );

    if (result == true && mounted) {
      await _loadActions();
    }
  }

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty ||
      _selectedStatusFilter != _ActionStatusFilter.all ||
      _selectedDeadlineFilter != _ActionDeadlineFilter.all ||
      _selectedTypeFilter != _ActionTypeFilter.all ||
      _selectedAssignee != null;

  int get _activeFilterCount {
    var count = 0;
    if (_selectedStatusFilter != _ActionStatusFilter.all) count += 1;
    if (_selectedDeadlineFilter != _ActionDeadlineFilter.all) count += 1;
    if (_selectedTypeFilter != _ActionTypeFilter.all) count += 1;
    if (_selectedAssignee != null) count += 1;
    return count;
  }

  List<String> get _availableAssignees {
    final labels = _actions
        .map((item) => item.action.assigneeLabel.trim())
        .where((label) => label.isNotEmpty)
        .toSet()
        .toList();
    labels.sort(
      (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
    );
    return labels;
  }

  bool _matchesSearch(OvaAssignedAction item, String query) {
    return <String>[
      item.action.description,
      item.action.assigneeLabel,
      item.action.typeLabel,
      item.ticket.id.toString(),
      item.ticket.ovaType ?? '',
    ].any((value) => _normalizeValue(value).contains(query));
  }

  bool _isOverdue(OvaAssignedAction item) {
    return item.action.dueDate.isBefore(_todayStart());
  }

  bool _isDueThisWeek(OvaAssignedAction item) {
    final today = _todayStart();
    final nextWeek = today.add(const Duration(days: 7));
    final dueDate = item.action.dueDate;
    return !dueDate.isBefore(today) && dueDate.isBefore(nextWeek);
  }

  bool _isDueLater(OvaAssignedAction item) {
    final nextWeek = _todayStart().add(const Duration(days: 7));
    return !item.action.dueDate.isBefore(nextWeek);
  }

  DateTime _todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _normalizeValue(String value) {
    return value.trim().toLowerCase();
  }

  String get _summaryText {
    if (_isLoading) {
      return _selectedScope == _ActionScope.all
          ? 'Openstaande opvolgacties binnen OVA.'
          : 'Openstaande opvolgacties die aan jou zijn toegewezen.';
    }

    if (_selectedScope == _ActionScope.all) {
      if (_actions.length == 1) {
        return '1 openstaande opvolgactie binnen OVA.';
      }

      return '${_actions.length} openstaande opvolgacties binnen OVA.';
    }

    if (_actions.length == 1) {
      return '1 openstaande opvolgactie die aan jou is toegewezen.';
    }

    return '${_actions.length} openstaande opvolgacties die aan jou zijn toegewezen.';
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
      onRefresh: _loadActions,
      color: kBrandGreenDark,
      child: LayoutBuilder(
        builder: (context, viewportConstraints) {
          final isNarrowPage = viewportConstraints.maxWidth < 760;
          final outerPadding = isNarrowPage
              ? const EdgeInsets.all(16)
              : const EdgeInsets.fromLTRB(24, 20, 24, 24);
          final contentPadding = isNarrowPage
              ? const EdgeInsets.fromLTRB(20, 22, 20, 24)
              : const EdgeInsets.fromLTRB(32, 28, 32, 32);

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: outerPadding,
            children: [
              Container(
                padding: contentPadding,
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(
                    isNarrowPage ? kRadiusLg : kRadius2xl,
                  ),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.embedded && widget.onNavigateBack != null) ...[
                      _BackLink(
                        label: 'OVA overzicht',
                        onTap: widget.onNavigateBack!,
                      ),
                      const SizedBox(height: 14),
                    ],
                    const _Breadcrumb(segments: ['Dashboard', 'OVA', 'Acties']),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, c) {
                        final compact = c.maxWidth < 840;
                        final titleBlock = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedScope == _ActionScope.all
                                  ? 'Alle OVA-acties'
                                  : 'Mijn opvolgacties',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: kTextPrimary,
                                letterSpacing: -0.4,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _summaryText,
                              style: const TextStyle(
                                fontSize: 14.5,
                                color: kTextSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        );
                        return compact
                            ? titleBlock
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [Expanded(child: titleBlock)],
                              );
                      },
                    ),
                    if (_canViewAllActions) ...[
                      const SizedBox(height: 20),
                      _ActionScopeTabs(
                        selectedScope: _selectedScope,
                        onSelected: _selectScope,
                      ),
                    ],
                    const SizedBox(height: 20),
                    _ActionFilters(
                      searchController: _searchController,
                      visibleCount: _filteredActions.length,
                      hasActiveFilters: _hasActiveFilters,
                      activeFilterCount: _activeFilterCount,
                      filtersExpanded: _filtersExpanded,
                      onToggleFilters: _toggleFiltersExpanded,
                      selectedStatus: _selectedStatusFilter,
                      onStatusSelected: _setStatusFilter,
                      selectedDeadline: _selectedDeadlineFilter,
                      onDeadlineSelected: _setDeadlineFilter,
                      selectedType: _selectedTypeFilter,
                      onTypeSelected: _setTypeFilter,
                      showAssignees: _selectedScope == _ActionScope.all,
                      assignees: _availableAssignees,
                      selectedAssignee: _selectedAssignee,
                      onAssigneeSelected: _setAssignee,
                      onClearFilters: _clearFilters,
                      selectedSort: _sortOption,
                      onSortChanged: _setSortOption,
                    ),
                    const SizedBox(height: 24),
                    if (_isLoading)
                      const _ActionsLoadingSkeleton()
                    else if (_error != null)
                      _ActionErrorState(message: _error!, onRetry: _loadActions)
                    else if (_filteredActions.isEmpty)
                      _ActionEmptyState(
                        scope: _selectedScope,
                        filtered: _hasActiveFilters,
                        onClearFilters: _clearFilters,
                      )
                    else
                      _ActionsOverview(
                        actions: _filteredActions,
                        savingActionIds: _savingActionIds,
                        onOpenAction: _openActionDetail,
                        onStatusChanged: _updateActionStatus,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    if (widget.embedded) {
      return ColoredBox(color: kBackground, child: content);
    }

    return Scaffold(
      backgroundColor: kBackground,
      appBar: const MainAppBar(title: 'Mijn OVA-acties'),
      body: content,
    );
  }
}

class _ActionsOverview extends StatelessWidget {
  const _ActionsOverview({
    required this.actions,
    required this.savingActionIds,
    required this.onOpenAction,
    required this.onStatusChanged,
  });

  final List<OvaAssignedAction> actions;
  final Set<int> savingActionIds;
  final ValueChanged<OvaAssignedAction> onOpenAction;
  final Future<void> Function(OvaAssignedAction, bool) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return _ActionsTable(
            actions: actions,
            savingActionIds: savingActionIds,
            onOpenAction: onOpenAction,
            onStatusChanged: onStatusChanged,
          );
        }

        return Column(
          children: List.generate(actions.length, (index) {
            final item = actions[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == actions.length - 1 ? 0 : 12,
              ),
              child: _ActionMobileTile(
                item: item,
                isSaving: savingActionIds.contains(item.action.id),
                onOpenAction: () => onOpenAction(item),
                onStatusChanged: (isOk) => onStatusChanged(item, isOk),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ActionScopeTabs extends StatelessWidget {
  const _ActionScopeTabs({
    required this.selectedScope,
    required this.onSelected,
  });

  final _ActionScope selectedScope;
  final ValueChanged<_ActionScope> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kSurfaceMuted,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionScopeChip(
            label: 'Mijn acties',
            selected: selectedScope == _ActionScope.mine,
            onTap: () => onSelected(_ActionScope.mine),
          ),
          const SizedBox(width: 4),
          _ActionScopeChip(
            label: 'Alle acties',
            selected: selectedScope == _ActionScope.all,
            onTap: () => onSelected(_ActionScope.all),
          ),
        ],
      ),
    );
  }
}

class _ActionScopeChip extends StatelessWidget {
  const _ActionScopeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? kSurface : Colors.transparent,
      borderRadius: BorderRadius.circular(kRadiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadiusSm),
            border: selected
                ? Border.all(color: kBorder)
                : Border.all(color: Colors.transparent),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? kBrandGreenDeep : kTextTertiary,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionFilters extends StatelessWidget {
  const _ActionFilters({
    required this.searchController,
    required this.visibleCount,
    required this.hasActiveFilters,
    required this.activeFilterCount,
    required this.filtersExpanded,
    required this.onToggleFilters,
    required this.selectedStatus,
    required this.onStatusSelected,
    required this.selectedDeadline,
    required this.onDeadlineSelected,
    required this.selectedType,
    required this.onTypeSelected,
    required this.showAssignees,
    required this.assignees,
    required this.selectedAssignee,
    required this.onAssigneeSelected,
    required this.onClearFilters,
    required this.selectedSort,
    required this.onSortChanged,
  });

  final TextEditingController searchController;
  final int visibleCount;
  final bool hasActiveFilters;
  final int activeFilterCount;
  final bool filtersExpanded;
  final VoidCallback onToggleFilters;
  final _ActionStatusFilter selectedStatus;
  final ValueChanged<_ActionStatusFilter> onStatusSelected;
  final _ActionDeadlineFilter selectedDeadline;
  final ValueChanged<_ActionDeadlineFilter> onDeadlineSelected;
  final _ActionTypeFilter selectedType;
  final ValueChanged<_ActionTypeFilter> onTypeSelected;
  final bool showAssignees;
  final List<String> assignees;
  final String? selectedAssignee;
  final ValueChanged<String?> onAssigneeSelected;
  final VoidCallback onClearFilters;
  final OvaSortOption selectedSort;
  final ValueChanged<OvaSortOption> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final searchField = SizedBox(
      width: 340,
      child: TextField(
        controller: searchController,
        style: const TextStyle(fontSize: 14, color: kTextPrimary),
        decoration: InputDecoration(
          hintText: 'Zoeken op actie of ticket…',
          hintStyle: const TextStyle(color: kTextMuted, fontSize: 14),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: kTextTertiary,
          ),
          filled: true,
          fillColor: kSurfaceMuted,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
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
            borderSide: const BorderSide(color: kBrandGreen, width: 1.4),
          ),
        ),
      ),
    );

    final filterButton = OutlinedButton.icon(
      onPressed: onToggleFilters,
      icon: const Icon(Icons.tune_rounded, size: 18),
      label: Text(
        activeFilterCount > 0 ? 'Filters · $activeFilterCount' : 'Filters',
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: filtersExpanded || activeFilterCount > 0
            ? kBrandGreenDeep
            : kTextSecondary,
        backgroundColor: filtersExpanded ? kBrandGreenSubtle : kSurface,
        side: BorderSide(
          color: filtersExpanded || activeFilterCount > 0
              ? kBrandGreenSoft
              : kBorder,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      ),
    );

    final sortButton = PopupMenuButton<OvaSortOption>(
      tooltip: 'Sorteren',
      onSelected: onSortChanged,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: OvaSortOption(
            field: OvaSortField.date,
            direction: selectedSort.field == OvaSortField.date
                ? selectedSort.direction
                : OvaSortDirection.descending,
          ),
          child: Row(
            children: [
              Icon(
                selectedSort.field == OvaSortField.date
                    ? Icons.check_rounded
                    : Icons.calendar_today_rounded,
                size: 18,
                color: selectedSort.field == OvaSortField.date
                    ? kBrandGreenDeep
                    : kTextTertiary,
              ),
              const SizedBox(width: 10),
              const Text('Deadline'),
            ],
          ),
        ),
        PopupMenuItem(
          value: OvaSortOption(
            field: OvaSortField.status,
            direction: selectedSort.field == OvaSortField.status
                ? selectedSort.direction
                : OvaSortDirection.ascending,
          ),
          child: Row(
            children: [
              Icon(
                selectedSort.field == OvaSortField.status
                    ? Icons.check_rounded
                    : Icons.info_outline_rounded,
                size: 18,
                color: selectedSort.field == OvaSortField.status
                    ? kBrandGreenDeep
                    : kTextTertiary,
              ),
              const SizedBox(width: 10),
              const Text('Status'),
            ],
          ),
        ),
        PopupMenuItem(
          value: OvaSortOption(
            field: OvaSortField.type,
            direction: selectedSort.field == OvaSortField.type
                ? selectedSort.direction
                : OvaSortDirection.ascending,
          ),
          child: Row(
            children: [
              Icon(
                selectedSort.field == OvaSortField.type
                    ? Icons.check_rounded
                    : Icons.category_outlined,
                size: 18,
                color: selectedSort.field == OvaSortField.type
                    ? kBrandGreenDeep
                    : kTextTertiary,
              ),
              const SizedBox(width: 10),
              const Text('Type'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: selectedSort.toggle(),
          child: Row(
            children: [
              Icon(
                selectedSort.direction == OvaSortDirection.ascending
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                size: 18,
                color: kTextTertiary,
              ),
              const SizedBox(width: 10),
              Text(
                selectedSort.direction == OvaSortDirection.ascending
                    ? 'Aflopend'
                    : 'Oplopend',
              ),
            ],
          ),
        ),
      ],
      offset: const Offset(0, 44),
      position: PopupMenuPosition.under,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 18, color: kTextSecondary),
            const SizedBox(width: 8),
            Text(
              selectedSort.label,
              style: const TextStyle(
                color: kTextSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final counter = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.view_list_rounded, size: 16, color: kTextMuted),
            const SizedBox(width: 6),
            Text(
              '$visibleCount actie${visibleCount == 1 ? '' : 's'} zichtbaar',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: kTextTertiary,
              ),
            ),
          ],
        );

        final actionsRow = compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchField,
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [filterButton, sortButton],
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  searchField,
                  const SizedBox(width: 10),
                  filterButton,
                  const SizedBox(width: 8),
                  sortButton,
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compact) ...[
              counter,
              const SizedBox(height: 12),
              actionsRow,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: counter),
                  actionsRow,
                ],
              ),
            if (activeFilterCount > 0) ...[
              const SizedBox(height: 14),
              _buildActiveFilters(),
            ],
            if (filtersExpanded) ...[
              const SizedBox(height: 14),
              _ActionFilterPanel(
                selectedStatus: selectedStatus,
                onStatusSelected: onStatusSelected,
                selectedDeadline: selectedDeadline,
                onDeadlineSelected: onDeadlineSelected,
                selectedType: selectedType,
                onTypeSelected: onTypeSelected,
                showAssignees: showAssignees,
                assignees: assignees,
                selectedAssignee: selectedAssignee,
                onAssigneeSelected: onAssigneeSelected,
                hasActiveFilters: hasActiveFilters,
                onClearFilters: onClearFilters,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildActiveFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (selectedStatus != _ActionStatusFilter.all)
          _ActionActiveFilterChip(
            label: 'Status: ${_statusLabel(selectedStatus)}',
            onRemove: () => onStatusSelected(_ActionStatusFilter.all),
          ),
        if (selectedDeadline != _ActionDeadlineFilter.all)
          _ActionActiveFilterChip(
            label: 'Deadline: ${_deadlineLabel(selectedDeadline)}',
            onRemove: () => onDeadlineSelected(_ActionDeadlineFilter.all),
          ),
        if (selectedType != _ActionTypeFilter.all)
          _ActionActiveFilterChip(
            label: 'Type: ${_typeLabel(selectedType)}',
            onRemove: () => onTypeSelected(_ActionTypeFilter.all),
          ),
        if (selectedAssignee != null)
          _ActionActiveFilterChip(
            label: 'Verantwoordelijke: $selectedAssignee',
            onRemove: () => onAssigneeSelected(null),
          ),
        TextButton(
          onPressed: onClearFilters,
          child: const Text('Alle filters wissen'),
        ),
      ],
    );
  }

  String _statusLabel(_ActionStatusFilter filter) {
    switch (filter) {
      case _ActionStatusFilter.nok:
        return 'NOK';
      case _ActionStatusFilter.ok:
        return 'OK';
      case _ActionStatusFilter.all:
        return 'Alles';
    }
  }

  String _deadlineLabel(_ActionDeadlineFilter filter) {
    switch (filter) {
      case _ActionDeadlineFilter.overdue:
        return 'Te laat';
      case _ActionDeadlineFilter.thisWeek:
        return 'Deze week';
      case _ActionDeadlineFilter.later:
        return 'Later';
      case _ActionDeadlineFilter.all:
        return 'Alle deadlines';
    }
  }

  String _typeLabel(_ActionTypeFilter filter) {
    switch (filter) {
      case _ActionTypeFilter.corrective:
        return 'Corrigerend';
      case _ActionTypeFilter.preventive:
        return 'Preventief';
      case _ActionTypeFilter.all:
        return 'Alle types';
    }
  }
}

class _ActionFilterPanel extends StatelessWidget {
  const _ActionFilterPanel({
    required this.selectedStatus,
    required this.onStatusSelected,
    required this.selectedDeadline,
    required this.onDeadlineSelected,
    required this.selectedType,
    required this.onTypeSelected,
    required this.showAssignees,
    required this.assignees,
    required this.selectedAssignee,
    required this.onAssigneeSelected,
    required this.hasActiveFilters,
    required this.onClearFilters,
  });

  final _ActionStatusFilter selectedStatus;
  final ValueChanged<_ActionStatusFilter> onStatusSelected;
  final _ActionDeadlineFilter selectedDeadline;
  final ValueChanged<_ActionDeadlineFilter> onDeadlineSelected;
  final _ActionTypeFilter selectedType;
  final ValueChanged<_ActionTypeFilter> onTypeSelected;
  final bool showAssignees;
  final List<String> assignees;
  final String? selectedAssignee;
  final ValueChanged<String?> onAssigneeSelected;
  final bool hasActiveFilters;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kSurfaceMuted,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fieldCount = showAssignees ? 4 : 3;
          final fieldWidth = constraints.maxWidth < 760
              ? constraints.maxWidth
              : (constraints.maxWidth - (14 * (fieldCount - 1))) / fieldCount;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              _ActionFilterSelectField<_ActionStatusFilter>(
                width: fieldWidth,
                label: 'Status',
                value: selectedStatus,
                options: const [
                  _ActionFilterOption(
                    value: _ActionStatusFilter.nok,
                    label: 'NOK',
                  ),
                  _ActionFilterOption(
                    value: _ActionStatusFilter.ok,
                    label: 'OK',
                  ),
                  _ActionFilterOption(
                    value: _ActionStatusFilter.all,
                    label: 'Alles',
                  ),
                ],
                onChanged: onStatusSelected,
              ),
              _ActionFilterSelectField<_ActionDeadlineFilter>(
                width: fieldWidth,
                label: 'Deadline',
                value: selectedDeadline,
                options: const [
                  _ActionFilterOption(
                    value: _ActionDeadlineFilter.all,
                    label: 'Alle deadlines',
                  ),
                  _ActionFilterOption(
                    value: _ActionDeadlineFilter.overdue,
                    label: 'Te laat',
                  ),
                  _ActionFilterOption(
                    value: _ActionDeadlineFilter.thisWeek,
                    label: 'Deze week',
                  ),
                  _ActionFilterOption(
                    value: _ActionDeadlineFilter.later,
                    label: 'Later',
                  ),
                ],
                onChanged: onDeadlineSelected,
              ),
              _ActionFilterSelectField<_ActionTypeFilter>(
                width: fieldWidth,
                label: 'Type',
                value: selectedType,
                options: const [
                  _ActionFilterOption(
                    value: _ActionTypeFilter.all,
                    label: 'Alle types',
                  ),
                  _ActionFilterOption(
                    value: _ActionTypeFilter.corrective,
                    label: 'Corrigerend',
                  ),
                  _ActionFilterOption(
                    value: _ActionTypeFilter.preventive,
                    label: 'Preventief',
                  ),
                ],
                onChanged: onTypeSelected,
              ),
              if (showAssignees)
                _ActionFilterSelectField<String?>(
                  width: fieldWidth,
                  label: 'Verantwoordelijke',
                  hintText: 'Alle verantwoordelijken',
                  value: selectedAssignee,
                  options: [
                    const _ActionFilterOption<String?>(
                      value: null,
                      label: 'Alle verantwoordelijken',
                    ),
                    ...assignees.map(
                      (assignee) => _ActionFilterOption<String?>(
                        value: assignee,
                        label: assignee,
                      ),
                    ),
                  ],
                  onChanged: onAssigneeSelected,
                ),
              if (hasActiveFilters)
                TextButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Filters wissen'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ActionActiveFilterChip extends StatelessWidget {
  const _ActionActiveFilterChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: kBrandGreenSoft,
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: kBrandGreenSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: kBrandGreenDeep,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.all(5),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: kBrandGreenDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionFilterSelectField<T> extends StatelessWidget {
  const _ActionFilterSelectField({
    required this.width,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hintText,
  });

  final double width;
  final String label;
  final T value;
  final List<_ActionFilterOption<T>> options;
  final ValueChanged<T> onChanged;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: kTextTertiary,
        ),
        style: const TextStyle(
          fontSize: 14,
          color: kTextPrimary,
          fontWeight: FontWeight.w500,
        ),
        hint: hintText == null ? null : Text(hintText!),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: kSurface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
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
            borderSide: const BorderSide(color: kBrandGreen, width: 1.4),
          ),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem<T>(
                value: option.value,
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (value) => onChanged(value as T),
      ),
    );
  }
}

class _ActionFilterOption<T> {
  const _ActionFilterOption({required this.value, required this.label});

  final T value;
  final String label;
}

class _ActionsTable extends StatelessWidget {
  const _ActionsTable({
    required this.actions,
    required this.savingActionIds,
    required this.onOpenAction,
    required this.onStatusChanged,
  });

  final List<OvaAssignedAction> actions;
  final Set<int> savingActionIds;
  final ValueChanged<OvaAssignedAction> onOpenAction;
  final Future<void> Function(OvaAssignedAction, bool) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadiusLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: kSurfaceMuted,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              child: const Row(
                children: [
                  Expanded(flex: 44, child: _TableHeaderLabel('Omschrijving')),
                  SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: _TableHeaderLabel('Verantwoordelijke'),
                  ),
                  SizedBox(width: 12),
                  SizedBox(width: 110, child: _TableHeaderLabel('Ticket')),
                  SizedBox(width: 12),
                  SizedBox(width: 110, child: _TableHeaderLabel('Deadline')),
                  SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: Center(child: _TableHeaderLabel('Status')),
                  ),
                ],
              ),
            ),
            ...List.generate(actions.length, (index) {
              final item = actions[index];
              return _ActionsTableRow(
                item: item,
                striped: index.isOdd,
                isSaving: savingActionIds.contains(item.action.id),
                onOpenAction: () => onOpenAction(item),
                onStatusChanged: (isOk) => onStatusChanged(item, isOk),
              );
            }),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: const BoxDecoration(
                color: kSurfaceMuted,
                border: Border(top: BorderSide(color: kBorder)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: kTextMuted),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Klik op een rij om de actiedetails en het gekoppelde ticket te bekijken.',
                      style: TextStyle(
                        color: kTextTertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionsTableRow extends StatefulWidget {
  const _ActionsTableRow({
    required this.item,
    required this.striped,
    required this.isSaving,
    required this.onOpenAction,
    required this.onStatusChanged,
  });

  final OvaAssignedAction item;
  final bool striped;
  final bool isSaving;
  final VoidCallback onOpenAction;
  final ValueChanged<bool> onStatusChanged;

  @override
  State<_ActionsTableRow> createState() => _ActionsTableRowState();
}

class _ActionsTableRowState extends State<_ActionsTableRow> {
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
          onTap: widget.onOpenAction,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: kBorderSubtle)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 44,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.action.description,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.item.action.typeLabel,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: kTextTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: Text(
                    widget.item.action.assigneeLabel,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: kTextSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: Text(
                    _formatOvaTicketNumber(widget.item.ticket.id),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: kTextSecondary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: Text(
                    formatOvaDate(widget.item.action.dueDate),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: kTextSecondary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: Center(
                    child: _StatusDropdown(
                      isOk: widget.item.action.isOk,
                      isSaving: widget.isSaving,
                      onChanged: widget.onStatusChanged,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionMobileTile extends StatelessWidget {
  const _ActionMobileTile({
    required this.item,
    required this.isSaving,
    required this.onOpenAction,
    required this.onStatusChanged,
  });

  final OvaAssignedAction item;
  final bool isSaving;
  final VoidCallback onOpenAction;
  final ValueChanged<bool> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(kRadiusLg),
      child: InkWell(
        onTap: onOpenAction,
        borderRadius: BorderRadius.circular(kRadiusLg),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadiusLg),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.action.description,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusDropdown(
                    isOk: item.action.isOk,
                    isSaving: isSaving,
                    onChanged: onStatusChanged,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _InfoPill(
                    icon: Icons.confirmation_number_outlined,
                    label: _formatOvaTicketNumber(item.ticket.id),
                  ),
                  _InfoPill(
                    icon: Icons.person_outline,
                    label: item.action.assigneeLabel,
                  ),
                  _InfoPill(
                    icon: Icons.event_rounded,
                    label: 'Deadline ${formatOvaDate(item.action.dueDate)}',
                  ),
                  _InfoPill(
                    icon: Icons.category_outlined,
                    label: item.action.typeLabel,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Details bekijken',
                    style: TextStyle(
                      color: kBrandGreenDark,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: kBrandGreenDark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({
    required this.isOk,
    required this.isSaving,
    required this.onChanged,
  });

  final bool isOk;
  final bool isSaving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final fg = isOk ? kSuccess : kDanger;
    final bg = isOk ? kSuccessBg : kDangerBg;
    final border = isOk ? kSuccessBorder : kDangerBorder;

    return InkWell(
      borderRadius: BorderRadius.circular(kRadiusPill),
      onTap: isSaving
          ? null
          : () async {
              final result = await showMenu<bool>(
                context: context,
                position: _buttonPosition(context),
                items: [
                  _statusMenuItem(value: false, label: 'NOK'),
                  _statusMenuItem(value: true, label: 'OK'),
                ],
              );
              if (result != null) {
                onChanged(result);
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(kRadiusPill),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isOk ? 'OK' : 'NOK',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: fg,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 4),
            if (isSaving)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            else
              Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: fg),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<bool> _statusMenuItem({
    required bool value,
    required String label,
  }) {
    final color = value ? kSuccess : kDanger;

    return PopupMenuItem<bool>(
      value: value,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  RelativeRect _buttonPosition(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

    if (box == null) {
      return RelativeRect.fill;
    }

    return RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(box.size.bottomLeft(Offset.zero), ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kSurfaceMuted,
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: kTextTertiary),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeaderLabel extends StatelessWidget {
  const _TableHeaderLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: kTextTertiary,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _ActionEmptyState extends StatelessWidget {
  const _ActionEmptyState({
    required this.scope,
    required this.filtered,
    required this.onClearFilters,
  });

  final _ActionScope scope;
  final bool filtered;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final isAllScope = scope == _ActionScope.all;

    return AppEmptyState.emphasis(
      icon: filtered ? Icons.filter_alt_off_rounded : Icons.task_alt_rounded,
      title: filtered
          ? 'Geen acties voor deze filters'
          : isAllScope
          ? 'Geen openstaande OVA-acties'
          : 'Je hebt geen openstaande acties',
      message: filtered
          ? 'Pas je zoekterm of filters aan om opnieuw acties te tonen.'
          : isAllScope
          ? 'Zodra er een opvolgactie op een open OVA-ticket staat, verschijnt ze hier automatisch.'
          : 'Zodra een opvolgactie aan jou is toegewezen, verschijnt ze hier automatisch.',
      actionLabel: filtered ? 'Filters wissen' : null,
      onAction: filtered ? onClearFilters : null,
    );
  }
}

class _ActionsLoadingSkeleton extends StatelessWidget {
  const _ActionsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        if (compact) {
          return Column(
            children: List.generate(
              4,
              (i) => Padding(
                padding: EdgeInsets.only(bottom: i == 3 ? 0 : 12),
                child: const AppListRowSkeleton(),
              ),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(kRadiusLg),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  color: kSurfaceMuted,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(kRadiusLg),
                    topRight: Radius.circular(kRadiusLg),
                  ),
                ),
                child: const Row(
                  children: [
                    AppSkeleton(height: 10, width: 100),
                    Spacer(),
                    AppSkeleton(height: 10, width: 60),
                  ],
                ),
              ),
              ...List.generate(
                5,
                (i) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 18,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: kBorderSubtle)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppSkeleton(height: 13, width: 280),
                            SizedBox(height: 8),
                            AppSkeleton(height: 11, width: 90),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: AppSkeleton(height: 12, width: 120),
                      ),
                      SizedBox(width: 12),
                      AppSkeleton(height: 12, width: 60),
                      SizedBox(width: 24),
                      AppSkeleton(height: 12, width: 80),
                      SizedBox(width: 24),
                      AppSkeleton(height: 22, width: 60, borderRadius: 999),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionErrorState extends StatelessWidget {
  const _ActionErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kDangerBg,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kDangerBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: kDanger, size: 28),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: kTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Opnieuw proberen'),
          ),
        ],
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.segments});
  final List<String> segments;

  @override
  Widget build(BuildContext context) {
    return AppBreadcrumb(segments: segments);
  }
}

class _BackLink extends StatelessWidget {
  const _BackLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.arrow_back_rounded,
              color: kBrandGreenDark,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: kBrandGreenDark,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
