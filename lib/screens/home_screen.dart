// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qa_dashboard/screens/jap_gpp_placeholder_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ova_assigned_action.dart';
import '../models/ova_ticket.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'account_management_page.dart';
import 'departments_screen.dart';
import 'login_screen.dart';
import 'ova_dashboard_screen.dart';
import 'profile_screen.dart';
import 'maintenance_inspections_placeholder_screen.dart';
import 'whs_tours_placeholder_screen.dart';

// ─────────────────────────────────────────────
//  HomeScreen — root shell met sidebar + body
// ─────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _ActiveModule _activeModule = _ActiveModule.dashboard;

  void _selectModule(_ActiveModule module) {
    setState(() => _activeModule = module);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        final user = authService.user;
        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final hasOvaAccess =
            user.isAdmin || user.access.ova || user.access.basis;

        return Scaffold(
          backgroundColor: const Color(0xFFF6F6F3),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 860;
              if (isCompact) {
                return Column(
                  children: [
                    _TopBar(
                      authService: authService,
                      onLogout: () => _logout(context, authService),
                    ),
                    _CompactNavBar(
                      user: user,
                      active: _activeModule,
                      onSelect: _selectModule,
                    ),
                    Expanded(
                      child: _resolveBody(
                        context,
                        _activeModule,
                        authService,
                        user,
                        hasOvaAccess,
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  _SideBar(
                    user: user,
                    active: _activeModule,
                    onSelect: _selectModule,
                    onLogout: () => _logout(context, authService),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        _TopBar(
                          authService: authService,
                          onLogout: () => _logout(context, authService),
                          showLogout: false,
                        ),
                        Expanded(
                          child: _resolveBody(
                            context,
                            _activeModule,
                            authService,
                            user,
                            hasOvaAccess,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _resolveBody(
    BuildContext context,
    _ActiveModule module,
    AuthService authService,
    dynamic user,
    bool hasOvaAccess,
  ) {
    switch (module) {
      case _ActiveModule.dashboard:
        return _DashboardBody(
          authService: authService,
          onNavigate: _selectModule,
        );
      case _ActiveModule.ova:
        return hasOvaAccess
            ? const OvaDashboardScreen()
            : const _NoAccessBody(moduleName: 'OVA');
      case _ActiveModule.whsTours:
        return (user.isAdmin || user.access.whsTours)
            ? const WhsToursScreen()
            : const _NoAccessBody(moduleName: 'WHS-Tours');
      case _ActiveModule.onderhoudKeuringen:
        return (user.isAdmin || user.access.maintenanceInspections)
            ? const MaintenanceInspectionsPlaceholderScreen()
            : const _NoAccessBody(moduleName: 'Onderhoud & Keuringen');
      case _ActiveModule.japGpp:
        return (user.isAdmin || user.access.japGpp)
            ? const JapGppScreen()
            : const _NoAccessBody(moduleName: 'JAP & GPP');
      case _ActiveModule.departments:
        return const DepartmentsScreen();
      case _ActiveModule.accounts:
        return const AccountManagementPage();
    }
  }

  Future<void> _logout(
    BuildContext context,
    AuthService authService,
  ) async {
    await authService.logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }
}

// ─────────────────────────────────────────────
//  Navigatie-modules enum
// ─────────────────────────────────────────────

enum _ActiveModule {
  dashboard,
  whsTours,
  ova,
  onderhoudKeuringen,
  japGpp,
  departments,
  accounts,
}

// ─────────────────────────────────────────────
//  Sidebar (wide layout)
// ─────────────────────────────────────────────

class _SideBar extends StatelessWidget {
  const _SideBar({
    required this.user,
    required this.active,
    required this.onSelect,
    required this.onLogout,
  });

  final dynamic user;
  final _ActiveModule active;
  final ValueChanged<_ActiveModule> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: const Color(0xFF8CC63F),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Row(
                children: [
                  const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  const Text(
                    'Vlotter',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0x33FFFFFF), height: 1),
            const SizedBox(height: 8),
            _SidebarItem(
              icon: Icons.grid_view_rounded,
              label: 'Dashboard',
              selected: active == _ActiveModule.dashboard,
              onTap: () => onSelect(_ActiveModule.dashboard),
            ),
            if (user.isAdmin || user.access.whsTours)
              _SidebarItem(
                icon: Icons.apartment_outlined,
                label: 'WHS-Tours',
                selected: active == _ActiveModule.whsTours,
                onTap: () => onSelect(_ActiveModule.whsTours),
              ),
            if (user.isAdmin || user.access.ova || user.access.basis)
              _SidebarItem(
                icon: Icons.radio_button_checked_rounded,
                label: 'OVA',
                selected: active == _ActiveModule.ova,
                onTap: () => onSelect(_ActiveModule.ova),
              ),
            if (user.isAdmin || user.access.maintenanceInspections)
              _SidebarItem(
                icon: Icons.build_outlined,
                label: 'Onderhoud\nKeuringen',
                selected: active == _ActiveModule.onderhoudKeuringen,
                onTap: () => onSelect(_ActiveModule.onderhoudKeuringen),
              ),
            if (user.isAdmin || user.access.japGpp)
              _SidebarItem(
                icon: Icons.folder_open_outlined,
                label: 'JAP & GPP',
                selected: active == _ActiveModule.japGpp,
                onTap: () => onSelect(_ActiveModule.japGpp),
              ),
            const Spacer(),
            const Divider(color: Color(0x33FFFFFF), height: 1),
            const SizedBox(height: 4),
            _SidebarItem(
              icon: Icons.settings_outlined,
              label: 'Instellingen',
              selected: false,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountScreen()),
              ),
            ),
            _SidebarItem(
              icon: Icons.logout_rounded,
              label: 'Afmelden',
              selected: false,
              onTap: onLogout,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF6FA832) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                    height: 1.25,
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

// ─────────────────────────────────────────────
//  Compact nav bar (mobile / narrow)
// ─────────────────────────────────────────────

class _CompactNavBar extends StatelessWidget {
  const _CompactNavBar({
    required this.user,
    required this.active,
    required this.onSelect,
  });

  final dynamic user;
  final _ActiveModule active;
  final ValueChanged<_ActiveModule> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF8CC63F),
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        children: [
          _CompactNavItem(
            icon: Icons.grid_view_rounded,
            label: 'Dashboard',
            selected: active == _ActiveModule.dashboard,
            onTap: () => onSelect(_ActiveModule.dashboard),
          ),
          if (user.isAdmin || user.access.whsTours)
            _CompactNavItem(
              icon: Icons.apartment_outlined,
              label: 'WHS-Tours',
              selected: active == _ActiveModule.whsTours,
              onTap: () => onSelect(_ActiveModule.whsTours),
            ),
          if (user.isAdmin || user.access.ova || user.access.basis)
            _CompactNavItem(
              icon: Icons.radio_button_checked_rounded,
              label: 'OVA',
              selected: active == _ActiveModule.ova,
              onTap: () => onSelect(_ActiveModule.ova),
            ),
          if (user.isAdmin || user.access.maintenanceInspections)
            _CompactNavItem(
              icon: Icons.build_outlined,
              label: 'Onderhoud\nKeuringen',
              selected: active == _ActiveModule.onderhoudKeuringen,
              onTap: () => onSelect(_ActiveModule.onderhoudKeuringen),
            ),
          if (user.isAdmin || user.access.japGpp)
            _CompactNavItem(
              icon: Icons.folder_open_outlined,
              label: 'JAP & GPP',
              selected: active == _ActiveModule.japGpp,
              onTap: () => onSelect(_ActiveModule.japGpp),
            ),
        ],
      ),
    );
  }
}

class _CompactNavItem extends StatelessWidget {
  const _CompactNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 88,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF6FA832) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Top bar
// ─────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.authService,
    required this.onLogout,
    this.showLogout = true,
  });

  final AuthService authService;
  final VoidCallback onLogout;
  final bool showLogout;

  @override
  Widget build(BuildContext context) {
    final user = authService.user;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8EBE3))),
      ),
      child: Row(
        children: [
          const Text(
            'QA Dashboard',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF2B3424),
            ),
          ),
          const Spacer(),
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                user.displayName,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF5A6354),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF555F4E),
            ),
            tooltip: 'Meldingen',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Meldingen zijn hier nog niet beschikbaar.'),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: Color(0xFF555F4E),
            ),
            tooltip: 'Instellingen',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountScreen()),
            ),
          ),
          if (showLogout)
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Color(0xFF555F4E)),
              tooltip: 'Afmelden',
              onPressed: onLogout,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Dashboard body
