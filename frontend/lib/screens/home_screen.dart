import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/app_bars/main_app_bar.dart';
import '../widgets/resizable_sidebar.dart';
import '../models/ova_assigned_action.dart';
import '../models/ova_ticket.dart';
import '../models/jap_gpp_entry.dart';
import '../services/ova_api_service.dart';
import '../services/auth_service.dart';
import '../widgets/design/design_system.dart';
import 'jap_gpp_screen.dart';
import 'ova_dashboard_screen.dart';
import 'maintenance_inspections_screen.dart';
import '../services/jap_gpp_api_service.dart';
import '../services/maintenance_api_service.dart';
import '../services/whs_api_service.dart';
import '../widgets/user_avatar.dart';
import 'whs_tours_screen.dart';

enum _HomeSection { dashboard, whsTours, ova, onderhoud, japGpp }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.initialSectionKey = 'dashboard',
    this.initialOvaTicketId,
    this.initialJapGppModule,
    this.initialJapGppEntryId,
    this.initialMaintenanceInspectionId,
  });

  final String initialSectionKey;
  final int? initialOvaTicketId;
  final String? initialJapGppModule;
  final int? initialJapGppEntryId;
  final int? initialMaintenanceInspectionId;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late _HomeSection _selected;
  int? _initialOvaTicketId;
  OvaDashboardInitialPage _initialOvaPage = OvaDashboardInitialPage.overview;
  bool _initialOvaTicketConsumed = false;
  String? _initialJapGppModule;
  int? _initialJapGppEntryId;
  int? _initialMaintenanceInspectionId;
  int _breadcrumbNavigationVersion = 0;

  @override
  void initState() {
    super.initState();
    _selected = _sectionFromKey(widget.initialSectionKey);
    _initialOvaTicketId = widget.initialOvaTicketId;
    _initialJapGppModule = widget.initialJapGppModule;
    _initialJapGppEntryId = widget.initialJapGppEntryId;
    _initialMaintenanceInspectionId = widget.initialMaintenanceInspectionId;
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSection = _sectionFromKey(widget.initialSectionKey);
    final previousSection = _sectionFromKey(oldWidget.initialSectionKey);
    if (nextSection != previousSection && nextSection != _selected) {
      _selected = nextSection;
    }

    if (widget.initialJapGppModule != oldWidget.initialJapGppModule ||
        widget.initialJapGppEntryId != oldWidget.initialJapGppEntryId) {
      _initialJapGppModule = widget.initialJapGppModule;
      _initialJapGppEntryId = widget.initialJapGppEntryId;
    }

    if (widget.initialOvaTicketId != oldWidget.initialOvaTicketId) {
      _initialOvaTicketId = widget.initialOvaTicketId;
      _initialOvaTicketConsumed = false;
    }

    if (widget.initialMaintenanceInspectionId !=
        oldWidget.initialMaintenanceInspectionId) {
      _initialMaintenanceInspectionId = widget.initialMaintenanceInspectionId;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MainAppBar(title: 'Vlotter'),
      body: AppBreadcrumbNavigation(
        onNavigateTo: _navigateFromBreadcrumb,
        child: Row(
          children: [
            _Sidebar(
              selected: _selected,
              onSelect: (section) {
                setState(() {
                  if (section == _HomeSection.ova) {
                    _initialOvaPage = OvaDashboardInitialPage.overview;
                  }
                  _selected = section;
                });
              },
            ),
            Expanded(child: _buildSectionContent(_selected)),
          ],
        ),
      ),
    );
  }

  void _navigateFromBreadcrumb(String key) {
    setState(() {
      _breadcrumbNavigationVersion++;
      _initialOvaTicketId = null;
      _initialOvaTicketConsumed = true;
      _initialJapGppModule = null;
      _initialJapGppEntryId = null;
      _initialMaintenanceInspectionId = null;

      switch (key) {
        case 'dashboard':
          _selected = _HomeSection.dashboard;
          break;
        case 'whsTours':
          _selected = _HomeSection.whsTours;
          break;
        case 'ovaTickets':
          _initialOvaPage = OvaDashboardInitialPage.tickets;
          _selected = _HomeSection.ova;
          break;
        case 'ovaActions':
          _initialOvaPage = OvaDashboardInitialPage.actions;
          _selected = _HomeSection.ova;
          break;
        case 'ova':
          _initialOvaPage = OvaDashboardInitialPage.overview;
          _selected = _HomeSection.ova;
          break;
        case 'onderhoud':
          _selected = _HomeSection.onderhoud;
          break;
        case 'japGpp':
          _selected = _HomeSection.japGpp;
          break;
      }
    });
  }

  Widget _buildSectionContent(_HomeSection section) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;
    final user = authService.user;

    switch (section) {
      case _HomeSection.dashboard:
        return _DashboardBody(
          authService: authService,
          onNavigate: (section) {
            setState(() {
              _selected = section;
            });
          },
          onNavigateToOva: (page) {
            setState(() {
              _initialOvaPage = page;
              _selected = _HomeSection.ova;
            });
          },
        );
      case _HomeSection.whsTours:
        return WhsToursScreen(
          key: ValueKey<String>('whsTours-$_breadcrumbNavigationVersion'),
          token: token ?? '',
        );
      case _HomeSection.ova:
        final ovaTicketId = _initialOvaTicketConsumed
            ? null
            : _initialOvaTicketId;
        return OvaDashboardScreen(
          key: ValueKey<String>(
            'ova-${_initialOvaPage.name}-${ovaTicketId ?? 'none'}-$_breadcrumbNavigationVersion',
          ),
          initialPage: _initialOvaPage,
          initialTicketId: ovaTicketId,
          onCloseInitialTicket: () {
            if (!mounted) {
              return;
            }
            setState(() {
              _initialOvaTicketConsumed = true;
            });
          },
        );
      case _HomeSection.onderhoud:
        if (user == null ||
            (!user.isAdmin && !user.access.maintenanceInspections)) {
          return const AppAccessDenied(
            title: 'Geen toegang tot Onderhoud & Keuringen',
            message:
                'Je hebt rechten voor Onderhoud & Keuringen nodig om dit scherm te openen.',
          );
        }
        return MaintenanceInspectionsScreen(
          key: ValueKey<String>('maintenance-$_breadcrumbNavigationVersion'),
          initialInspectionId: _initialMaintenanceInspectionId,
        );
      case _HomeSection.japGpp:
        if (user == null || (!user.isAdmin && !user.access.japGpp)) {
          return const AppAccessDenied(
            title: 'Geen JAP/GPP-toegang',
            message: 'Je hebt JAP/GPP-rechten nodig om dit scherm te openen.',
          );
        }
        return JapGppScreen(
          key: ValueKey<String>('japGpp-$_breadcrumbNavigationVersion'),
          token: token ?? '',
          initialModule: _initialJapGppModule,
          initialEntryId: _initialJapGppEntryId,
        );
    }
  }

  _HomeSection _sectionFromKey(String key) {
    switch (key) {
      case 'dashboard':
        return _HomeSection.dashboard;
      case 'whsTours':
        return _HomeSection.whsTours;
      case 'ova':
        return _HomeSection.ova;
      case 'onderhoud':
        return _HomeSection.onderhoud;
      case 'japGpp':
        return _HomeSection.japGpp;
      default:
        return _HomeSection.dashboard;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sidebar — neutral surface with a pill-style active indicator.
// ─────────────────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.onSelect});

  final _HomeSection selected;
  final ValueChanged<_HomeSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return ResizableSidebar(
      title: 'NAVIGATIE',
      storageKey: 'homeSidebar',
      defaultWidth: 232,
      footer: const Padding(
        padding: EdgeInsets.fromLTRB(22, 0, 22, 18),
        child: Text(
          'Vlotter QA Dashboard',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: kTextMuted,
          ),
        ),
      ),
      childBuilder: (context, expanded) => Column(
        children: [
          _SidebarItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            expanded: expanded,
            selected: selected == _HomeSection.dashboard,
            onTap: () => onSelect(_HomeSection.dashboard),
          ),
          _SidebarItem(
            icon: Icons.apartment_rounded,
            label: 'WHS-Tours',
            expanded: expanded,
            selected: selected == _HomeSection.whsTours,
            onTap: () => onSelect(_HomeSection.whsTours),
          ),
          _SidebarItem(
            icon: Icons.report_problem_outlined,
            label: 'OVA',
            expanded: expanded,
            selected: selected == _HomeSection.ova,
            onTap: () => onSelect(_HomeSection.ova),
          ),
          _SidebarItem(
            icon: Icons.build_rounded,
            label: 'Onderhoud & Keuringen',
            expanded: expanded,
            selected: selected == _HomeSection.onderhoud,
            onTap: () => onSelect(_HomeSection.onderhoud),
          ),
          _SidebarItem(
            icon: Icons.assignment_rounded,
            label: 'JAP & GPP',
            expanded: expanded,
            selected: selected == _HomeSection.japGpp,
            onTap: () => onSelect(_HomeSection.japGpp),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool expanded;
  final bool selected;
  final VoidCallback? onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? kBrandGreenDeep : kTextSecondary;
    final bg = selected ? kBrandGreenSoft : Colors.transparent;
    final borderColor = selected ? kBrandGreenSoft : Colors.transparent;

    final item = Padding(
      padding: EdgeInsets.fromLTRB(12, 2, expanded ? 12 : 10, 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadiusMd),
          hoverColor: selected ? kBrandGreenSubtle : kSurfaceHover,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(kRadiusMd),
            ),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(icon, color: fg, size: 20),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (selected)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: kBrandGreenDeep,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Tooltip(message: label, child: item);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Dashboard body
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardBody extends StatefulWidget {
  const _DashboardBody({
    required this.authService,
    required this.onNavigate,
    required this.onNavigateToOva,
  });

  final AuthService authService;
  final ValueChanged<_HomeSection> onNavigate;
  final ValueChanged<OvaDashboardInitialPage> onNavigateToOva;

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  bool _isLoading = true;
  String? _error;
  List<OvaTicket> _tickets = const [];
  List<OvaAssignedAction> _actions = const [];
  List<JapGppComment> _recentJapGpp = [];
  List<MaintenanceItem> _upcomingMaintenance = [];
  List<Map<String, dynamic>> _whsRecent = [];
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await widget.authService.getValidAccessToken();

      final results = await Future.wait<dynamic>([
        OvaApiService.fetchOvaTickets(
          token: token,
        ).catchError((_) => <Map<String, dynamic>>[]),
        OvaApiService.fetchMyOvaActions(
          token: token,
        ).catchError((_) => <Map<String, dynamic>>[]),
        JapApiService.fetchJapEntries(
          token: token,
        ).catchError((_) => <JapEntry>[]),
        JapApiService.fetchGppEntries(
          token: token,
        ).catchError((_) => <GppEntry>[]),
        MaintenanceApiService.fetchUpcomingInspections(
          token: token,
        ).catchError((_) => <Map<String, dynamic>>[]),
        WhsApiService.fetchRecentReports(
          token: token,
        ).catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;

      final japEntries = List<JapEntry>.from(results[2] as List)
        ..sort((a, b) => b.year.compareTo(a.year));
      final gppEntries = List<GppEntry>.from(results[3] as List)
        ..sort((a, b) {
          final endCompare = b.endYear.compareTo(a.endYear);
          if (endCompare != 0) return endCompare;
          return b.startYear.compareTo(a.startYear);
        });
      final today = DateTime.now();
      final startOfToday = DateTime(today.year, today.month, today.day);
      final urgentCutoff = startOfToday.add(const Duration(days: 30));

      final maintenanceOverview =
          (results[4] as List<Map<String, dynamic>>).where((inspection) {
            final dueDate = DateTime.tryParse(
              inspection['dueDate']?.toString() ?? '',
            );
            if (dueDate == null) return false;
            return dueDate.isBefore(startOfToday) ||
                !dueDate.isAfter(urgentCutoff);
          }).toList()..sort((a, b) {
            final aDate =
                DateTime.tryParse(a['dueDate']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bDate =
                DateTime.tryParse(b['dueDate']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return aDate.compareTo(bDate);
          });

      setState(() {
        _tickets = (results[0] as List)
            .map((j) => OvaTicket.fromJson(j as Map<String, dynamic>))
            .toList();
        _actions = (results[1] as List)
            .map((j) => OvaAssignedAction.fromJson(j as Map<String, dynamic>))
            .toList();
        _recentJapGpp = [
          ...japEntries
              .take(3)
              .map(
                (entry) => JapGppComment(
                  title: entry.goalMeasure,
                  author: 'JAP ${entry.year} · ${entry.domain}',
                  comment:
                      '${_japPriorityLabel(entry.priority)} · ${_japRealisationLabel(entry.realisation)}',
                ),
              ),
          ...gppEntries
              .take(3)
              .map(
                (entry) => JapGppComment(
                  title: entry.goalMeasure,
                  author: 'GPP ${entry.yearLabel} · ${entry.domain}',
                  comment:
                      '${_gppPriorityLabel(entry.priority)} · ${_gppRealisationLabel(entry.realisation)}',
                ),
              ),
        ];
        _upcomingMaintenance = maintenanceOverview.take(20).map((inspection) {
          final dueDate = DateTime.tryParse(
            inspection['dueDate']?.toString() ?? '',
          );
          final formatted = dueDate == null
              ? (inspection['dueDate']?.toString() ?? '')
              : '${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}/${dueDate.year}';
          final branchValues = inspection['branches'];
          final branches = branchValues is List
              ? branchValues.whereType<String>().join(', ')
              : '';
          final title = inspection['equipment']?.toString() ?? '';
          return MaintenanceItem(
            title: '$title${branches.isEmpty ? '' : ' ($branches)'}',
            date: formatted,
            dueDate: dueDate,
          );
        }).toList();
        _whsRecent =
            (results.length > 5
                    ? (results[5] as List<Map<String, dynamic>>)
                    : <Map<String, dynamic>>[])
                .take(3)
                .map((r) => Map<String, dynamic>.from(r))
                .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<OvaTicket> get _openTickets => _tickets.where((t) => t.isOpen).toList();

  int get _incidentsThisMonth {
    final now = DateTime.now();
    return _tickets.where((t) {
      final date = t.findingDate;
      if (date == null) return false;
      return date.year == now.year && date.month == now.month;
    }).length;
  }

  int get _nokActionsCount => _actions.where((a) => !a.action.isOk).length;

  Map<String, int> get _ticketsByType {
    const order = ['OVA 3', 'OVA 2', 'OVA 1', 'Near Miss'];
    final counts = <String, int>{};
    for (final t in _openTickets) {
      final type = t.ovaType?.trim();
      if (type == null || type.isEmpty) continue;
      counts[type] = (counts[type] ?? 0) + 1;
    }
    final sorted = <String, int>{};
    for (final key in order) {
      if (counts.containsKey(key)) sorted[key] = counts[key]!;
    }
    for (final entry in counts.entries) {
      if (!sorted.containsKey(entry.key)) sorted[entry.key] = entry.value;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.user;
    if (user == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: CircularProgressIndicator(color: kBrandGreen),
        ),
      );
    }

    final hasOvaAccess = user.isAdmin || user.access.ova || user.access.basis;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: kBrandGreenDark,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WelcomeHeader(user: user),
            const SizedBox(height: 28),
            if (_isLoading)
              _DashboardSkeleton(showStats: hasOvaAccess)
            else if (_error != null)
              _ErrorCard(message: _error!, onRetry: _loadData)
            else ...[
              if (hasOvaAccess) ...[
                _StatCardRow(
                  children: [
                    _OvaTicketsCard(
                      openTickets: _openTickets,
                      ticketsByType: _ticketsByType,
                      onTap: () => widget.onNavigateToOva(
                        OvaDashboardInitialPage.tickets,
                      ),
                    ),
                    _StatCard(
                      title: 'Mijn OVA-acties',
                      value: _nokActionsCount.toString(),
                      subtitle: 'open acties',
                      accentColor: kBrandGreen,
                      icon: Icons.format_list_bulleted_rounded,
                      onTap: () => widget.onNavigateToOva(
                        OvaDashboardInitialPage.actions,
                      ),
                    ),
                    _StatCard(
                      title: 'OVA Incidenten',
                      value: _incidentsThisMonth.toString(),
                      subtitle: 'incidenten deze maand',
                      accentColor: const Color(0xFFE08423),
                      icon: Icons.warning_amber_rounded,
                      onTap: () => widget.onNavigateToOva(
                        OvaDashboardInitialPage.tickets,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 880;
                final cards = <Widget>[
                  _JapGppOverviewCard(
                    items: _recentJapGpp,
                    onTap: () => widget.onNavigate(_HomeSection.japGpp),
                  ),
                  _UpcomingMaintenanceCard(
                    items: _upcomingMaintenance,
                    onTap: () => widget.onNavigate(_HomeSection.onderhoud),
                  ),
                  _WhsToursOverviewCard(
                    items: _whsRecent,
                    onTap: () => widget.onNavigate(_HomeSection.whsTours),
                  ),
                ];

                const cardHeight = 300.0;
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < cards.length; i++)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: i == cards.length - 1 ? 0 : 16,
                                ),
                                child: SizedBox(
                                  height: cardHeight,
                                  child: cards[i],
                                ),
                              ),
                            ),
                        ],
                      )
                    : Column(
                        children: cards
                            .map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: SizedBox(height: cardHeight, child: c),
                              ),
                            )
                            .toList(),
                      );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Welcome header
// ─────────────────────────────────────────────

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton({required this.showStats});

  final bool showStats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showStats) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              if (compact) {
                return const Column(
                  children: [
                    AppMetricCardSkeleton(),
                    SizedBox(height: 14),
                    AppMetricCardSkeleton(),
                    SizedBox(height: 14),
                    AppMetricCardSkeleton(),
                  ],
                );
              }
              return const Row(
                children: [
                  Expanded(child: AppMetricCardSkeleton()),
                  SizedBox(width: 16),
                  Expanded(child: AppMetricCardSkeleton()),
                  SizedBox(width: 16),
                  Expanded(child: AppMetricCardSkeleton()),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 880;
            final cards = List.generate(
              3,
              (_) => const _OverviewCardSkeleton(),
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: cards
                        .map(
                          (c) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: c,
                            ),
                          ),
                        )
                        .toList(),
                  )
                : Column(
                    children: cards
                        .map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: c,
                          ),
                        )
                        .toList(),
                  );
          },
        ),
      ],
    );
  }
}

