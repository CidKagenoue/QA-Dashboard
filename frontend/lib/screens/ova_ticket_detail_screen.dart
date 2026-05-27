import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ova_ticket.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'ova_ticket_wizard_screen.dart';

class OvaTicketDetailScreen extends StatefulWidget {
  const OvaTicketDetailScreen({
    super.key,
    this.ticket,
    this.ticketId,
    required this.onClose,
  }) : assert(ticket != null || ticketId != null);

  final OvaTicket? ticket;
  final int? ticketId;
  final VoidCallback onClose;

  @override
  State<OvaTicketDetailScreen> createState() => _OvaTicketDetailScreenState();
}

class _OvaTicketDetailScreenState extends State<OvaTicketDetailScreen> {
  OvaTicket? _ticket;
  bool _isLoading = false;
  bool _isDeleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
    if (_ticket == null) {
      _loadTicket();
    }
  }

  Future<void> _loadTicket() async {
    final ticketId = widget.ticketId ?? _ticket?.id;
    if (ticketId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await context.read<AuthService>().getValidAccessToken();
      final response = await ApiService.fetchOvaTicket(
        token: token,
        ticketId: ticketId,
      );

      if (!mounted) return;

      final ticket = OvaTicket.fromJson(response);
      setState(() {
        _ticket = ticket;
      });
    } catch (error) {
      if (!mounted) return;
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

  Future<void> _openTicketWizard() async {
    final ticket = _ticket;
    if (ticket == null) return;

    final result = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (context) =>
            OvaTicketWizardScreen(ticketId: ticket.id, embedded: true),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      await _loadTicket();
    }
  }

  Future<void> _confirmDelete() async {
    final ticket = _ticket;
    if (ticket == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ticket verwijderen'),
        content: const Text(
          'Weet je zeker dat je dit OVA-ticket wilt verwijderen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kDanger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final authService = context.read<AuthService>();
      final messenger = ScaffoldMessenger.of(context);
      final token = await authService.getValidAccessToken();
      await ApiService.deleteOvaTicket(token: token, ticketId: ticket.id);

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('Ticket verwijderd')),
      );
      widget.onClose();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _ticket == null
                    ? _ErrorView(message: _error!, onRetry: _loadTicket)
                    : _ticket == null
                        ? const Center(
                            child: Text('Ticket niet beschikbaar'),
                          )
                        : Padding(
                            padding:
                                const EdgeInsets.fromLTRB(24, 20, 24, 24),
                            child: SizedBox.expand(
                              child: _buildMainCard(context, _ticket!),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard(BuildContext context, OvaTicket ticket) {
    final isAdmin = context.watch<AuthService>().user?.isAdmin == true;

    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadius2xl),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Breadcrumb(segments: ['Dashboard', 'OVA', 'Tickets']),
          const SizedBox(height: 16),
          _buildHeader(ticket: ticket, isAdmin: isAdmin),
          const SizedBox(height: 20),
          Expanded(child: SingleChildScrollView(child: _buildContent(ticket))),
        ],
      ),
    );
  }

  Widget _buildHeader({required OvaTicket ticket, required bool isAdmin}) {
    final actions = _buildHeaderActions(ticket, isAdmin);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final title = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _BackButton(onTap: widget.onClose),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'OVA Ticket',
                        style: TextStyle(
                          fontSize: 13,
                          color: kTextTertiary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(ticket),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '#${ticket.id.toString().padLeft(4, '0')}',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildHeaderActions(OvaTicket ticket, bool isAdmin) {
    return [
      if (!ticket.isClosed)
        ElevatedButton.icon(
          onPressed: _isDeleting ? null : _openTicketWizard,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Bewerken'),
        ),
      if (isAdmin)
        OutlinedButton.icon(
          onPressed: _isDeleting ? null : _confirmDelete,
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Verwijderen'),
          style: OutlinedButton.styleFrom(
            foregroundColor: kDanger,
            side: const BorderSide(color: kDangerBorder),
          ),
        ),
    ];
  }

  Widget _buildContent(OvaTicket ticket) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryStrip(ticket),
        const SizedBox(height: 18),
        _buildResponsiveDetailLayout(ticket),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kDangerBg,
              borderRadius: BorderRadius.circular(kRadiusMd),
              border: Border.all(color: kDangerBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: kDanger, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: kDanger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryStrip(OvaTicket ticket) {
    final metrics = [
      _MetricData(
        icon: Icons.category_outlined,
        label: 'Type',
        value: _display(ticket.ovaType),
      ),
      _MetricData(
        icon: Icons.event_note_outlined,
        label: 'Datum vaststelling',
        value: _findingDateLabel(ticket),
      ),
      _MetricData(
        icon: Icons.business_outlined,
        label: 'Vestiging',
        value: _display(ticket.branchLabel),
      ),
      _MetricData(
        icon: Icons.account_tree_outlined,
        label: 'Afdeling',
        value: _display(ticket.departmentLabel),
      ),
      _MetricData(
        icon: Icons.checklist_rtl_outlined,
        label: 'Opvolging',
        value: _actionProgressLabel(ticket),
      ),
      _MetricData(
        icon: Icons.person_outline,
        label: 'Aangemaakt door',
        value: ticket.createdBy.displayName,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kSurfaceMuted,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 860) {
            final widgets = <Widget>[];
            for (var i = 0; i < metrics.length; i++) {
              widgets.add(
                Expanded(child: _SummaryMetric(data: metrics[i])),
              );
              if (i != metrics.length - 1) {
                widgets.add(const SizedBox(
                  height: 36,
                  child: VerticalDivider(width: 24, color: kBorderSubtle),
                ));
              }
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: widgets,
            );
          }

          final itemWidth = constraints.maxWidth >= 540
              ? (constraints.maxWidth - 16) / 2
              : constraints.maxWidth;

          return Wrap(
            spacing: 16,
            runSpacing: 14,
            children: metrics
                .map(
                  (metric) => SizedBox(
                    width: itemWidth,
                    child: _SummaryMetric(data: metric),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildResponsiveDetailLayout(OvaTicket ticket) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1040;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: _buildPrimaryColumn(ticket)),
              const SizedBox(width: 18),
              SizedBox(width: 380, child: _buildSideColumn(ticket)),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPrimaryColumn(ticket),
            const SizedBox(height: 18),
            _buildSideColumn(ticket),
          ],
        );
      },
    );
  }

  Widget _buildPrimaryColumn(OvaTicket ticket) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionPanel(
          title: 'Incident',
          icon: Icons.report_problem_outlined,
          child: _buildInfoGrid([
            (label: 'Redenen', value: _reasonsLabel(ticket), wide: true),
            (
              label: 'Omschrijving incident',
              value: _display(ticket.incidentDescription),
              wide: true,
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _buildSectionPanel(
          title: 'Oorzakenanalyse',
          icon: Icons.manage_search_outlined,
          child: _buildInfoGrid([
            (
              label: 'Methode',
              value: _display(ticket.causeAnalysisMethod),
              wide: false,
            ),
            (
              label: 'Notities',
              value: _display(ticket.causeAnalysisNotes),
              wide: true,
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _buildActionsPanel(ticket),
      ],
    );
  }

  Widget _buildSideColumn(OvaTicket ticket) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEffectivenessPanel(ticket),
        const SizedBox(height: 16),
        _buildMetaPanel(ticket),
        if (ticket.isClosed) ...[
          const SizedBox(height: 16),
          _buildClosurePanel(ticket),
        ],
      ],
    );
  }

  Widget _buildEffectivenessPanel(OvaTicket ticket) {
    return _buildSectionPanel(
      title: 'Effectiviteit',
      icon: Icons.verified_outlined,
      child: _buildInfoGrid([
        (
          label: 'Datum effectiviteit',
          value: ticket.effectivenessDate != null
              ? formatOvaDateTime(ticket.effectivenessDate!)
              : '-',
          wide: false,
        ),
        (
          label: 'Notities effectiviteit',
          value: _display(ticket.effectivenessNotes),
          wide: true,
        ),
      ], minItemWidth: 160),
    );
  }

  Widget _buildSectionPanel({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: kBrandGreenSubtle,
                  borderRadius: BorderRadius.circular(kRadiusSm),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: kBrandGreenDeep),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoGrid(
    List<({String label, String value, bool wide})> fields, {
    double minItemWidth = 220,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 20.0;
        final columnCount =
            ((constraints.maxWidth + gap) / (minItemWidth + gap)).floor().clamp(
                  1,
                  3,
                );
        final itemWidth =
            (constraints.maxWidth - (gap * (columnCount - 1))) / columnCount;

        return Wrap(
          spacing: gap,
          runSpacing: 16,
          children: fields.map((field) {
            return SizedBox(
              width: field.wide ? constraints.maxWidth : itemWidth,
              child: _InfoItem(label: field.label, value: field.value),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildActionsPanel(OvaTicket ticket) {
    return _buildSectionPanel(
      title: 'Opvolgacties',
      icon: Icons.assignment_turned_in_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _openActionsLabel(ticket),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: kTextTertiary,
            ),
          ),
          const SizedBox(height: 14),
          if (ticket.actions.isEmpty)
            const Text(
              'Geen opvolgacties geregistreerd.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: kTextTertiary,
                height: 1.4,
              ),
            )
          else
            ...List.generate(ticket.actions.length, (index) {
              final action = ticket.actions[index];
              return Padding(
                padding: EdgeInsets.only(
                    top: index == 0 ? 0 : 10),
                child: _ActionCard(action: action),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildClosurePanel(OvaTicket ticket) {
    return _buildSectionPanel(
      title: 'Afsluiting',
      icon: Icons.lock_outline_rounded,
      child: _buildInfoGrid([
        (
          label: 'Gesloten op',
          value: ticket.closedAt != null
              ? formatOvaDateTime(ticket.closedAt!)
              : '-',
          wide: false,
        ),
        (
          label: 'Gesloten door',
          value: _display(ticket.closedBy?.displayName),
          wide: false,
        ),
        (
          label: 'Sluitingsnotities',
          value: _display(ticket.closureNotes),
          wide: true,
        ),
      ]),
    );
  }

  Widget _buildMetaPanel(OvaTicket ticket) {
    return _buildSectionPanel(
      title: 'Historiek',
      icon: Icons.history_rounded,
      child: _buildInfoGrid([
        (
          label: 'Aangemaakt door',
          value: ticket.createdBy.displayName,
          wide: false,
        ),
        (
          label: 'Aangemaakt op',
          value: formatOvaDateTime(ticket.createdAt),
          wide: false,
        ),
        (
          label: 'Laatst bewerkt door',
          value: ticket.lastEditedBy.displayName,
          wide: false,
        ),
        (
          label: 'Laatst bewerkt op',
          value: formatOvaDateTime(ticket.updatedAt),
          wide: false,
        ),
      ], minItemWidth: 160),
    );
  }

  String _display(String? value, {String fallback = '-'}) {
    final normalized = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized == null || normalized.isEmpty) {
      return fallback;
    }
    return normalized;
  }

  String _findingDateLabel(OvaTicket ticket) {
    return formatOvaDateTime(ticket.findingDate ?? ticket.createdAt);
  }

  String _reasonsLabel(OvaTicket ticket) {
    final labels = <String>[
      ...ticket.reasons
          .map((reason) => reason.trim())
          .where((r) => r.isNotEmpty),
      if (_display(ticket.otherReason) != '-')
        'Andere: ${_display(ticket.otherReason)}',
    ];

    if (labels.isEmpty) {
      return '-';
    }
    return labels.join(', ');
  }

  String _actionProgressLabel(OvaTicket ticket) {
    if (ticket.actions.isEmpty) {
      return 'Geen acties';
    }

    final done = ticket.actions.where((action) => action.isOk).length;
    return '$done/${ticket.actions.length} OK';
  }

  String _openActionsLabel(OvaTicket ticket) {
    if (ticket.actions.isEmpty) {
      return 'Geen acties gekoppeld';
    }

    final open = ticket.actions.where((action) => !action.isOk).length;
    if (open == 0) {
      return 'Alle acties staan op OK';
    }
    if (open == 1) {
      return '1 actie staat nog op NOK';
    }
    return '$open acties staan nog op NOK';
  }

  Widget _buildStatusBadge(OvaTicket ticket) {
    final Color bg;
    final Color fg;
    final Color border;

    if (ticket.isClosed) {
      bg = kSuccessBg;
      fg = kSuccess;
      border = kSuccessBorder;
    } else if (ticket.status.trim().toLowerCase() == 'open') {
      bg = kWarningBg;
      fg = kWarning;
      border = kWarningBorder;
    } else {
      bg = kDangerBg;
      fg = kDanger;
      border = kDangerBorder;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: border),
      ),
      child: Text(
        ticket.statusLabel,
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

// ─────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: kBrandGreenSoft,
            borderRadius: BorderRadius.circular(kRadiusSm),
          ),
          alignment: Alignment.center,
          child: Icon(data.icon, size: 18, color: kBrandGreenDeep),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: kTextTertiary,
                  height: 1.2,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.trim() == '-';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: kTextTertiary,
            letterSpacing: 0.2,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: isEmpty ? kTextMuted : kTextPrimary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action});

  final OvaFollowUpAction action;

  String _display(String? value) {
    final normalized = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
    return (normalized == null || normalized.isEmpty) ? '-' : normalized;
  }

  @override
  Widget build(BuildContext context) {
    final isOk = action.isOk;
    final statusFg = isOk ? kSuccess : kDanger;
    final statusBg = isOk ? kSuccessBg : kDangerBg;
    final statusBorder = isOk ? kSuccessBorder : kDangerBorder;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceMuted,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(kRadiusPill),
                  border: Border.all(color: kBorder),
                ),
                child: Text(
                  action.typeLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kTextSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(kRadiusPill),
                  border: Border.all(color: statusBorder),
                ),
                child: Text(
                  isOk ? 'OK' : 'NOK',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: statusFg,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _display(action.description),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _ActionMeta(
                icon: Icons.person_outline,
                label: action.assigneeLabel,
              ),
              _ActionMeta(
                icon: Icons.event_rounded,
                label: 'Deadline ${formatOvaDate(action.dueDate)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionMeta extends StatelessWidget {
  const _ActionMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: kTextTertiary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: kTextSecondary,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.segments});
  final List<String> segments;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      final isLast = i == segments.length - 1;
      children.add(
        Text(
          segments[i],
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
            color: isLast ? kTextSecondary : kTextTertiary,
            letterSpacing: 0.1,
          ),
        ),
      );
      if (!isLast) {
        children.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.chevron_right_rounded,
              size: 16, color: kTextMuted),
        ));
      }
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Terug',
      child: Material(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadiusMd),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kSurfaceMuted,
              borderRadius: BorderRadius.circular(kRadiusMd),
              border: Border.all(color: kBorder),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.arrow_back_rounded,
                color: kTextPrimary, size: 20),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: kDanger, size: 36),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Opnieuw proberen'),
            ),
          ],
        ),
      ),
    );
  }
}