// ─────────────────────────────────────────────

class _DashboardBody extends StatefulWidget {
  const _DashboardBody({
    required this.authService,
    required this.onNavigate,
  });

  final AuthService authService;
  final ValueChanged<_ActiveModule> onNavigate;

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  bool _isLoading = true;
  String? _error;
  List<OvaTicket> _tickets = const [];
  List<OvaAssignedAction> _actions = const [];

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

      final results = await Future.wait([
        ApiService.fetchOvaTickets(token: token),
        ApiService.fetchMyOvaActions(token: token),
      ]);

      if (!mounted) return;

      setState(() {
        _tickets = (results[0] as List)
            .map((j) => OvaTicket.fromJson(j as Map<String, dynamic>))
            .toList();
        _actions = (results[1] as List)
            .map((j) => OvaAssignedAction.fromJson(j as Map<String, dynamic>))
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

  List<OvaTicket> get _openTickets =>
      _tickets.where((t) => t.isOpen).toList();

  int get _nokActionsCount =>
      _actions.where((a) => !a.action.isOk).length;

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
    final user = widget.authService.user!;
    final hasOvaAccess =
        user.isAdmin || user.access.ova || user.access.basis;

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
                      onTap: () => widget.onNavigate(_ActiveModule.ova),
                    ),
                    _StatCard(
                      title: 'Mijn OVA Acties',
                      value: _nokActionsCount.toString(),
                      subtitle: 'NOK',
                      accentColor: const Color(0xFF8CC63F),
                      icon: Icons.format_list_bulleted_rounded,
                      onTap: () => widget.onNavigate(_ActiveModule.ova),
                    ),
                    _StatCard(
                      title: 'OVA Incidenten',
                      value: _openTickets.length.toString(),
                      subtitle: 'open deze maand',
                      accentColor: const Color(0xFFF5A623),
                      icon: Icons.warning_amber_rounded,
                      onTap: () => widget.onNavigate(_ActiveModule.ova),
                    ),
                    const _AfvalverwerkingCard(),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // ── Onderste rij ──
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > 760;
                  final cards = <Widget>[
                    if (_actions.isNotEmpty)
                      _RecentActionsCard(
                        actions: _actions.take(3).toList(),
                        onTap: () => widget.onNavigate(_ActiveModule.ova),
                      ),

                    // === REPLACED: show JAP & GPP commentaar and Upcoming maintenance ===
                    _JapGppCommentaarCard(
                      items: [
                        JapGppComment(
                          title: 'FD Soft Handafwasmiddel',
                          author: 'Milton Boon',
                          comment: 'Opgebruiken en vervangen',
                        ),
                        JapGppComment(
                          title: 'Loctite Quick Gasket',
                          author: 'Tina Dupon',
                          comment: 'Deze wordt niet meer gemaakt',
                        ),
                      ],
                      onTap: () => widget.onNavigate(_ActiveModule.japGpp),
                    ),
                    _UpcomingMaintenanceCard(
                      items: [
                        MaintenanceItem(
                          title: 'Stookinstallatie De Dietrich (Netweg 2)',
                          date: '03/07/2025',
                        ),
                        MaintenanceItem(
                          title: 'Elektrische installatie (Netweg 4)',
                          date: '15/07/2025',
                        ),
                        MaintenanceItem(
                          title: 'Brandblussers (Tunnelweg 1)',
                          date: '28/12/2025',
                        ),
                      ],
                      onTap: () =>
                          widget.onNavigate(_ActiveModule.onderhoudKeuringen),
                    ),
                  ];

                  if (cards.isEmpty) return const SizedBox.shrink();

                  return wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: cards
                              .map(
                                (c) => Expanded(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.only(right: 16),
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
                                  padding:
                                      const EdgeInsets.only(bottom: 16),
                                  child: c,
                                ),
                              )
                              .toList(),
                        );
                },
              ),
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
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7A62),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Stat card rij
// ─────────────────────────────────────────────

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
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: c,
                    ))
                .toList(),
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children
                .map((c) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: c,
                      ),
                    ))
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
                              horizontal: 8, vertical: 6),
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
                icon: const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF8CC63F)),
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
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7A62),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(value,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2B3424))),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7A62))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Afvalverwerking kaart (voorbeeld)
// ─────────────────────────────────────────────