class _OverviewCardSkeleton extends StatelessWidget {
  const _OverviewCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kBorder),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppSkeleton.circle(size: 36),
              SizedBox(width: 12),
              AppSkeleton(height: 14, width: 120),
            ],
          ),
          SizedBox(height: 20),
          AppSkeleton(height: 12, width: 240),
          SizedBox(height: 8),
          AppSkeleton(height: 12, width: 180),
          SizedBox(height: 16),
          AppSkeleton(height: 12, width: 220),
          SizedBox(height: 8),
          AppSkeleton(height: 12, width: 160),
        ],
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppUserAvatar(
          initial: (user.displayName.isNotEmpty ? user.displayName[0] : '?')
              .toUpperCase(),
          profileImage: user.profileImage as String?,
          size: 56,
          borderRadius: kRadiusLg,
          fontSize: 22,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welkom, ${user.displayName}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.isAdmin
                    ? 'Administrator · Volledige toegang'
                    : 'Gebruiker · Overzicht van jouw werkstroom',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: kTextTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCardRow extends StatelessWidget {
  const _StatCardRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: children
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: c,
                  ),
                )
                .toList(),
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == children.length - 1 ? 0 : 16,
                    ),
                    child: children[i],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  OVA Tickets KPI card
// ─────────────────────────────────────────────

