import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qa_dashboard/widgets/app_bars/main_app_bar.dart';

import '../models/ova_ticket.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'ova_ticket_wizard_screen.dart';

enum _TicketSection { open, incomplete, closed }

const double _ticketTableColumnGap = 14;

class OvaTicketListScreen extends StatefulWidget {
  const OvaTicketListScreen({super.key});

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
    if (!mounted) {
      return;
    }

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
      if (!mounted) {
        return;
      }

      setState(() {
        _tickets = response.map(OvaTicket.fromJson).toList();
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

  Future<void> _openTicket({int? ticketId}) async {
    final resultingSection = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (context) => OvaTicketWizardScreen(ticketId: ticketId),
      ),
    );

    if (resultingSection == null || !mounted) {
      return;
    }

    final targetSection = _sectionForResult(resultingSection);
    await _loadTickets();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedSection = targetSection;
      if (targetSection != _TicketSection.open) {
        _selectedOvaType = null;
      }
    });
  }

  void _selectSection(_TicketSection section) {
    if (_selectedSection == section) {
      return;
    }

    setState(() {
      _selectedSection = section;
      if (section != _TicketSection.open) {
        _selectedOvaType = null;
      }
    });
  }

  void _toggleOvaType(String type) {
    setState(() {
      if (_sameOvaType(_selectedOvaType, type)) {
        _selectedOvaType = null;
        return;
      }

      _selectedOvaType = type;
    });
  }

  void _clearFilters() {
    if (!_hasActiveFilters) {
      return;
    }

    _searchController.clear();
    setState(() {
      _selectedOvaType = null;
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
        return _TicketSection.incomplete;
    }
  }

  bool _hasCauseAnalysis(OvaTicket ticket) {
    final method = ticket.causeAnalysisMethod?.trim();
    final notes = ticket.causeAnalysisNotes?.trim();
    return (method != null && method.isNotEmpty) ||
        (notes != null && notes.isNotEmpty);
  }

  bool _isOpenTicket(OvaTicket ticket) {
    return !ticket.isClosed &&
        _hasCauseAnalysis(ticket) &&
        ticket.actions.isNotEmpty;
  }

  bool _isIncompleteTicket(OvaTicket ticket) {
    return !ticket.isClosed && !_isOpenTicket(ticket);
  }

  List<OvaTicket> _sortTickets(Iterable<OvaTicket> tickets) {
    final sorted = tickets.toList();
    sorted.sort((left, right) {
      final leftDate = left.findingDate ?? left.updatedAt;
      final rightDate = right.findingDate ?? right.updatedAt;
      final byDate = leftDate.compareTo(rightDate);
      if (byDate != 0) {
        return byDate;
      }

      return left.id.compareTo(right.id);
    });
    return sorted;
  }

  List<OvaTicket> get _openTickets =>
      _sortTickets(_tickets.where(_isOpenTicket));

  List<OvaTicket> get _incompleteTickets =>
      _sortTickets(_tickets.where(_isIncompleteTicket));

  List<OvaTicket> get _closedTickets =>
      _sortTickets(_tickets.where((ticket) => ticket.isClosed));

  List<String> get _availableOvaTypes =>
      _resolveAvailableOvaTypes(_openTickets);

  List<OvaTicket> get _filteredTickets {
    final query = _normalizeValue(_searchController.text);
    Iterable<OvaTicket> tickets;
    switch (_selectedSection) {
      case _TicketSection.open:
        tickets = _openTickets;
      case _TicketSection.incomplete:
        tickets = _incompleteTickets;
      case _TicketSection.closed:
        tickets = _closedTickets;
    }

    if (query.isNotEmpty) {
      tickets = tickets.where((ticket) => _matchesSearch(ticket, query));
    }

    if (_selectedSection == _TicketSection.open &&
        _selectedOvaType != null &&
        _selectedOvaType!.trim().isNotEmpty) {
      tickets = tickets.where(
        (ticket) => _sameOvaType(ticket.ovaType, _selectedOvaType),
      );
    }

    return tickets.toList();
  }

  bool get _hasActiveFilters {
    return _searchController.text.trim().isNotEmpty ||
        (_selectedSection == _TicketSection.open &&
            _selectedOvaType != null &&
            _selectedOvaType!.trim().isNotEmpty);
  }

  bool _matchesSearch(OvaTicket ticket, String query) {
    final values = <String>[
      ticket.id.toString(),
      _ticketDescription(ticket),
      ticket.ovaType ?? '',
      ticket.statusLabel,
      _incompleteStatusLabel(ticket),
      ticket.createdBy.displayName,
      ticket.lastEditedBy.displayName,
    ];

    return values.any((value) => _normalizeValue(value).contains(query));
  }

  String _ticketDescription(OvaTicket ticket) {
    final candidates = <String?>[
      ticket.incidentDescription,
      ticket.followUpActions,
      ticket.otherReason,
      if (ticket.reasons.isNotEmpty) ticket.reasons.join(', '),
    ];

    for (final candidate in candidates) {
      final normalized = candidate?.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }

    return 'Geen omschrijving beschikbaar';
  }

  String _incompleteStatusLabel(OvaTicket ticket) {
    if (!_hasCauseAnalysis(ticket)) {
      return 'Oorzakenanalyse';
    }

    if (ticket.actions.isEmpty) {
      return 'Lege Opvolgacties';
    }

    return 'Incompleet';
  }

  String _sectionStatusLabel(OvaTicket ticket) {
    if (ticket.isClosed) {
      return 'Gesloten';
    }

    if (_isOpenTicket(ticket)) {
      return 'Open';
    }

    return _incompleteStatusLabel(ticket);
  }

  String _actionProgressLabel(OvaTicket ticket) {
    final completedActions = ticket.actions
        .where((action) => action.isOk)
        .length;
    return '$completedActions/${ticket.actions.length}';
  }

  String _ticketTypeLabel(OvaTicket ticket) {
    final type = ticket.ovaType?.trim();
    if (type == null || type.isEmpty) {
      return '-';
    }

    return type;
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

    return 'Ontbreekt';
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

  bool _sameOvaType(String? left, String? right) {
    return _normalizeValue(left) == _normalizeValue(right);
  }

  List<String> _resolveAvailableOvaTypes(List<OvaTicket> tickets) {
    const preferredOrder = ['Near Miss', 'OVA 3', 'OVA 2', 'OVA 1'];
    final types = tickets
        .map((ticket) => ticket.ovaType?.trim())
        .whereType<String>()
        .where((type) => type.isNotEmpty)
        .toList();

    final ordered = <String>[];
    for (final preferred in preferredOrder) {
      final match = types.where((type) => _sameOvaType(type, preferred));
      if (match.isNotEmpty) {
        ordered.add(match.first);
      }
    }

    for (final type in types) {
      if (!ordered.any((existing) => _sameOvaType(existing, type))) {
        ordered.add(type);
      }
    }

    return ordered;
  }

  int _ticketCountForSection(_TicketSection section) {
    switch (section) {
      case _TicketSection.open:
        return _openTickets.length;
      case _TicketSection.incomplete:
        return _incompleteTickets.length;
      case _TicketSection.closed:
        return _closedTickets.length;
    }
  }

  String _emptyTitleForSection(_TicketSection section) {
    switch (section) {
      case _TicketSection.open:
        return 'Geen open tickets';
      case _TicketSection.incomplete:
        return 'Geen incomplete tickets';
      case _TicketSection.closed:
        return 'Geen gesloten tickets';
    }
  }

  String _emptyMessageForSection(_TicketSection section) {
    switch (section) {
      case _TicketSection.open:
        return 'Tickets met een afgewerkte oorzakenanalyse en minstens een opvolgactie verschijnen hier.';
      case _TicketSection.incomplete:
        return 'Tickets zonder oorzakenanalyse of zonder opvolgacties verschijnen hier.';
      case _TicketSection.closed:
        return 'Afgesloten tickets blijven hier zichtbaar zodat de historiek bewaard blijft.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.user;
    final canCreate = user != null && (user.isAdmin || user.access.ova);
    final pageBackground = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: const MainAppBar(title: 'Vlotter'),
      body: RefreshIndicator(
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
                      const Text(
                        'Dashboard > OVA > Tickets',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7B8077),
                        ),
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 840;
                          final titleBlock = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'OVA Tickets',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
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

                          if (isCompact) {
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
                      _SectionTabs(
                        selectedSection: _selectedSection,
                        counts: {
                          _TicketSection.open: _ticketCountForSection(
                            _TicketSection.open,
                          ),
                          _TicketSection.incomplete: _ticketCountForSection(
                            _TicketSection.incomplete,
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
                          section: _selectedSection,
                          searchController: _searchController,
                          hasActiveFilters: _hasActiveFilters,
                          availableOvaTypes: _availableOvaTypes,
                          selectedOvaType: _selectedOvaType,
                          onToggleOvaType: _toggleOvaType,
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
      ),
    );
  }

  Widget _buildSelectedTable() {
    return _TicketTable(
      minWidth: 1560,
      columns: const [
        _TableColumnData(label: 'ID', flex: 6),
        _TableColumnData(label: 'Status', flex: 14),
        _TableColumnData(
          label: 'Type OVA',
          flex: 11,
          alignment: Alignment.center,
        ),
        _TableColumnData(
          label: 'Datum vaststelling',
          flex: 15,
          alignment: Alignment.centerRight,
        ),
        _TableColumnData(label: 'Omschrijving', flex: 32),
        _TableColumnData(label: 'Aanleiding', flex: 24),
        _TableColumnData(label: 'Oorzakenanalyse', flex: 18),
        _TableColumnData(
          label: 'Opvolgacties',
          flex: 12,
          alignment: Alignment.center,
        ),
        _TableColumnData(label: 'Effectiviteit', flex: 14),
        _TableColumnData(label: 'Laatst bewerkt', flex: 22),
        _TableColumnData(label: 'Afsluiting', flex: 18),
      ],
      rows: List<Widget>.generate(_filteredTickets.length, (index) {
        final ticket = _filteredTickets[index];
        return _TicketTableRow(
          striped: index.isOdd,
          onTap: () => _openTicket(ticketId: ticket.id),
          cells: [
            _TableCellData(
              flex: 6,
              child: Text(
                ticket.id.toString().padLeft(4, '0'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            _TableCellData(
              flex: 14,
              child: _TicketStatusChip(label: _sectionStatusLabel(ticket)),
            ),
            _TableCellData(
              flex: 11,
              alignment: Alignment.center,
              child: _OvaTypeChip(label: _ticketTypeLabel(ticket)),
            ),
            _TableCellData(
              flex: 15,
              alignment: Alignment.centerRight,
              child: _CellText(
                formatOvaDate(ticket.findingDate ?? ticket.updatedAt),
              ),
            ),
            _TableCellData(
              flex: 32,
              child: _CellText(_ticketDescription(ticket), emphasized: true),
            ),
            _TableCellData(flex: 24, child: _CellText(_reasonsLabel(ticket))),
            _TableCellData(
              flex: 18,
              child: _CellText(_causeAnalysisLabel(ticket)),
            ),
            _TableCellData(
              flex: 12,
              alignment: Alignment.center,
              child: Text(
                _actionProgressLabel(ticket),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            _TableCellData(
              flex: 14,
              child: _CellText(_effectivenessLabel(ticket)),
            ),
            _TableCellData(
              flex: 22,
              child: _CellText(_lastEditedLabel(ticket)),
            ),
            _TableCellData(
              flex: 18,
              child: _CellText(_closedInfoLabel(ticket)),
            ),
          ],
        );
      }),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({
    required this.selectedSection,
    required this.counts,
    required this.onSelected,
  });

  final _TicketSection selectedSection;
  final Map<_TicketSection, int> counts;
  final ValueChanged<_TicketSection> onSelected;

  String _labelForSection(_TicketSection section) {
    switch (section) {
      case _TicketSection.open:
        return 'Open Tickets';
      case _TicketSection.incomplete:
        return 'Incomplete Tickets';
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
        children: _TicketSection.values.map((section) {
          final isSelected = section == selectedSection;
          return InkWell(
            onTap: () => onSelected(section),
            child: Container(
              padding: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected
                        ? const Color(0xFF8CC63F)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                '${_labelForSection(section)} (${counts[section] ?? 0})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
              'Dit ticket heeft een oorzakenanalyse en minstens een opvolgactie. Het wordt actief opgevolgd tot de opvolging en effectiviteit afgerond zijn.',
          color: Color(0xFFEAF4D9),
          iconColor: Color(0xFF6F972D),
        );
      case _TicketSection.incomplete:
        return const _StatusGuideCard(
          title: 'Incompleet',
          description:
              'Dit ticket is gestart, maar mist nog een oorzakenanalyse of opvolgacties. Vul die info aan voordat het als actief opgevolgd telt.',
          color: Color(0xFFFFF5DE),
          iconColor: Color(0xFFB37A12),
        );
      case _TicketSection.closed:
        return const _StatusGuideCard(
          title: 'Gesloten',
          description:
              'Dit ticket is afgehandeld. Het blijft zichtbaar als historiek en bewijs van de uitgevoerde opvolging.',
          color: Color(0xFFEAF0F4),
          iconColor: Color(0xFF527083),
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
    required this.section,
    required this.searchController,
    required this.hasActiveFilters,
    required this.availableOvaTypes,
    required this.selectedOvaType,
    required this.onToggleOvaType,
    required this.onClearFilters,
    required this.visibleCount,
  });

  final _TicketSection section;
  final TextEditingController searchController;
  final bool hasActiveFilters;
  final List<String> availableOvaTypes;
  final String? selectedOvaType;
  final ValueChanged<String> onToggleOvaType;
  final VoidCallback onClearFilters;
  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    final showTypeFilters =
        section == _TicketSection.open && availableOvaTypes.isNotEmpty;

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

    final filterButton = Tooltip(
      message: 'Wis filters',
      child: InkWell(
        onTap: hasActiveFilters ? onClearFilters : null,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: hasActiveFilters
                ? const Color(0xFFF4F4F0)
                : const Color(0xFFF8F8F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasActiveFilters
                  ? const Color(0xFFD9DDD1)
                  : const Color(0xFFE8EBE1),
            ),
          ),
          child: Icon(
            Icons.filter_alt_off_rounded,
            size: 20,
            color: hasActiveFilters
                ? const Color(0xFF2F382E)
                : const Color(0xFFB5BBB0),
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 940;
        final left = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$visibleCount ticket${visibleCount == 1 ? '' : 's'} zichtbaar',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7A8078),
              ),
            ),
            if (showTypeFilters) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableOvaTypes.map((type) {
                  final isSelected =
                      _normalize(type) == _normalize(selectedOvaType);
                  return ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (_) => onToggleOvaType(type),
                    selectedColor: const Color(0xFFEAF4D9),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? const Color(0xFF6B8F2A)
                          : const Color(0xFF4D5548),
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF98C74D)
                          : const Color(0xFFD9DDD1),
                    ),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              left,
              const SizedBox(height: 16),
              Row(
                children: [
                  filterButton,
                  const SizedBox(width: 10),
                  Expanded(child: searchField),
                ],
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [filterButton, const SizedBox(width: 10), searchField],
            ),
          ],
        );
      },
    );
  }

  String _normalize(String? value) => value?.trim().toLowerCase() ?? '';
}

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
      builder: (context, constraints) {
        final tableWidth = math.max(constraints.maxWidth, minWidth).toDouble();
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
                width: tableWidth,
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
      backgroundColor = const Color(0xFFEAF4D9);
      textColor = const Color(0xFF6F972D);
    } else if (normalized == 'gesloten') {
      backgroundColor = const Color(0xFFEAF0F4);
      textColor = const Color(0xFF527083);
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
    final normalized = label.trim().toLowerCase();
    late final Color backgroundColor;
    late final Color textColor;

    switch (normalized) {
      case 'near miss':
        backgroundColor = const Color(0xFFEAF4D9);
        textColor = const Color(0xFF6F972D);
      case 'ova 1':
        backgroundColor = const Color(0xFFFFF0C7);
        textColor = const Color(0xFFAF7A00);
      case 'ova 2':
        backgroundColor = const Color(0xFFFFE2B3);
        textColor = const Color(0xFFB55A00);
      case 'ova 3':
        backgroundColor = const Color(0xFFFFD4CF);
        textColor = const Color(0xFFC43C33);
      default:
        backgroundColor = const Color(0xFFF0F2EC);
        textColor = const Color(0xFF5A6256);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
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
            filtered ? 'Geen resultaten voor deze filters' : title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            filtered
                ? 'Pas je zoekterm of typefilter aan om opnieuw tickets te tonen.'
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
                ? 'Maak een eerste ticket aan en werk het stap voor stap verder af. Zodra opvolgacties toegevoegd zijn, verhuist het naar Open Tickets.'
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