class _AfvalverwerkingCard extends StatelessWidget {
  const _AfvalverwerkingCard();

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      onTap: () async {
        final url = Uri.parse('https://matis.example.com');

        // Capture messenger before async gap to avoid use_build_context_synchronously
        final messenger = ScaffoldMessenger.of(context);

        if (await canLaunchUrl(url)) {
          await launchUrl(url);
        } else {
          messenger.showSnackBar(
            const SnackBar(content: Text('Kon MATIS website niet openen.')),
          );
        }
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFF8CC63F)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Afvalverwerking',
                    style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7A62),
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 6),
                Text('MATIS Website',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2B3424))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Recent actions kaart (voorbeeld)
// ─────────────────────────────────────────────

class _RecentActionsCard extends StatelessWidget {
  const _RecentActionsCard({
    required this.actions,
    required this.onTap,
  });

  final List<OvaAssignedAction> actions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recente acties',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7A62),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Divider(color: Color(0xFFE8EBE3), height: 1),
          const SizedBox(height: 12),
          // Use spread without unnecessary toList()
          ...actions.map((a) {
            final titleText = (a.actionTitle!.isNotEmpty ? a.actionTitle : (a.action.title ?? ''))?.trim();
            final assignedByText = (a.assignedBy)?.trim();

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: a.action.isOk
                          ? const Color(0xFFEAF4D9)
                          : const Color(0xFFFFECEC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      a.action.isOk ? Icons.check : Icons.close,
                      size: 16,
                      color: a.action.isOk
                          ? const Color(0xFF6B8F2A)
                          : const Color(0xFFC43C33),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleText!,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2B3424)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          assignedByText!,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6B7A62)),
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
          Text(message,
              style: const TextStyle(fontSize: 14, color: Color(0xFF2B3424))),
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
//  NEW: JAP & GPP Commentaar kaart + model
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

class _JapGppCommentaarCard extends StatelessWidget {
  const _JapGppCommentaarCard({
    required this.items,
    required this.onTap,
  });

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
            'JAP & GPP Commentaar',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7A62),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Divider(color: Color(0xFFE8EBE3), height: 1),
          const SizedBox(height: 14),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.comment_rounded,
                      size: 20, color: Color(0xFF8CC63F)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF2B3424))),
                        const SizedBox(height: 4),
                        Text(item.author ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF6B7A62))),
                        const SizedBox(height: 6),
                        Text(item.comment ?? '',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF4A4F45))),
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

  MaintenanceItem({
    required this.title,
    required this.date,
  });
}

class _UpcomingMaintenanceCard extends StatelessWidget {
  const _UpcomingMaintenanceCard({
    required this.items,
    required this.onTap,
  });

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
            'Naderende Onderhoud & Keuringen',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7A62),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Divider(color: Color(0xFFE8EBE3), height: 1),
          const SizedBox(height: 14),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.event_available_rounded,
                      size: 20, color: Color(0xFF8CC63F)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF2B3424))),
                        const SizedBox(height: 4),
                        Text(item.date ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF6B7A62))),
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
//  No access body
// ─────────────────────────────────────────────

class _NoAccessBody extends StatelessWidget {
  const _NoAccessBody({required this.moduleName});
  final String moduleName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE4E9DD)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 48, color: Color(0xFF8CC63F)),
            const SizedBox(height: 24),
            Text(
              'Geen toegang tot $moduleName',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E2A18),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Je hebt geen rechten om deze module te bekijken.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF6B7A62),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
