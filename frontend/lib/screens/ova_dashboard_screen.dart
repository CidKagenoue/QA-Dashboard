import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/design/app_access_denied.dart';
import '../widgets/design/app_breadcrumb.dart';
import 'ova_actions_screen.dart';
import 'ova_ticket_list_screen.dart';
import 'ova_ticket_wizard_screen.dart';

enum OvaDashboardInitialPage { overview, tickets, actions }

class OvaDashboardScreen extends StatelessWidget {
  const OvaDashboardScreen({
    super.key,
    this.initialPage = OvaDashboardInitialPage.overview,
    this.initialTicketId,
    this.onCloseInitialTicket,
  });

  final OvaDashboardInitialPage initialPage;
  final int? initialTicketId;
  final VoidCallback? onCloseInitialTicket;

  @override
  Widget build(BuildContext context) {
    if (initialTicketId != null) {
      return OvaTicketWizardScreen(
        ticketId: initialTicketId,
        embedded: true,
        onClose: onCloseInitialTicket,
      );
    }

    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (routeContext) => _buildInitialPage(routeContext),
      ),
    );
  }

  Widget _buildInitialPage(BuildContext routeContext) {
    switch (initialPage) {
      case OvaDashboardInitialPage.tickets:
        return OvaTicketListScreen(
          embedded: true,
          onNavigateBack: () => _replaceWithOverview(routeContext),
        );
      case OvaDashboardInitialPage.actions:
        return OvaActionsScreen(
          embedded: true,
          onNavigateBack: () => _replaceWithOverview(routeContext),
        );
      case OvaDashboardInitialPage.overview:
        return _OvaOverviewRoute();
    }
  }

  void _replaceWithOverview(BuildContext routeContext) {
    Navigator.of(routeContext).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => _OvaOverviewRoute()),
    );
  }
}

class _OvaOverviewRoute extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final user = authService.user;

        if (user == null) {
          return const Center(
            child: Text('Geen gebruiker gevonden. Meld je opnieuw aan.'),
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
              pageBuilder: (context) => OvaTicketListScreen(
                embedded: true,
                onNavigateBack: () => Navigator.of(context).pop(),
              ),
            ),
          _OvaTileData(
            icon: Icons.checklist_rtl_rounded,
            title: 'Acties',
            subtitle: 'Open jouw OVA-opvolgacties.',
            pageBuilder: (context) => OvaActionsScreen(
              embedded: true,
              onNavigateBack: () => Navigator.of(context).pop(),
            ),
          ),
          if (hasFullOvaAccess)
            _OvaTileData(
              icon: Icons.add_circle_outline_rounded,
              title: 'Nieuw ticket',
              subtitle: 'Maak een nieuw OVA-ticket aan.',
              pageBuilder: (context) => OvaTicketWizardScreen(
                embedded: true,
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
        ];

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
      color: kBackground,
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
      child: Container(
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(kRadius2xl),
          border: Border.all(color: kBorder),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(36, 32, 36, 36),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: hasOvaAccess
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Breadcrumb(segments: ['Dashboard', 'OVA']),
                          const SizedBox(height: 16),
                          const Text(
                            'OVA',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary,
                              letterSpacing: -0.4,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            hasFullOvaAccess
                                ? 'Beheer tickets, opvolg jouw acties en maak nieuwe OVA-dossiers aan. Drafts kunnen per stap opgeslagen worden zodat een collega later kan verderwerken.'
                                : 'Je hebt Basis (OVA Acties) toegang. Tickets en Acties zijn beschikbaar; Nieuw ticket vereist volledige OVA-rechten.',
                            style: const TextStyle(
                              fontSize: 15,
                              color: kTextSecondary,
                              height: 1.55,
                            ),
                          ),
                          if (!hasFullOvaAccess) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: kBrandGreenSubtle,
                                borderRadius: BorderRadius.circular(kRadiusLg),
                                border: Border.all(color: kBrandGreenSoft),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: kBrandGreenDeep,
                                    size: 22,
                                  ),
                                  SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      'Volledige OVA-rechten geven ook toegang tot Nieuw ticket. Bestaande drafts kun je hier wel al raadplegen en verder invullen.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: kTextSecondary,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 36),
                          Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 20,
                              runSpacing: 20,
                              children: tiles
                                  .map((tile) => _OvaTileCard(data: tile))
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      )
                    : SizedBox(
                        height: constraints.maxHeight,
                        child: const AppAccessDenied(
                          title: 'Geen OVA-toegang',
                          message:
                              'Je hebt Basis (OVA Acties) of OVA-rechten nodig om dit startscherm te openen.',
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

class _OvaTileCard extends StatefulWidget {
  final _OvaTileData data;

  const _OvaTileCard({required this.data});

  @override
  State<_OvaTileCard> createState() => _OvaTileCardState();
}

class _OvaTileCardState extends State<_OvaTileCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        child: Material(
          color: kSurface,
          borderRadius: BorderRadius.circular(kRadiusXl),
          child: InkWell(
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: widget.data.pageBuilder));
            },
            borderRadius: BorderRadius.circular(kRadiusXl),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 240,
              height: 224,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kRadiusXl),
                border: Border.all(
                  color: _hovered ? kBrandGreenDark : kBorder,
                  width: _hovered ? 1.4 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: kBrandGreenSoft,
                      borderRadius: BorderRadius.circular(kRadiusLg),
                    ),
                    child: Icon(
                      widget.data.icon,
                      size: 28,
                      color: kBrandGreenDeep,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.data.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.data.subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: kTextTertiary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
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

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.segments});

  final List<String> segments;

  @override
  Widget build(BuildContext context) {
    return AppBreadcrumb(segments: segments);
  }
}
