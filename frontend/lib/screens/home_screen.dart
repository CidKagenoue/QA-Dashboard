import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/app_bars/main_app_bar.dart';
import '../models/ova_assigned_action.dart';
import '../models/ova_ticket.dart';
import '../models/jap_gpp_entry.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'jap_gpp_screen.dart';
import 'ova_dashboard_screen.dart';
import 'maintenance_inspections_screen.dart';
import '../services/jap_gpp_api_service.dart';
import '../services/maintenance_api_service.dart';
import '../services/whs_api_service.dart';
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

  static const _sidebarGreen = Color(0xFF8BC34A);
  static const _sidebarText = Color(0xFFFFFFFF);
  static const _sidebarSelected = Color(0xFF7CB342);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late _HomeSection _selected;
  int? _initialOvaTicketId;
  bool _initialOvaTicketConsumed = false;
  String? _initialJapGppModule;
  int? _initialJapGppEntryId;
  int? _initialMaintenanceInspectionId;

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
      body: Row(
        children: [
          Container(
            width: 200,
            color: HomeScreen._sidebarGreen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                _SidebarItem(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  selected: _selected == _HomeSection.dashboard,
                  onTap: () =>
                      setState(() => _selected = _HomeSection.dashboard),
                ),
                const SizedBox(height: 12),
                _SidebarItem(
                  icon: Icons.apartment_outlined,
                  label: 'WHS-Tours',
                  selected: _selected == _HomeSection.whsTours,
                  onTap: () =>
                      setState(() => _selected = _HomeSection.whsTours),
                ),
                const SizedBox(height: 12),
                _SidebarItem(
                  icon: Icons.info_outline_rounded,
                  label: 'OVA',
                  selected: _selected == _HomeSection.ova,
                  onTap: () => setState(() => _selected = _HomeSection.ova),
                ),
                const SizedBox(height: 12),
                _SidebarItem(
                  icon: Icons.build,
                  label: 'Onderhoud\nKeuringen',
                  selected: _selected == _HomeSection.onderhoud,
                  onTap: () =>
                      setState(() => _selected = _HomeSection.onderhoud),
                ),
                const SizedBox(height: 12),
                _SidebarItem(
                  icon: Icons.assignment,
                  label: 'JAP & GPP',
                  selected: _selected == _HomeSection.japGpp,
                  onTap: () => setState(() => _selected = _HomeSection.japGpp),
                ),
                const Spacer(),
              ],
            ),
          ),
          Expanded(child: _buildSectionContent(_selected)),
        ],
      ),
    );
  }

  Widget _buildSectionContent(_HomeSection section) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;

    switch (section) {
      case _HomeSection.dashboard:
        return _DashboardBody(
          authService: authService,
          onNavigate: (section) {
            setState(() {
              _selected = section;
            });
          },
        );
      case _HomeSection.whsTours:
        return WhsToursScreen(token: token ?? '');
      case _HomeSection.ova:
        final ovaTicketId = _initialOvaTicketConsumed
            ? null
            : _initialOvaTicketId;
        return OvaDashboardScreen(
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
        return MaintenanceInspectionsScreen(
          initialInspectionId: _initialMaintenanceInspectionId,
        );
      case _HomeSection.japGpp:
        return JapGppScreen(
          key: const ValueKey<String>('japGpp-screen'),
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

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? HomeScreen._sidebarSelected : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: HomeScreen._sidebarText, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                color: HomeScreen._sidebarText,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends StatefulWidget {
  const _DashboardBody({required this.authService, required this.onNavigate});

  final AuthService authService;
  final ValueChanged<_HomeSection> onNavigate;

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
        ApiService.fetchOvaTickets(token: token).catchError((_) => <Map<String, dynamic>>[]),
        ApiService.fetchMyOvaActions(token: token).catchError((_) => <Map<String, dynamic>>[]),
        JapApiService.fetchJapEntries(token: token).catchError((_) => <JapEntry>[]),
        JapApiService.fetchGppEntries(token: token).catchError((_) => <GppEntry>[]),
        MaintenanceApiService.fetchUpcomingInspections(token: token).catchError((_) => <Map<String, dynamic>>[]),
        WhsApiService.fetchRecentReports(token: token).catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;

      final japEntries = (results[2] as List<JapEntry>)
        ..sort((a, b) => b.year.compareTo(a.year));
      final gppEntries = (results[3] as List<GppEntry>)
        ..sort((a, b) {
          final endCompare = b.endYear.compareTo(a.endYear);
          if (endCompare != 0) return endCompare;
          return b.startYear.compareTo(a.startYear);
        });
      final maintenanceOverview = (results[4] as List<Map<String, dynamic>>)
        ..sort((a, b) {
          final aDate = DateTime.tryParse(a['dueDate']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = DateTime.tryParse(b['dueDate']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
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
          ...japEntries.take(3).map(
                (entry) => JapGppComment(
                  title: entry.goalMeasure,
                  author: 'JAP ${entry.year} · ${entry.domain}',
                  comment:
                      '${_japPriorityLabel(entry.priority)} · ${_japRealisationLabel(entry.realisation)}',
                ),
              ),
          ...gppEntries.take(3).map(
                (entry) => JapGppComment(
                  title: entry.goalMeasure,
                  author: 'GPP ${entry.yearLabel} · ${entry.domain}',
                  comment:
                      '${_gppPriorityLabel(entry.priority)} · ${_gppRealisationLabel(entry.realisation)}',
                ),
              ),
        ];
        _upcomingMaintenance = maintenanceOverview.take(3).map((inspection) {
          final dueDate = DateTime.tryParse(inspection['dueDate']?.toString() ?? '');
          final formatted = dueDate == null
              ? (inspection['dueDate']?.toString() ?? '')
              : '${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}/${dueDate.year}';
          final locations = inspection['locations'] is List
              ? (inspection['locations'] as List).whereType<String>().join(', ')
              : '';
          final title = inspection['equipment']?.toString() ?? '';
          return MaintenanceItem(
            title: '$title${locations.isEmpty ? '' : ' ($locations)'}',
            date: formatted,
          );
        }).toList();
        _whsRecent = (results.length > 5 ? (results[5] as List<Map<String, dynamic>>) : <Map<String, dynamic>>[])
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

  int get _nokActionsCount => _actions.where((a) => !a.action.isOk).length;

  Map<String, int> get _ticketsByType {
    final map = <String, int>{};
    for (final t in _openTickets) {
      final type = t.ovaType?.trim() ?? 'NM';
      map[type] = (map[type] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.user;
    if (user == null) {
      // Auth state not yet initialized or user not available — show loader
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: CircularProgressIndicator(color: Color(0xFF8CC63F)),
        ),
      );
    }

    final hasOvaAccess = user.isAdmin || user.access.ova || user.access.basis;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WelcomeHeader(user: user),
            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 760;
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
            const SizedBox(height: 20),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: CircularProgressIndicator(color: Color(0xFF8CC63F)),
                ),
              )
            else if (_error != null)
              _ErrorCard(message: _error!, onRetry: _loadData)
            else ...[
              // ── KPI kaarten rij ──
              if (hasOvaAccess) ...[
                _StatCardRow(
                  children: [
                    _OvaTicketsCard(
                      openTickets: _openTickets,
                      ticketsByType: _ticketsByType,
                      onTap: () => widget.onNavigate(_HomeSection.ova),
                    ),
                    _StatCard(
                      title: 'Mijn OVA Acties',
                      value: _nokActionsCount.toString(),
                      subtitle: 'NOK',
                      accentColor: const Color(0xFF8CC63F),
                      icon: Icons.format_list_bulleted_rounded,
                      onTap: () => widget.onNavigate(_HomeSection.ova),
                    ),
                    _StatCard(
                      title: 'OVA Incidenten',
                      value: _openTickets.length.toString(),
                      subtitle: 'open deze maand',
                      accentColor: const Color(0xFFF5A623),
                      icon: Icons.warning_amber_rounded,
                      onTap: () => widget.onNavigate(_HomeSection.ova),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Welcome header
// ─────────────────────────────────────────────

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFF8CC63F),
          child: Text(
            (user.displayName.isNotEmpty ? user.displayName[0] : '?')
                .toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welkom, ${user.displayName}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E2A18),
              ),
            ),
            Text(
              user.isAdmin ? 'Administrator' : 'Gebruiker',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7A62)),
            ),
          ],
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
        if (constraints.maxWidth < 600) {
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
            children: children
                .map(
                  (c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: c,
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  OVA Tickets KPI kaart
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

  Color _badgeColor(String type) {
    switch (type.trim().toLowerCase()) {
      case 'ova 3':
        return const Color(0xFFFFD4CF);
      case 'ova 2':
        return const Color(0xFFFFE2B3);
      case 'ova 1':
        return const Color(0xFFFFF0C7);
      default:
        return const Color(0xFFDDDDDD);
    }
  }

  Color _badgeTextColor(String type) {
    switch (type.trim().toLowerCase()) {
      case 'ova 3':
        return const Color(0xFFC43C33);
      case 'ova 2':
        return const Color(0xFFB55A00);
      case 'ova 1':
        return const Color(0xFFAF7A00);
      default:
        return const Color(0xFF555555);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Open OVA Tickets',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7A62),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Divider(color: Color(0xFFE8EBE3), height: 1),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${openTickets.length} Open',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2B3424),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ticketsByType.entries.map((e) {
                        final type = e.key;
                        final count = e.value;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _badgeColor(type),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$type: $count',
                            style: TextStyle(
                              color: _badgeTextColor(type),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onTap,
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF8CC63F),
                ),
              ),
            ],
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
    // Use withAlpha to avoid deprecated color component access
    final bgColor = accentColor.withAlpha((0.12 * 255).round());

    return _BaseCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7A62),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2B3424),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7A62),
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

// ─────────────────────────────────────────────
//  Error card
// ─────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      onTap: onRetry,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fout bij laden',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7A62),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 14, color: Color(0xFF2B3424)),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8CC63F),
            ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8EBE3)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  JAP & GPP dashboard kaart + model
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
          const Text(
            'JAP & GPP',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7A62),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Divider(color: Color(0xFFE8EBE3), height: 1),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Text(
              'Nog geen JAP of GPP items beschikbaar.',
              style: TextStyle(fontSize: 13, color: Color(0xFF4A4F45)),
            ),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.assignment_rounded,
                    size: 20,
                    color: Color(0xFF8CC63F),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF2B3424),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.author,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7A62),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.comment,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF4A4F45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  NEW: Upcoming maintenance kaart + model
// ─────────────────────────────────────────────

class MaintenanceItem {
  final String title;
  final String date;

  MaintenanceItem({required this.title, required this.date});
}

class _UpcomingMaintenanceCard extends StatelessWidget {
  const _UpcomingMaintenanceCard({required this.items, required this.onTap});

  final List<MaintenanceItem> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Onderhoud & Keuringen',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7A62),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Divider(color: Color(0xFFE8EBE3), height: 1),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Text(
              'Nog geen onderhouds- of keuringsitems beschikbaar.',
              style: TextStyle(fontSize: 13, color: Color(0xFF4A4F45)),
            ),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_available_rounded,
                    size: 20,
                    color: Color(0xFF8CC63F),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF2B3424),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.date,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7A62),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
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
          const Text(
            'WHS-Tours',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7A62),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Divider(color: Color(0xFFE8EBE3), height: 1),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Text(
              'Nog geen WHS tours beschikbaar.',
              style: TextStyle(fontSize: 13, color: Color(0xFF4A4F45)),
            ),
          ...items.map((item) {
            final location = item['vestiging'] is Map ? (item['vestiging']['address'] ?? item['vestiging']['name']) : (item['vestiging']?.toString() ?? 'Onbekend');
            final rawDate = item['datum'] ?? item['date'];
            String dateLabel = '';
            if (rawDate != null) {
              final parsed = DateTime.tryParse(rawDate.toString());
              if (parsed != null) {
                dateLabel = '${parsed.day.toString().padLeft(2,'0')}/${parsed.month.toString().padLeft(2,'0')}/${parsed.year}';
              } else {
                dateLabel = rawDate.toString();
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.place, size: 20, color: Color(0xFF8CC63F)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF2B3424),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (dateLabel.isNotEmpty)
                          Text(
                            dateLabel,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7A62)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
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
