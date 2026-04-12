// lib/screens/ova_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'ova_actions_screen.dart';
import 'ova_ticket_list_screen.dart';
import 'ova_ticket_wizard_screen.dart';

// ---------------------------------------------------------------------------
// OvaDashboardScreen
//
// Geen eigen Scaffold of AppBar — HomeScreen levert die al via zijn shell.
// Interne navigatie tussen OVA-subschermen verloopt via _OvaView state,
// zodat de zijbalk en topbar van HomeScreen altijd zichtbaar blijven.
// ---------------------------------------------------------------------------

enum _OvaView { home, tickets, actions, newTicket }

class OvaDashboardScreen extends StatefulWidget {
  const OvaDashboardScreen({super.key});

  @override
  State<OvaDashboardScreen> createState() => _OvaDashboardScreenState();
}

class _OvaDashboardScreenState extends State<OvaDashboardScreen> {
  _OvaView _currentView = _OvaView.home;

  void _navigateTo(_OvaView view) {
    setState(() => _currentView = view);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        final user = authService.user;

        if (user == null) {
          return const Center(
            child: Text('Geen gebruiker gevonden. Meld je opnieuw aan.'),
          );
        }

        final hasFullOvaAccess = user.isAdmin || user.access.ova;
        final hasOvaAccess = hasFullOvaAccess || user.access.basis;

        // Geen Scaffold — gewoon een Container als body
        return ColoredBox(
          color: const Color(0xFFF6F6F3),
          child: _buildView(
            hasOvaAccess: hasOvaAccess,
            hasFullOvaAccess: hasFullOvaAccess,
          ),
        );
      },
    );
  }

  Widget _buildView({
    required bool hasOvaAccess,
    required bool hasFullOvaAccess,
  }) {
    switch (_currentView) {
      case _OvaView.home:
        return _OvaHomeContent(
          hasOvaAccess: hasOvaAccess,
          hasFullOvaAccess: hasFullOvaAccess,
          onNavigate: _navigateTo,
        );
      case _OvaView.tickets:
        return OvaTicketListScreen(
          onNavigateBack: () => _navigateTo(_OvaView.home),
        );
      case _OvaView.actions:
        return const OvaActionsScreen();
      case _OvaView.newTicket:
        return OvaTicketWizardScreen(
          onClose: () => _navigateTo(_OvaView.home),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// OVA home — tegelpagina
// ---------------------------------------------------------------------------

class _OvaHomeContent extends StatelessWidget {
  const _OvaHomeContent({
    required this.hasOvaAccess,
    required this.hasFullOvaAccess,
    required this.onNavigate,
  });

  final bool hasOvaAccess;
  final bool hasFullOvaAccess;
  final ValueChanged<_OvaView> onNavigate;

  @override
  Widget build(BuildContext context) {
    final tiles = <_OvaTileData>[
      if (hasOvaAccess)
        _OvaTileData(
          icon: Icons.description_outlined,
          title: 'Tickets',
          onTap: () => onNavigate(_OvaView.tickets),
        ),
      _OvaTileData(
        icon: Icons.format_list_bulleted_rounded,
        title: 'Acties',
        onTap: () => onNavigate(_OvaView.actions),
      ),
      if (hasFullOvaAccess)
        _OvaTileData(
          icon: Icons.add_rounded,
          title: 'Nieuwe\nTicket',
          onTap: () => onNavigate(_OvaView.newTicket),
        ),
    ];

    return Padding(
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
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hasFullOvaAccess
                                ? 'Kies snel tussen Tickets, Acties en Nieuwe Ticket. Drafts kunnen per stap opgeslagen worden zodat iemand anders later kan verderwerken.'
                                : 'Je hebt Basis (OVA Acties) toegang. Tickets en Acties zijn beschikbaar; Nieuwe Ticket vereist volledige OVA-toegang.',
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
                                      'Volledige OVA-rechten geven ook toegang tot Nieuwe Ticket. Bestaande drafts kun je hier wel al raadplegen.',
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
                                  .map((t) => _OvaTileCard(data: t))
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

// ---------------------------------------------------------------------------
// Tegel kaart
// ---------------------------------------------------------------------------

class _OvaTileCard extends StatelessWidget {
  const _OvaTileCard({required this.data});
  final _OvaTileData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: data.onTap,
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
  const _OvaTileData({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
}