import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qa_dashboard/widgets/app_bars/main_app_bar.dart';

import '../models/ova_assigned_action.dart';
import '../models/ova_ticket.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'ova_ticket_wizard_screen.dart';

enum _ActionScope { mine, all }

enum _ActionStatusFilter { nok, ok, all }

enum _ActionDeadlineFilter { all, overdue, thisWeek, later }

enum _ActionTypeFilter { all, corrective, preventive }

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
  _ActionStatusFilter _selectedStatusFilter = _ActionStatusFilter.nok;
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
      _selectedStatusFilter = _ActionStatusFilter.nok;
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

  Future<void> _openTicket(int ticketId) async {
    final result = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) => OvaTicketWizardScreen(
          ticketId: ticketId,
          embedded: widget.embedded,
        ),
      ),
    );

    if (result != null && mounted) {
      await _loadActions();
    }
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

    return actions.toList();
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
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.embedded && widget.onNavigateBack != null) ...[
                  TextButton.icon(
                    onPressed: widget.onNavigateBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('OVA overzicht'),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  _selectedScope == _ActionScope.all
                      ? 'Alle OVA-acties'
                      : 'Mijn acties-overzicht',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_summaryText),
                if (_canViewAllActions) ...[
                  const SizedBox(height: 18),
                  _ActionScopeTabs(
                    selectedScope: _selectedScope,
                    onSelected: _selectScope,
                  ),
                ],
                const SizedBox(height: 18),
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
                ),
                const SizedBox(height: 28),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
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
                    onOpenTicket: (item) => _openTicket(item.ticket.id),
                    onStatusChanged: _updateActionStatus,
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return ColoredBox(color: const Color(0xFFF6F6F3), child: content);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F3),
      appBar: const MainAppBar(title: 'Mijn OVA-acties'),
      body: content,
    );
  }
}

class _ActionsOverview extends StatelessWidget {
  const _ActionsOverview({
    required this.actions,
    required this.savingActionIds,
    required this.onOpenTicket,
    required this.onStatusChanged,
  });

