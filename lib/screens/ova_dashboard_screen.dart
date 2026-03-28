import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import 'ova_actions_screen.dart';
import 'ova_ticket_list_screen.dart';
import 'ova_ticket_wizard_screen.dart';
import 'profile_screen.dart';

class OvaDashboardScreen extends StatelessWidget {
  const OvaDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final user = authService.user;

        if (user == null) {
          return const Scaffold(
            body: Center(
              child: Text('Geen gebruiker gevonden. Meld je opnieuw aan.'),
            ),
          );
        }

        final hasFullOvaAccess = user.isAdmin || user.access.ova;
        final hasOvaAccess = hasFullOvaAccess || user.access.basis;
        final tiles = <_OvaTileData>[
          if (hasOvaAccess)
            _OvaTileData(
              icon: Icons.description_outlined,
              title: 'Tickets',
              subtitle: 'Open drafts en lopende OVA-tickets.',
              pageBuilder: (_) => const OvaTicketListScreen(),
            ),
          _OvaTileData(
            icon: Icons.format_list_bulleted_rounded,
            title: 'Acties',
            subtitle: 'Open jouw OVA-acties.',
            pageBuilder: (_) => const OvaActionsScreen(),
          ),
          if (hasFullOvaAccess)
            _OvaTileData(
              icon: Icons.add_rounded,
              title: 'Nieuwe Ticket',
              subtitle: 'Maak een nieuw OVA-ticket aan.',
              pageBuilder: (_) => const OvaTicketWizardScreen(),
            ),
        ];

        return Scaffold(
          backgroundColor: const Color(0xFF4B4B4B),
          appBar: AppBar(
            backgroundColor: const Color(0xFF8CC63F),
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Het hoofdmenu opent hier later.'),
                  ),
                );
              },
            ),
            titleSpacing: 0,
            title: const Text(
              'Vlotter',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Meldingen zijn hier nog niet beschikbaar.',
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AccountScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 900;
              final navItems = _buildModuleItems(context, user, hasOvaAccess);

              return isCompact
                  ? Column(
                      children: [
                        _CompactModuleBar(items: navItems),
                        Expanded(
                          child: _OvaContent(
                            hasOvaAccess: hasOvaAccess,
                            hasFullOvaAccess: hasFullOvaAccess,
                            tiles: tiles,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        _ModuleRail(items: navItems),
                        Expanded(
                          child: _OvaContent(
                            hasOvaAccess: hasOvaAccess,
                            hasFullOvaAccess: hasFullOvaAccess,
                            tiles: tiles,
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

  List<_ModuleItemData> _buildModuleItems(
    BuildContext context,
    User user,
    bool hasOvaAccess,
  ) {
    return [
      _ModuleItemData(
        icon: Icons.grid_view_rounded,
        label: 'Dashboard',
        onTap: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
      ),
      if (user.isAdmin || user.access.whsTours)
        _ModuleItemData(
          icon: Icons.apartment_outlined,
          label: 'WHS-Tours',
          onTap: () => _showModuleMessage(context, 'WHS-Tours'),
        ),
      if (hasOvaAccess)
        _ModuleItemData(
          icon: Icons.radio_button_checked_rounded,
          label: 'OVA',
          selected: true,
        ),
      if (user.isAdmin || user.access.maintenanceInspections)
        _ModuleItemData(
          icon: Icons.build_outlined,
          label: 'Onderhoud\nKeuringen',
          onTap: () => _showModuleMessage(context, 'Onderhoud & Keuringen'),
        ),
      if (user.isAdmin || user.access.japGpp)
        _ModuleItemData(
          icon: Icons.folder_open_outlined,
          label: 'SDS Fiches',
          onTap: () => _showModuleMessage(context, 'SDS Fiches'),
        ),
    ];
  }

  static void _showModuleMessage(BuildContext context, String moduleName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$moduleName is nog niet gekoppeld in dit startscherm.'),
      ),
    );
  }
}

class _OvaContent extends StatelessWidget {
  final bool hasOvaAccess;
  final bool hasFullOvaAccess;
  final List<_OvaTileData> tiles;

  const _OvaContent({
    required this.hasOvaAccess,
    required this.hasFullOvaAccess,
    required this.tiles,
  });

  @override
  Widget build(BuildContext context) {
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: hasOvaAccess
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OVA',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hasFullOvaAccess
                                ? 'Kies snel tussen Tickets, Acties en Nieuwe Ticket. Drafts kunnen per stap opgeslagen worden zodat iemand anders later kan verderwerken.'
                                : 'Je hebt Basis (OVA Acties) toegang. Daarom tonen we Tickets en Acties, maar Nieuwe Ticket blijft voorbehouden aan volledige OVA-toegang.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          if (!hasFullOvaAccess) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5FAEC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFD5E4B4),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: Color(0xFF6B8F2A),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Volledige OVA-rechten geven ook toegang tot Nieuwe Ticket. Bestaande drafts kun je hier wel al raadplegen en verder invullen.',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 56),
                          Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 28,
                              runSpacing: 28,
                              children: tiles
                                  .map((tile) => _OvaTileCard(data: tile))
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      )
                    : SizedBox(
                        height: constraints.maxHeight,
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 520),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9F9F6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFD7DBD2),
                              ),
                            ),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 48,
                                  color: Color(0xFF6C7566),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Geen OVA-toegang',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Je hebt Basis (OVA Acties) of OVA-rechten nodig om dit startscherm te openen.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OvaTileCard extends StatelessWidget {
  final _OvaTileData data;

  const _OvaTileCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: data.pageBuilder));
      },
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        width: 220,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE0E3DA)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, size: 46, color: const Color(0xFF555555)),
            const SizedBox(height: 18),
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF444444),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleRail extends StatelessWidget {
  final List<_ModuleItemData> items;

  const _ModuleRail({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      color: const Color(0xFF8CC63F),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: items
              .map((item) => _ModuleRailButton(item: item, compact: false))
              .toList(),
        ),
      ),
    );
  }
}

class _CompactModuleBar extends StatelessWidget {
  final List<_ModuleItemData> items;

  const _CompactModuleBar({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF8CC63F),
      height: 92,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return _ModuleRailButton(item: items[index], compact: true);
        },
      ),
    );
  }
}

class _ModuleRailButton extends StatelessWidget {
  final _ModuleItemData item;
  final bool compact;

  const _ModuleRailButton({required this.item, required this.compact});

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: compact ? 110 : 100,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: item.selected ? const Color(0xFF789F3A) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 20, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: item.selected ? FontWeight.w700 : FontWeight.w600,
                fontSize: compact ? 11 : 12,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );

    return compact
        ? button
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: button,
          );
  }
}

class _ModuleItemData {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  const _ModuleItemData({
    required this.icon,
    required this.label,
    this.onTap,
    this.selected = false,
  });
}

class _OvaTileData {
  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder pageBuilder;

  _OvaTileData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.pageBuilder,
  });
}
