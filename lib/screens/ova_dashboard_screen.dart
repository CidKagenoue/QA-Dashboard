import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import 'ova_actions_screen.dart';
import 'ova_ticket_list_screen.dart';
import 'ova_ticket_wizard_screen.dart';

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

        // Alleen de OVA content, geen eigen Scaffold/AppBar/navbars
        return _OvaContent(
          hasOvaAccess: hasOvaAccess,
          hasFullOvaAccess: hasFullOvaAccess,
          tiles: tiles,
        );
      },
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
