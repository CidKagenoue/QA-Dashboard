import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qa_dashboard/screens/ova_ticket_detail_screen.dart';
import 'package:qa_dashboard/widgets/app_bars/main_app_bar.dart';

import '../models/ova_ticket.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'ova_ticket_wizard_screen.dart';

enum _TicketSection { open, closed }

const List<String> _reasonFilterOptions = [
  'Klacht',
  'Audit',
  'Incident',
  'Risico',
  'Andere',
];

const double _ticketTableColumnGap = 10;
const int _ticketIdFlex = 6;
const int _ticketStatusFlex = 9;
const int _ticketTypeFlex = 10;
const int _ticketDateFlex = 13;
const int _ticketReasonsFlex = 24;
const int _ticketDescriptionFlex = 32;

class OvaTicketListScreen extends StatefulWidget {
  const OvaTicketListScreen({
    super.key,
    this.embedded = false,
    this.onNavigateBack,
  });

  final bool embedded;
  final VoidCallback? onNavigateBack;

  @override
  State<OvaTicketListScreen> createState() => _OvaTicketListScreenState();
}

class _OvaTicketListScreenState extends State<OvaTicketListScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  List<OvaTicket> _tickets = const [];
  _TicketSection _selectedSection = _TicketSection.open;
  String? _selectedOvaType;
  int? _selectedDepartmentId;
  int? _selectedBranchId;
  String? _selectedReason;
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _loadTickets();
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await context.read<AuthService>().getValidAccessToken();
      final response = await ApiService.fetchOvaTickets(token: token);
      if (!mounted) return;
      setState(() {
        _tickets = response.map(OvaTicket.fromJson).toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openTicket({int? ticketId}) async {
    final resultingSection = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (context) => OvaTicketWizardScreen(
          ticketId: ticketId,
          embedded: widget.embedded,
        ),
      ),
    );

    if (resultingSection == null || !mounted) return;

    final targetSection = _sectionForResult(resultingSection);
    await _loadTickets();
    if (!mounted) return;

    setState(() {
      _selectedSection = targetSection;
    });
  }

  Future<void> _openTicketDetail(OvaTicket ticket) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => OvaTicketDetailScreen(
          ticket: ticket,
          onClose: () => Navigator.of(context).pop(true),
        ),
      ),
    );

    // Reload als er wijzigingen waren
    if (result == true && mounted) {
      await _loadTickets();
    }
  }

  void _selectSection(_TicketSection section) {
    if (_selectedSection == section) return;
    setState(() {
      _selectedSection = section;
    });
  }

  void _setOvaType(String? type) {
    setState(() {
      _selectedOvaType = type;
    });
  }

  void _setDepartment(int? id) {
    setState(() {
      _selectedDepartmentId = id;
    });
  }

  void _setBranch(int? id) {
    setState(() {
      _selectedBranchId = id;
    });
  }

  void _setReason(String? reason) {
    setState(() {
      _selectedReason = reason;
    });
  }

  void _toggleFiltersExpanded() {
    setState(() {
      _filtersExpanded = !_filtersExpanded;
    });
  }

  void _clearFilters() {
    if (!_hasActiveFilters) return;
    _searchController.clear();
    setState(() {
      _selectedOvaType = null;
      _selectedDepartmentId = null;
      _selectedBranchId = null;
      _selectedReason = null;
    });
  }

  _TicketSection _sectionForResult(String value) {
    switch (_normalizeValue(value)) {
      case 'closed':
      case 'completed':
        return _TicketSection.closed;
      case 'open':
        return _TicketSection.open;
      default:
        return _TicketSection.open;
    }
  }

  bool _isOpenTicket(OvaTicket ticket) => !ticket.isClosed;

  List<OvaTicket> _sortTickets(Iterable<OvaTicket> tickets) {
    final sorted = tickets.toList();
    sorted.sort((l, r) {
      final ld = l.findingDate ?? l.updatedAt;
      final rd = r.findingDate ?? r.updatedAt;
      final byDate = ld.compareTo(rd);
      return byDate != 0 ? byDate : l.id.compareTo(r.id);
    });
    return sorted;
  }

  List<OvaTicket> get _openTickets =>
      _sortTickets(_tickets.where(_isOpenTicket));
  List<OvaTicket> get _closedTickets =>
      _sortTickets(_tickets.where((t) => t.isClosed));
  List<String> get _availableOvaTypes => _resolveAvailableOvaTypes(_tickets);
  List<OvaTicketOption> get _availableDepartments =>
      _resolveAvailableOptions(_tickets.map((ticket) => ticket.department));
  List<OvaTicketOption> get _availableBranches =>
      _resolveAvailableOptions(_tickets.map((ticket) => ticket.branch));

  List<OvaTicket> get _filteredTickets {
    final query = _normalizeValue(_searchController.text);
    Iterable<OvaTicket> tickets;
    switch (_selectedSection) {
      case _TicketSection.open:
        tickets = _openTickets;
      case _TicketSection.closed:
        tickets = _closedTickets;
    }
    if (query.isNotEmpty) {
      tickets = tickets.where((t) => _matchesSearch(t, query));
    }
    if (_selectedOvaType != null && _selectedOvaType!.trim().isNotEmpty) {
      tickets = tickets.where((t) => _sameOvaType(t.ovaType, _selectedOvaType));
    }
    if (_selectedDepartmentId != null) {
      tickets = tickets.where(
        (ticket) => ticket.department?.id == _selectedDepartmentId,
      );
    }
    if (_selectedBranchId != null) {
      tickets = tickets.where(
        (ticket) => ticket.branch?.id == _selectedBranchId,
      );
    }
    if (_selectedReason != null && _selectedReason!.trim().isNotEmpty) {
      tickets = tickets.where(
        (ticket) => _matchesReason(ticket, _selectedReason!),
      );
    }
    return tickets.toList();
  }

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty ||
      (_selectedOvaType != null && _selectedOvaType!.trim().isNotEmpty) ||
      _selectedDepartmentId != null ||
      _selectedBranchId != null ||
      (_selectedReason != null && _selectedReason!.trim().isNotEmpty);

  int get _activeFilterCount {
    var count = 0;
    if (_selectedOvaType != null && _selectedOvaType!.trim().isNotEmpty) {
      count += 1;
    }
    if (_selectedBranchId != null) count += 1;
    if (_selectedDepartmentId != null) count += 1;
    if (_selectedReason != null && _selectedReason!.trim().isNotEmpty) {
      count += 1;
    }
    return count;
  }

  String? get _selectedDepartmentLabel {
    for (final department in _availableDepartments) {
      if (department.id == _selectedDepartmentId) return department.name;
    }
    return null;
  }

  String? get _selectedBranchLabel {
    for (final branch in _availableBranches) {
      if (branch.id == _selectedBranchId) return branch.name;
    }
    return null;
  }

  bool _matchesSearch(OvaTicket ticket, String query) {
    return <String>[
      ticket.id.toString(),
      _ticketDescription(ticket),
      _reasonsLabel(ticket),
      ticket.ovaType ?? '',
      ticket.department?.name ?? '',
      ticket.branch?.name ?? '',
      ticket.statusLabel,
      ticket.createdBy.displayName,
      ticket.lastEditedBy.displayName,
    ].any((v) => _normalizeValue(v).contains(query));
  }

  bool _matchesReason(OvaTicket ticket, String reason) {
    final normalizedReason = _normalizeValue(reason);
    final hasReason = ticket.reasons.any(
      (item) => _normalizeValue(item) == normalizedReason,
    );
    if (hasReason) {
      return true;
    }

    return normalizedReason == 'andere' &&
        (ticket.otherReason ?? '').trim().isNotEmpty;
  }

  String _ticketDescription(OvaTicket ticket) {
    for (final c in [ticket.incidentDescription, ticket.followUpActions]) {
      final n = c?.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (n != null && n.isNotEmpty) return n;
    }
    return '-';
  }

  String _sectionStatusLabel(OvaTicket ticket) {
    if (ticket.isClosed) {
      return 'Gesloten';
    }

    return 'Open';
  }

  String _actionProgressLabel(OvaTicket ticket) {
    if (ticket.actions.isEmpty) {
      return '-';
    }

    final done = ticket.actions.where((a) => a.isOk).length;
    return '$done/${ticket.actions.length}';
  }

  String _ticketTypeLabel(OvaTicket ticket) {
    final type = ticket.ovaType?.trim();
    return (type == null || type.isEmpty) ? '-' : type;
  }

  String _reasonsLabel(OvaTicket ticket) {
    final labels = <String>[
      ...ticket.reasons,
      if ((ticket.otherReason ?? '').trim().isNotEmpty)
        'Andere: ${ticket.otherReason!.trim()}',
    ];

    if (labels.isEmpty) {
      return '-';
    }

    return labels.join(', ');
  }

  String _causeAnalysisLabel(OvaTicket ticket) {
    final method = ticket.causeAnalysisMethod?.trim();
    final notes = ticket.causeAnalysisNotes?.trim();

    if (method != null && method.isNotEmpty) {
      return method;
    }

    if (notes != null && notes.isNotEmpty) {
      return 'Notities ingevuld';
    }

    return '-';
  }

  String _effectivenessLabel(OvaTicket ticket) {
    final effectivenessDate = ticket.effectivenessDate;
    if (effectivenessDate != null) {
      return formatOvaDate(effectivenessDate);
    }

    final notes = ticket.effectivenessNotes?.trim();
    if (notes != null && notes.isNotEmpty) {
      return 'Notities ingevuld';
    }

    return '-';
  }

  String _closedInfoLabel(OvaTicket ticket) {
    if (!ticket.isClosed) {
      return '-';
    }

    final date = formatOvaDate(ticket.closedAt ?? ticket.updatedAt);
    final user = ticket.closedBy?.displayName;
    if (user == null || user.trim().isEmpty) {
      return date;
    }

    return '$date door $user';
  }

  String _lastEditedLabel(OvaTicket ticket) {
    return '${formatOvaDate(ticket.updatedAt)} door ${ticket.lastEditedBy.displayName}';
  }

  String _normalizeValue(String? value) {
    return value?.trim().toLowerCase() ?? '';
  }

  bool _sameOvaType(String? l, String? r) =>
      _normalizeValue(l) == _normalizeValue(r);

  List<String> _resolveAvailableOvaTypes(List<OvaTicket> tickets) {
    const preferred = ['Near Miss', 'OVA 3', 'OVA 2', 'OVA 1'];
    final types = tickets
        .map((t) => t.ovaType?.trim())
        .whereType<String>()
        .where((t) => t.isNotEmpty)
        .toList();
    final ordered = <String>[];
    for (final p in preferred) {
      final match = types.where((t) => _sameOvaType(t, p));
      if (match.isNotEmpty) ordered.add(match.first);
    }
    for (final t in types) {
      if (!ordered.any((e) => _sameOvaType(e, t))) ordered.add(t);
    }
    return ordered;
  }

  List<OvaTicketOption> _resolveAvailableOptions(
    Iterable<OvaTicketOption?> options,
  ) {
    final byId = <int, OvaTicketOption>{};
    for (final option in options) {
      if (option == null || option.name.trim().isEmpty) {
        continue;
      }
      byId.putIfAbsent(option.id, () => option);
    }

    final ordered = byId.values.toList();
    ordered.sort(
      (left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );
    return ordered;
  }

  int _ticketCountForSection(_TicketSection s) {
    switch (s) {
      case _TicketSection.open:
        return _openTickets.length;
      case _TicketSection.closed:
        return _closedTickets.length;
    }
  }

  String _emptyTitleForSection(_TicketSection s) {
    switch (s) {
      case _TicketSection.open:
        return 'Geen open tickets';
      case _TicketSection.closed:
        return 'Geen gesloten tickets';
    }
  }

  String _emptyMessageForSection(_TicketSection s) {
    switch (s) {
      case _TicketSection.open:
        return 'Alle tickets die nog niet afgesloten zijn verschijnen hier.';
      case _TicketSection.closed:
        return 'Afgesloten tickets blijven hier zichtbaar zodat de historiek bewaard blijft.';
    }
  }

  // ---------------------------------------------------------------------------
  // Build — geen Scaffold/AppBar
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.user;
    final canCreate = user != null && (user.isAdmin || user.access.ova);
    final pageBackground = Theme.of(context).scaffoldBackgroundColor;

    final content = RefreshIndicator(
      onRefresh: _loadTickets,
      child: LayoutBuilder(
        builder: (context, viewportConstraints) {
          final isNarrowPage = viewportConstraints.maxWidth < 760;
          final outerPadding = isNarrowPage
              ? const EdgeInsets.all(16)
              : const EdgeInsets.fromLTRB(24, 20, 24, 24);
          final contentPadding = isNarrowPage
              ? const EdgeInsets.fromLTRB(20, 20, 20, 24)
              : const EdgeInsets.fromLTRB(32, 28, 32, 32);
          final minContentHeight = math.max(
            0.0,
            viewportConstraints.maxHeight - outerPadding.vertical,
          );

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: outerPadding,
            children: [
              Container(
                width: double.infinity,
                constraints: BoxConstraints(minHeight: minContentHeight),
                padding: contentPadding,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isNarrowPage ? 18 : 24),
                  border: Border.all(color: const Color(0xFFE2E6DD)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
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
                    // Breadcrumb
                    const Text(
                      'Dashboard > OVA > Tickets',
                      style: TextStyle(fontSize: 11, color: Color(0xFF7B8077)),
                    ),
                    const SizedBox(height: 18),

                    // Titel + knop
                    LayoutBuilder(
                      builder: (context, c) {
                        final compact = c.maxWidth < 840;
                        final titleBlock = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OVA Tickets',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF243022),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Bekijk alle tickets per status en open elk ticket rechtstreeks voor detailopvolging.',
                              style: TextStyle(
                                color: Color(0xFF586154),
                                height: 1.45,
                              ),
                            ),
                          ],
                        );

                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              titleBlock,
                              if (canCreate) ...[
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => _openTicket(),
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Nieuw ticket'),
                                ),
                              ],
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: titleBlock),
                            if (canCreate)
                              ElevatedButton.icon(
                                onPressed: () => _openTicket(),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Nieuw ticket'),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 28),

                    // Sectie tabs
                    _SectionTabs(
                      selectedSection: _selectedSection,
                      counts: {
                        _TicketSection.open: _ticketCountForSection(
                          _TicketSection.open,
                        ),
                        _TicketSection.closed: _ticketCountForSection(
                          _TicketSection.closed,
                        ),
                      },
                      onSelected: _selectSection,
                    ),
                    const SizedBox(height: 18),
                    _TicketStatusGuide(section: _selectedSection),
                    const SizedBox(height: 24),

                    // Content
                    if (_isLoading)
                      const SizedBox(
                        height: 260,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      _ErrorState(message: _error!, onRetry: _loadTickets)
                    else if (_tickets.isEmpty)
                      _EmptyTicketState(
                        canCreate: canCreate,
                        onCreate: canCreate ? () => _openTicket() : null,
                      )
                    else ...[
                      _TicketToolbar(
                        searchController: _searchController,
                        hasActiveFilters: _hasActiveFilters,
                        activeFilterCount: _activeFilterCount,
                        filtersExpanded: _filtersExpanded,
                        onToggleFilters: _toggleFiltersExpanded,
                        availableOvaTypes: _availableOvaTypes,
                        selectedOvaType: _selectedOvaType,
                        onOvaTypeChanged: _setOvaType,
                        availableDepartments: _availableDepartments,
                        selectedDepartmentId: _selectedDepartmentId,
                        selectedDepartmentLabel: _selectedDepartmentLabel,
                        onDepartmentChanged: _setDepartment,
                        availableBranches: _availableBranches,
                        selectedBranchId: _selectedBranchId,
                        selectedBranchLabel: _selectedBranchLabel,
                        onBranchChanged: _setBranch,
                        reasonOptions: _reasonFilterOptions,
                        selectedReason: _selectedReason,
                        onReasonChanged: _setReason,
                        onClearFilters: _clearFilters,
                        visibleCount: _filteredTickets.length,
                      ),
                      const SizedBox(height: 18),
                      if (_filteredTickets.isEmpty)
                        _SectionEmptyState(
                          title: _emptyTitleForSection(_selectedSection),
                          message: _emptyMessageForSection(_selectedSection),
                          filtered: _hasActiveFilters,
                          onClearFilters: _clearFilters,
                        )
                      else
                        _buildSelectedTable(),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    if (widget.embedded) {
      return ColoredBox(color: pageBackground, child: content);
    }

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: const MainAppBar(title: 'Vlotter'),
      body: content,
    );
  }

  Widget _buildSelectedTable() {
    return _TicketTable(
      minWidth: 1080,
      columns: const [
        _TableColumnData(label: 'ID', flex: _ticketIdFlex),
        _TableColumnData(label: 'Status', flex: _ticketStatusFlex),
        _TableColumnData(label: 'Type OVA', flex: _ticketTypeFlex),
        _TableColumnData(label: 'Datum vaststelling', flex: _ticketDateFlex),
        _TableColumnData(label: 'Redenen', flex: _ticketReasonsFlex),
        _TableColumnData(label: 'Omschrijving', flex: _ticketDescriptionFlex),
      ],
      rows: List<Widget>.generate(_filteredTickets.length, (index) {
        final ticket = _filteredTickets[index];
        return _TicketTableRow(
          striped: index.isOdd,
          onTap: () => _openTicketDetail(ticket),
          cells: [
            _TableCellData(
              flex: _ticketIdFlex,
              child: Text(
                ticket.id.toString().padLeft(4, '0'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            _TableCellData(
              flex: _ticketStatusFlex,
              child: _TicketStatusChip(label: _sectionStatusLabel(ticket)),
            ),
            _TableCellData(
              flex: _ticketTypeFlex,
              child: _OvaTypeChip(label: _ticketTypeLabel(ticket)),
            ),
            _TableCellData(
              flex: _ticketDateFlex,
              child: _CellText(
                formatOvaDate(ticket.findingDate ?? ticket.updatedAt),
              ),
            ),
            _TableCellData(
              flex: _ticketReasonsFlex,
              child: _CellText(_reasonsLabel(ticket), emphasized: true),
            ),
            _TableCellData(
              flex: _ticketDescriptionFlex,
              child: _CellText(_ticketDescription(ticket), emphasized: true),
            ),
          ],
        );
      }),
    );
  }
}
// ---------------------------------------------------------------------------
// Sectie tabs
// ---------------------------------------------------------------------------

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({
    required this.selectedSection,
    required this.counts,
    required this.onSelected,
  });

  final _TicketSection selectedSection;
  final Map<_TicketSection, int> counts;
  final ValueChanged<_TicketSection> onSelected;

  String _label(_TicketSection s) {
    switch (s) {
      case _TicketSection.open:
        return 'Open Tickets';
      case _TicketSection.closed:
        return 'Gesloten Tickets';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE4E7DE))),
      ),
      child: Wrap(
        spacing: 28,
        runSpacing: 10,
        children: _TicketSection.values.map((s) {
          final selected = s == selectedSection;
          return InkWell(
            onTap: () => onSelected(s),
            child: Container(
              padding: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected
                        ? const Color(0xFF8CC63F)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                '${_label(s)} (${counts[s] ?? 0})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: const Color(0xFF2F382E),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TicketStatusGuide extends StatelessWidget {
  const _TicketStatusGuide({required this.section});

  final _TicketSection section;

  @override
  Widget build(BuildContext context) {
    switch (section) {
      case _TicketSection.open:
        return const _StatusGuideCard(
          title: 'Open',
          description:
              'Alle tickets die nog niet afgesloten zijn staan hier. Ontbrekende onderdelen worden in de tabel met een streepje aangeduid.',
          color: Color(0xFFFFF1EF),
          iconColor: Color(0xFFC43C33),
        );
      case _TicketSection.closed:
        return const _StatusGuideCard(
          title: 'Gesloten',
          description:
              'Dit ticket is afgehandeld. Het blijft zichtbaar als historiek en bewijs van de uitgevoerde opvolging.',
          color: Color(0xFFEAF4D9),
          iconColor: Color(0xFF6F972D),
        );
    }
  }
}

class _StatusGuideCard extends StatelessWidget {
  const _StatusGuideCard({
    required this.title,
    required this.description,
    required this.color,
    required this.iconColor,
  });

  final String title;
  final String description;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(Icons.info_outline_rounded, color: iconColor, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF475142),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketToolbar extends StatelessWidget {
  const _TicketToolbar({
    required this.searchController,
    required this.hasActiveFilters,
    required this.activeFilterCount,
    required this.filtersExpanded,
    required this.onToggleFilters,
    required this.availableOvaTypes,
    required this.selectedOvaType,
    required this.onOvaTypeChanged,
    required this.availableDepartments,
    required this.selectedDepartmentId,
    required this.selectedDepartmentLabel,
    required this.onDepartmentChanged,
    required this.availableBranches,
    required this.selectedBranchId,
    required this.selectedBranchLabel,
    required this.onBranchChanged,
    required this.reasonOptions,
    required this.selectedReason,
    required this.onReasonChanged,
    required this.onClearFilters,
    required this.visibleCount,
  });

  final TextEditingController searchController;
  final bool hasActiveFilters;
  final int activeFilterCount;
  final bool filtersExpanded;
  final VoidCallback onToggleFilters;
  final List<String> availableOvaTypes;
  final String? selectedOvaType;
  final ValueChanged<String?> onOvaTypeChanged;
  final List<OvaTicketOption> availableDepartments;
  final int? selectedDepartmentId;
  final String? selectedDepartmentLabel;
  final ValueChanged<int?> onDepartmentChanged;
  final List<OvaTicketOption> availableBranches;
  final int? selectedBranchId;
  final String? selectedBranchLabel;
  final ValueChanged<int?> onBranchChanged;
  final List<String> reasonOptions;
  final String? selectedReason;
  final ValueChanged<String?> onReasonChanged;
  final VoidCallback onClearFilters;
  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    final searchField = SizedBox(
      width: 320,
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: 'Zoeken',
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
      builder: (context, c) {
        final compact = c.maxWidth < 940;
        final counter = Text(
          '$visibleCount ticket${visibleCount == 1 ? '' : 's'} zichtbaar',
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (selectedOvaType != null &&
                      selectedOvaType!.trim().isNotEmpty)
                    _ActiveFilterChip(
                      label: 'Type: $selectedOvaType',
                      onRemove: () => onOvaTypeChanged(null),
                    ),
                  if (selectedBranchId != null && selectedBranchLabel != null)
                    _ActiveFilterChip(
                      label: 'Vestiging: $selectedBranchLabel',
                      onRemove: () => onBranchChanged(null),
                    ),
                  if (selectedDepartmentId != null &&
                      selectedDepartmentLabel != null)
                    _ActiveFilterChip(
                      label: 'Afdeling: $selectedDepartmentLabel',
                      onRemove: () => onDepartmentChanged(null),
                    ),
                  if (selectedReason != null &&
                      selectedReason!.trim().isNotEmpty)
                    _ActiveFilterChip(
                      label: 'Aanleiding: $selectedReason',
                      onRemove: () => onReasonChanged(null),
                    ),
                  TextButton(
                    onPressed: onClearFilters,
                    child: const Text('Filters wissen'),
                  ),
                ],
              ),
            ],
            if (filtersExpanded) ...[
              const SizedBox(height: 12),
              _TicketFilterPanel(
                availableOvaTypes: availableOvaTypes,
                selectedOvaType: selectedOvaType,
                onOvaTypeChanged: onOvaTypeChanged,
                availableDepartments: availableDepartments,
                selectedDepartmentId: selectedDepartmentId,
                onDepartmentChanged: onDepartmentChanged,
                availableBranches: availableBranches,
                selectedBranchId: selectedBranchId,
                onBranchChanged: onBranchChanged,
                reasonOptions: reasonOptions,
                selectedReason: selectedReason,
                onReasonChanged: onReasonChanged,
                hasActiveFilters: hasActiveFilters,
                onClearFilters: onClearFilters,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _TicketFilterPanel extends StatelessWidget {
  const _TicketFilterPanel({
    required this.availableOvaTypes,
    required this.selectedOvaType,
    required this.onOvaTypeChanged,
    required this.availableDepartments,
    required this.selectedDepartmentId,
    required this.onDepartmentChanged,
    required this.availableBranches,
    required this.selectedBranchId,
    required this.onBranchChanged,
    required this.reasonOptions,
    required this.selectedReason,
    required this.onReasonChanged,
    required this.hasActiveFilters,
    required this.onClearFilters,
  });

  final List<String> availableOvaTypes;
  final String? selectedOvaType;
  final ValueChanged<String?> onOvaTypeChanged;
  final List<OvaTicketOption> availableDepartments;
  final int? selectedDepartmentId;
  final ValueChanged<int?> onDepartmentChanged;
  final List<OvaTicketOption> availableBranches;
  final int? selectedBranchId;
  final ValueChanged<int?> onBranchChanged;
  final List<String> reasonOptions;
  final String? selectedReason;
  final ValueChanged<String?> onReasonChanged;
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
          final fieldWidth = constraints.maxWidth < 760
              ? constraints.maxWidth
              : (constraints.maxWidth - 36) / 4;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              _FilterSelectField<String>(
                width: fieldWidth,
                label: 'OVA-type',
                value: selectedOvaType,
                allLabel: 'Alle types',
                options: availableOvaTypes
                    .map((type) => _FilterOption(value: type, label: type))
                    .toList(),
                onChanged: onOvaTypeChanged,
              ),
              _FilterSelectField<int>(
                width: fieldWidth,
                label: 'Vestiging',
                value: selectedBranchId,
                allLabel: 'Alle vestigingen',
                options: availableBranches
                    .map(
                      (branch) =>
                          _FilterOption(value: branch.id, label: branch.name),
                    )
                    .toList(),
                onChanged: onBranchChanged,
              ),
              _FilterSelectField<int>(
                width: fieldWidth,
                label: 'Afdeling',
                value: selectedDepartmentId,
                allLabel: 'Alle afdelingen',
                options: availableDepartments
                    .map(
                      (department) => _FilterOption(
                        value: department.id,
                        label: department.name,
                      ),
                    )
                    .toList(),
                onChanged: onDepartmentChanged,
              ),
              _FilterSelectField<String>(
                width: fieldWidth,
                label: 'Aanleiding',
                value: selectedReason,
                allLabel: 'Alle aanleidingen',
                options: reasonOptions
                    .map(
                      (reason) => _FilterOption(value: reason, label: reason),
                    )
                    .toList(),
                onChanged: onReasonChanged,
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

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label, required this.onRemove});

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

class _FilterSelectField<T extends Object> extends StatelessWidget {
  const _FilterSelectField({
    required this.width,
    required this.label,
    required this.value,
    required this.allLabel,
    required this.options,
    required this.onChanged,
  });

  final double width;
  final String label;
  final T? value;
  final String allLabel;
  final List<_FilterOption<T>> options;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T?>(
        initialValue: value,
        isExpanded: true,
        hint: Text(allLabel),
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
        items: [
          DropdownMenuItem<T?>(value: null, child: Text(allLabel)),
          ...options.map(
            (option) => DropdownMenuItem<T?>(
              value: option.value,
              child: Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _FilterOption<T extends Object> {
  const _FilterOption({required this.value, required this.label});

  final T value;
  final String label;
}

// ---------------------------------------------------------------------------
// Tabel
// ---------------------------------------------------------------------------

class _TicketTable extends StatelessWidget {
  const _TicketTable({
    required this.minWidth,
    required this.columns,
    required this.rows,
  });

  final double minWidth;
  final List<_TableColumnData> columns;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = math.max(c.maxWidth, minWidth).toDouble();
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E6DD)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: w,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TableHeader(columns: columns),
                    ...rows,
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
                        'Klik op een rij om alle details, oorzakenanalyse en opvolgacties te openen.',
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
            ),
          ),
        );
      },
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.columns});
  final List<_TableColumnData> columns;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F7F2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: _withTableColumnGaps(
          columns.map((column) {
            return Expanded(
              flex: column.flex,
              child: Align(
                alignment: column.alignment,
                child: Text(
                  column.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF545C50),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TicketTableRow extends StatelessWidget {
  const _TicketTableRow({
    required this.cells,
    required this.onTap,
    required this.striped,
  });

  final List<_TableCellData> cells;
  final VoidCallback onTap;
  final bool striped;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: striped ? const Color(0xFFF9FAF6) : Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE8ECE3))),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: _withTableColumnGaps(
              cells.map((cell) {
                return Expanded(
                  flex: cell.flex,
                  child: Align(alignment: cell.alignment, child: cell.child),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

List<Widget> _withTableColumnGaps(List<Widget> children) {
  final spacedChildren = <Widget>[];

  for (var index = 0; index < children.length; index += 1) {
    if (index > 0) {
      spacedChildren.add(const SizedBox(width: _ticketTableColumnGap));
    }

    spacedChildren.add(children[index]);
  }

  return spacedChildren;
}

class _TableColumnData {
  const _TableColumnData({
    required this.label,
    required this.flex,
    this.alignment = Alignment.centerLeft,
  });
  final String label;
  final int flex;
  final Alignment alignment;
}

class _TableCellData {
  const _TableCellData({
    required this.flex,
    required this.child,
    this.alignment = Alignment.centerLeft,
  });
  final int flex;
  final Widget child;
  final Alignment alignment;
}

class _CellText extends StatelessWidget {
  const _CellText(this.value, {this.emphasized = false});

  final String value;
  final bool emphasized;

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
          color: const Color(0xFF2F382E),
          fontWeight: emphasized ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _TicketStatusChip extends StatelessWidget {
  const _TicketStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.trim().toLowerCase();
    late final Color backgroundColor;
    late final Color textColor;

    if (normalized == 'open') {
      backgroundColor = const Color(0xFFFFE1DD);
      textColor = const Color(0xFFC43C33);
    } else if (normalized == 'gesloten') {
      backgroundColor = const Color(0xFFEAF4D9);
      textColor = const Color(0xFF6F972D);
    } else {
      backgroundColor = const Color(0xFFF5F1E2);
      textColor = const Color(0xFF786233);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
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

class _OvaTypeChip extends StatelessWidget {
  const _OvaTypeChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final n = label.trim().toLowerCase();
    final Color bg;
    final Color fg;
    switch (n) {
      case 'near miss':
        bg = const Color(0xFFEAF4D9);
        fg = const Color(0xFF6F972D);
      case 'ova 1':
        bg = const Color(0xFFFFF0C7);
        fg = const Color(0xFFAF7A00);
      case 'ova 2':
        bg = const Color(0xFFFFE2B3);
        fg = const Color(0xFFB55A00);
      case 'ova 3':
        bg = const Color(0xFFFFD4CF);
        fg = const Color(0xFFC43C33);
      default:
        bg = const Color(0xFFF0F2EC);
        fg = const Color(0xFF5A6256);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SectionEmptyState extends StatelessWidget {
  const _SectionEmptyState({
    required this.title,
    required this.message,
    required this.filtered,
    required this.onClearFilters,
  });

  final String title;
  final String message;
  final bool filtered;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6C7)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 42, color: Color(0xFF6B8F2A)),
          const SizedBox(height: 14),
          Text(
            filtered ? 'Geen tickets voor deze filters' : title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            filtered
                ? 'Pas je zoekterm of filters aan om opnieuw tickets te tonen.'
                : message,
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

class _EmptyTicketState extends StatelessWidget {
  const _EmptyTicketState({required this.canCreate, this.onCreate});
  final bool canCreate;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6C7)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 44, color: Color(0xFF6B8F2A)),
          const SizedBox(height: 14),
          const Text(
            'Nog geen OVA-tickets gevonden',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            canCreate
                ? 'Maak een eerste ticket aan en werk het stap voor stap verder af.'
                : 'Zodra een ticket gestart is, verschijnt het hier zodat jij het verder kunt opvolgen.',
            textAlign: TextAlign.center,
          ),
          if (onCreate != null) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nieuw ticket'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6F6),
        borderRadius: BorderRadius.circular(18),
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
