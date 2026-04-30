import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_bars/main_app_bar.dart';
import '../models/ova_assigned_action.dart';
import '../models/ova_ticket.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'jap_gpp_screen.dart';
import 'ova_dashboard_screen.dart';

enum _HomeSection {
  dashboard,
  whsTours,
  ova,
  onderhoud,
  japGpp,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const _sidebarGreen = Color(0xFF8BC34A);
  static const _sidebarText = Color(0xFFFFFFFF);
  static const _sidebarSelected = Color(0xFF7CB342);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _HomeSection _selected = _HomeSection.dashboard;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MainAppBar(title: 'Vlotter',),
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
                  onTap: () => setState(() => _selected = _HomeSection.dashboard),
                ),
                const SizedBox(height: 12),
                _SidebarItem(
                  icon: Icons.apartment_outlined,
                  label: 'WHS-Tours',
                  selected: _selected == _HomeSection.whsTours,
                  onTap: () => setState(() => _selected = _HomeSection.whsTours),
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
                  onTap: () => setState(() => _selected = _HomeSection.onderhoud),
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
          Expanded(
            child: _buildSectionContent(_selected),
          ),
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
        return const Center(child: Text('WHS-Tours'));
      case _HomeSection.ova:
        return const OvaDashboardScreen();
      case _HomeSection.onderhoud:
        return const Center(child: Text('Onderhoud & Keuringen'));
      case _HomeSection.japGpp:
        return JapGppScreen(token: token ?? '');
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
  const _DashboardBody({
    required this.authService,
    required this.onNavigate,
  });

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
                        onTap: () => widget.onNavigate(_HomeSection.ova),
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
                        onTap: () => widget.onNavigate(_HomeSection.japGpp),
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
                            widget.onNavigate(_HomeSection.onderhoud),
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
          ...actions.map((a) {
            final titleText = ((a.actionTitle?.isNotEmpty ?? false) ? a.actionTitle : (a.action.title ?? ''))?.trim() ?? 'Untitled';
            final assignedByText = (a.assignedBy)?.trim() ?? 'Unknown';

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
                          titleText,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2B3424)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          assignedByText,
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
                        Text(item.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF2B3424))),
                        const SizedBox(height: 4),
                        Text(item.author,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF6B7A62))),
                        const SizedBox(height: 6),
                        Text(item.comment,
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
                        Text(item.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF2B3424))),
                        const SizedBox(height: 4),
                        Text(item.date,
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