  final List<OvaAssignedAction> actions;
  final Set<int> savingActionIds;
  final ValueChanged<OvaAssignedAction> onOpenTicket;
  final Future<void> Function(OvaAssignedAction, bool) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return _ActionsTable(
            actions: actions,
            savingActionIds: savingActionIds,
            onOpenTicket: onOpenTicket,
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
                onOpenTicket: () => onOpenTicket(item),
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionScopeChip(
          label: 'Mijn acties',
          selected: selectedScope == _ActionScope.mine,
          onTap: () => onSelected(_ActionScope.mine),
        ),
        _ActionScopeChip(
          label: 'Alle acties',
          selected: selectedScope == _ActionScope.all,
          onTap: () => onSelected(_ActionScope.all),
        ),
      ],
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
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFEAF4D9),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF4E721C) : const Color(0xFF4C5448),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFF98C74D) : const Color(0xFFD7DBD2),
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

  @override
  Widget build(BuildContext context) {
    final searchField = SizedBox(
      width: 320,
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: 'Zoeken op actie of ticket',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          filled: true,
          fillColor: const Color(0xFFF4F4F0),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: Color(0xFF8CC63F)),
          ),
        ),
      ),
    );

    final filterButton = OutlinedButton.icon(
      onPressed: onToggleFilters,
      icon: const Icon(Icons.filter_alt_rounded, size: 18),
      label: Text(
        activeFilterCount > 0 ? 'Filters $activeFilterCount' : 'Filters',
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: filtersExpanded || activeFilterCount > 0
            ? const Color(0xFF4E721C)
            : const Color(0xFF3F473B),
        backgroundColor: filtersExpanded
            ? const Color(0xFFEAF4D9)
            : Colors.white,
        side: BorderSide(
          color: filtersExpanded || activeFilterCount > 0
              ? const Color(0xFF98C74D)
              : const Color(0xFFD9DDD1),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final counter = Text(
          '$visibleCount actie${visibleCount == 1 ? '' : 's'} zichtbaar',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF7A8078),
          ),
        );
        final actions = compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchField,
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerLeft, child: filterButton),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  searchField,
                  const SizedBox(width: 10),
                  filterButton,
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compact) ...[
              counter,
              const SizedBox(height: 12),
              actions,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: counter),
                  actions,
                ],
              ),
            if (activeFilterCount > 0) ...[
              const SizedBox(height: 12),
              _buildActiveFilters(),
            ],
            if (filtersExpanded) ...[
              const SizedBox(height: 12),
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
          child: const Text('Filters wissen'),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E6DD)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fieldCount = showAssignees ? 4 : 3;
          final fieldWidth = constraints.maxWidth < 760
              ? constraints.maxWidth
              : (constraints.maxWidth - (12 * (fieldCount - 1))) / fieldCount;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
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
                TextButton(
                  onPressed: onClearFilters,
                  child: const Text('Filters wissen'),
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
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4D9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFCFE5A8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF4E721C),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: Color(0xFF4E721C),
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
        hint: hintText == null ? null : Text(hintText!),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD9DDD1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD9DDD1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF8CC63F)),
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
    required this.onOpenTicket,
    required this.onStatusChanged,
  });

  final List<OvaAssignedAction> actions;
  final Set<int> savingActionIds;
  final ValueChanged<OvaAssignedAction> onOpenTicket;
  final Future<void> Function(OvaAssignedAction, bool) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E6DD)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: const Color(0xFFF6F7F2),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: const Row(
                children: [
                  Expanded(flex: 44, child: _TableHeaderLabel('Omschrijving')),
                  SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: _TableHeaderLabel('Verantwoordelijke'),
                  ),
                  SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: _TableHeaderLabel('Ticketnummer'),
                  ),
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
                onOpenTicket: () => onOpenTicket(item),
                onStatusChanged: (isOk) => onStatusChanged(item, isOk),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ActionsTableRow extends StatelessWidget {
  const _ActionsTableRow({
    required this.item,
    required this.striped,
    required this.isSaving,
    required this.onOpenTicket,
    required this.onStatusChanged,
  });

  final OvaAssignedAction item;
  final bool striped;
  final bool isSaving;
  final VoidCallback onOpenTicket;
  final ValueChanged<bool> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: striped ? const Color(0xFFF9FAF6) : Colors.white,
      child: InkWell(
        onTap: onOpenTicket,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE8ECE3))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 44,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.action.description,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2F382E),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.action.typeLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7B8077),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: Text(
                  item.action.assigneeLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF4D5548),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: Text(
                  '#${item.ticket.id}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4D5548),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: Text(
                  formatOvaDate(item.action.dueDate),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF4D5548),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: Center(
                  child: _StatusDropdown(
                    isOk: item.action.isOk,
                    isSaving: isSaving,
                    onChanged: onStatusChanged,
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

class _ActionMobileTile extends StatelessWidget {
  const _ActionMobileTile({
    required this.item,
    required this.isSaving,
    required this.onOpenTicket,
    required this.onStatusChanged,
  });

  final OvaAssignedAction item;
  final bool isSaving;
  final VoidCallback onOpenTicket;
  final ValueChanged<bool> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onOpenTicket,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E6DD)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.action.description,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2F382E),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _InfoPill(label: 'Ticket #${item.ticket.id}'),
                  _InfoPill(label: item.action.assigneeLabel),
                  _InfoPill(
                    label: 'Deadline ${formatOvaDate(item.action.dueDate)}',
                  ),
                  _InfoPill(label: item.action.typeLabel),
                  _StatusDropdown(
                    isOk: item.action.isOk,
                    isSaving: isSaving,
                    onChanged: onStatusChanged,
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
    final foregroundColor = isOk
        ? const Color(0xFF6B8F2A)
        : const Color(0xFFC43C33);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isOk ? const Color(0xFFEAF4D9) : const Color(0xFFFFECEB),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isOk ? const Color(0xFF98C74D) : const Color(0xFFE8A09C),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isOk ? 'OK' : 'NOK',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: foregroundColor,
              ),
            ),
            const SizedBox(width: 4),
            if (isSaving)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor,
                ),
              )
            else
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: foregroundColor,
              ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<bool> _statusMenuItem({
    required bool value,
    required String label,
  }) {
    final color = value ? const Color(0xFF6B8F2A) : const Color(0xFFC43C33);

    return PopupMenuItem<bool>(
      value: value,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label),
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
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E6DD)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF545C50),
        ),
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
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF545C50),
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

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE6C7)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.task_alt_rounded,
            size: 44,
            color: Color(0xFF6B8F2A),
          ),
          const SizedBox(height: 14),
          Text(
            filtered
                ? 'Geen acties voor deze filters'
                : isAllScope
                ? 'Geen openstaande OVA-acties'
                : 'Je hebt geen openstaande acties',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            filtered
                ? 'Pas je zoekterm of filters aan om opnieuw acties te tonen.'
                : isAllScope
                ? 'Zodra er een opvolgactie op een open OVA-ticket staat, verschijnt ze hier automatisch.'
                : 'Zodra een opvolgactie aan jou is toegewezen, verschijnt ze hier automatisch.',
            textAlign: TextAlign.center,
          ),
          if (filtered) ...[
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onClearFilters,
              child: const Text('Filters wissen'),
            ),
          ],
        ],
      ),
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
        color: const Color(0xFFFFF6F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF1C9C9)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Opnieuw proberen'),
          ),
        ],
      ),
    );
  }
}