class _OvaTicketsCard extends StatelessWidget {
  const _OvaTicketsCard({
    required this.openTickets,
    required this.ticketsByType,
    required this.onTap,
  });

  final List<OvaTicket> openTickets;
  final Map<String, int> ticketsByType;
  final VoidCallback onTap;

  ({Color bg, Color fg}) _badgeColors(String type) {
    switch (type.trim().toLowerCase()) {
      case 'ova 3':
        return (bg: const Color(0xFFFDEAE6), fg: const Color(0xFFB83828));
      case 'ova 2':
        return (bg: const Color(0xFFFDEDD2), fg: const Color(0xFF9D5C0F));
      case 'ova 1':
        return (bg: const Color(0xFFFCF3D1), fg: const Color(0xFF8A6905));
      case 'near miss':
        return (bg: kInfoBg, fg: kInfo);
      default:
        return (bg: kSurfaceMuted, fg: kTextTertiary);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Open OVA Tickets',
                  style: TextStyle(
                    fontSize: 13,
                    color: kTextTertiary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: kBrandGreenDark,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            openTickets.length.toString(),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: kTextPrimary,
              height: 1.05,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'open dossiers',
            style: TextStyle(fontSize: 12.5, color: kTextTertiary),
          ),
          const SizedBox(height: 16),
          if (ticketsByType.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ticketsByType.entries.map((e) {
                final type = e.key;
                final count = e.value;
                final c = _badgeColors(type);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(kRadiusPill),
                  ),
                  child: Text(
                    '$type · $count',
                    style: TextStyle(
                      color: c.fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Stat card (generic)
// ─────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accentColor,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color accentColor;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = accentColor.withAlpha((0.12 * 255).round());

    return _BaseCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(kRadiusSm),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_forward_rounded,
                color: kBrandGreenDark,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: kTextTertiary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: kTextPrimary,
              height: 1.05,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12.5, color: kTextTertiary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Error card
// ─────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kDangerBg,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kDangerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: kDanger, size: 22),
              SizedBox(width: 10),
              Text(
                'Fout bij laden',
                style: TextStyle(
                  fontSize: 14,
                  color: kDanger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 14, color: kTextPrimary),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Opnieuw proberen'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Base card (shared style)
// ─────────────────────────────────────────────

class _BaseCard extends StatelessWidget {
  const _BaseCard({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(kRadiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusLg),
        hoverColor: kSurfaceHover,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadiusLg),
            border: Border.all(color: kBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  JAP & GPP dashboard card + model
// ─────────────────────────────────────────────

class JapGppComment {
  final String title;
  final String author;
  final String comment;

  JapGppComment({
    required this.title,
    required this.author,
    required this.comment,
  });
}

class _JapGppOverviewCard extends StatelessWidget {
  const _JapGppOverviewCard({required this.items, required this.onTap});

  final List<JapGppComment> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OverviewCardHeader(
            icon: Icons.assignment_outlined,
            title: 'JAP & GPP',
          ),
          const SizedBox(height: 4),
          Expanded(
            child: items.isEmpty
                ? const _CenteredEmptyHint(
                    text: 'Nog geen JAP of GPP items beschikbaar.',
                  )
                : _ScrollableCardBody(
                    children: items
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: _OverviewRow(
                              icon: Icons.flag_outlined,
                              title: item.title,
                              subtitle: item.author,
                              trailing: item.comment,
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Maintenance overview card
// ─────────────────────────────────────────────

class MaintenanceItem {
  final String title;
  final String date;
  final DateTime? dueDate;

  MaintenanceItem({required this.title, required this.date, this.dueDate});
}

class _UpcomingMaintenanceCard extends StatelessWidget {
  const _UpcomingMaintenanceCard({required this.items, required this.onTap});

  final List<MaintenanceItem> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    var overdueCount = 0;
    var soonCount = 0;
    for (final item in items) {
      final due = item.dueDate;
      if (due == null) continue;
      if (due.isBefore(startOfToday)) {
        overdueCount++;
      } else {
        soonCount++;
      }
    }

    return _BaseCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OverviewCardHeader(
            icon: Icons.event_available_outlined,
            title: 'Onderhoud & Keuringen',
          ),
          if (overdueCount > 0 || soonCount > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (overdueCount > 0)
                  _UrgencyChip(
                    label: '$overdueCount verlopen',
                    bg: kDangerBg,
                    fg: kDanger,
                    border: kDangerBorder,
                  ),
                if (soonCount > 0)
                  _UrgencyChip(
                    label: '$soonCount binnen 30d',
                    bg: kWarningBg,
                    fg: kWarning,
                    border: kWarningBorder,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Expanded(
            child: items.isEmpty
                ? const _CenteredEmptyHint(
                    text: 'Geen urgente onderhouds- of keuringsitems.',
                  )
                : _ScrollableCardBody(
                    children: items.map((item) {
                      final due = item.dueDate;
                      final isOverdue =
                          due != null && due.isBefore(startOfToday);
                      final iconColor = due == null
                          ? kBrandGreenDark
                          : (isOverdue ? kDanger : kWarning);
                      final subtitle = due == null
                          ? item.date
                          : '${item.date} · ${_urgencyLabel(due, startOfToday)}';
                      return Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: _OverviewRow(
                          icon: Icons.calendar_today_rounded,
                          iconColor: iconColor,
                          title: item.title,
                          subtitle: subtitle,
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  static String _urgencyLabel(DateTime due, DateTime startOfToday) {
    final diffDays = due.difference(startOfToday).inDays;
    if (diffDays < 0) {
      final abs = -diffDays;
      return abs == 1 ? 'verlopen sinds 1 dag' : 'verlopen sinds $abs dagen';
    }
    if (diffDays == 0) return 'vandaag';
    if (diffDays == 1) return 'morgen';
    return 'binnen $diffDays dagen';
  }
}

class _UrgencyChip extends StatelessWidget {
  const _UrgencyChip({
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
  });

  final String label;
  final Color bg;
  final Color fg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _WhsToursOverviewCard extends StatelessWidget {
  const _WhsToursOverviewCard({required this.items, required this.onTap});

  final List<Map<String, dynamic>> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OverviewCardHeader(icon: Icons.tour_outlined, title: 'WHS-Tours'),
          const SizedBox(height: 4),
          Expanded(
            child: items.isEmpty
                ? const _CenteredEmptyHint(
                    text: 'Nog geen WHS-tours gekoppeld.',
                  )
                : _ScrollableCardBody(
                    children: items.map((item) {
                      final location = item['vestiging'] is Map
                          ? (item['vestiging']['address'] ??
                                item['vestiging']['name'])
                          : (item['vestiging']?.toString() ?? 'Onbekend');
                      final rawDate = item['datum'] ?? item['date'];
                      String dateLabel = '';
                      if (rawDate != null) {
                        final parsed = DateTime.tryParse(rawDate.toString());
                        if (parsed != null) {
                          dateLabel =
                              '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
                        } else {
                          dateLabel = rawDate.toString();
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: _OverviewRow(
                          icon: Icons.place_outlined,
                          title: location.toString(),
                          subtitle: dateLabel,
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Vertically centered empty hint — used inside an [Expanded] so the message
/// floats in the middle of the card instead of sticking to the top.
class _CenteredEmptyHint extends StatelessWidget {
  const _CenteredEmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: kTextTertiary,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

/// Scrollable container for the body of an overview card. Shows a hover
/// scrollbar on desktop/web when content overflows the fixed card height.
class _ScrollableCardBody extends StatefulWidget {
  const _ScrollableCardBody({required this.children});

  final List<Widget> children;

  @override
  State<_ScrollableCardBody> createState() => _ScrollableCardBodyState();
}

class _ScrollableCardBodyState extends State<_ScrollableCardBody> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: false,
      child: SingleChildScrollView(
        controller: _controller,
        padding: const EdgeInsets.only(right: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widget.children,
        ),
      ),
    );
  }
}

class _OverviewCardHeader extends StatelessWidget {
  const _OverviewCardHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: kBrandGreenSoft,
            borderRadius: BorderRadius.circular(kRadiusSm),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: kBrandGreenDeep),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
            ),
          ),
        ),
        const Icon(
          Icons.arrow_forward_rounded,
          color: kBrandGreenDark,
          size: 18,
        ),
      ],
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor ?? kBrandGreenDark),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: kTextPrimary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12.5, color: kTextTertiary),
              ),
              if (trailing != null && trailing!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  trailing!,
                  style: const TextStyle(fontSize: 12.5, color: kTextSecondary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _japPriorityLabel(JapPriority priority) {
  switch (priority) {
    case JapPriority.high:
      return 'Hoog';
    case JapPriority.medium:
      return 'Middel';
    case JapPriority.low:
      return 'Laag';
  }
}

String _japRealisationLabel(JapRealisation realisation) {
  switch (realisation) {
    case JapRealisation.inProgress:
      return 'In uitvoering';
    case JapRealisation.completed:
      return 'Uitgevoerd';
    case JapRealisation.notYetCompleted:
      return 'Nog niet uitgevoerd';
    case JapRealisation.fillIn:
      return 'Vul aan';
  }
}

String _gppPriorityLabel(String value) {
  switch (value.toLowerCase()) {
    case 'hoog':
    case 'high':
      return 'Hoog';
    case 'middel':
    case 'middelmatig':
    case 'medium':
      return 'Middel';
    default:
      return 'Laag';
  }
}

String _gppRealisationLabel(String value) {
  final normalised = value.toLowerCase().replaceAll(' ', '_');
  switch (normalised) {
    case 'in_uitvoering':
    case 'inuitvoering':
    case 'in_progress':
      return 'In uitvoering';
    case 'uitgevoerd':
    case 'completed':
      return 'Uitgevoerd';
    case 'nog_niet_uitgevoerd':
    case 'neg_niet_uitgevoerd':
      return 'Nog niet uitgevoerd';
    default:
      return 'Vul aan';
  }
}
