import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ova_ticket.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
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
              backgroundColor: const Color(0xFFD32F2F),
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
      backgroundColor: const Color(0xFFF6F6F3),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _ticket == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadTicket,
                            child: const Text('Opnieuw proberen'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _ticket == null
                ? const Center(child: Text('Ticket niet beschikbaar'))
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E9DD)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard > OVA > Tickets',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9CA39A),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),

          _buildHeader(ticket: ticket, isAdmin: isAdmin),
          const SizedBox(height: 16),

          Expanded(child: SingleChildScrollView(child: _buildContent(ticket))),
        ],
      ),
    );
  }

  Widget _buildHeader({required OvaTicket ticket, required bool isAdmin}) {
    final actions = _buildHeaderActions(ticket, isAdmin);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final title = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.arrow_back, color: Color(0xFF243022)),
              tooltip: 'Terug',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OVA Ticket #${ticket.id.toString().padLeft(4, '0')}',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF243022),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _headerSubtitle(ticket),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7A62),
                      height: 1.2,
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
                const SizedBox(height: 14),
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
              children: actions,
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildHeaderActions(OvaTicket ticket, bool isAdmin) {
    return [
      if (isAdmin)
        TextButton.icon(
          onPressed: _isDeleting ? null : _confirmDelete,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Verwijderen'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFD32F2F)),
        ),
      if (!ticket.isClosed)
        ElevatedButton.icon(
          onPressed: _isDeleting ? null : _openTicketWizard,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Bewerken'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8CC63F),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
    ];
  }

  Widget _buildContent(OvaTicket ticket) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E9DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryStrip(ticket),
          const SizedBox(height: 16),
          _buildResponsiveDetailLayout(ticket),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _headerSubtitle(OvaTicket ticket) {
    return '${_display(ticket.ovaType, fallback: 'Geen type')} - ${_findingDateLabel(ticket)}';
  }

  Widget _buildSummaryStrip(OvaTicket ticket) {
    final metrics = [
      (
        flex: 4,
        widget: _buildSummaryMetric(
          icon: Icons.category_outlined,
          label: 'Type',
          value: _display(ticket.ovaType),
        ),
      ),
      (
        flex: 6,
        widget: _buildSummaryMetric(
          icon: Icons.event_note_outlined,
          label: 'Datum vaststelling',
          value: _findingDateLabel(ticket),
        ),
      ),
      (
        flex: 5,
        widget: _buildSummaryMetric(
          icon: Icons.business_outlined,
          label: 'Vestiging',
          value: _display(ticket.branchLabel),
        ),
      ),
      (
        flex: 5,
        widget: _buildSummaryMetric(
          icon: Icons.account_tree_outlined,
          label: 'Afdeling',
          value: _display(ticket.departmentLabel),
        ),
      ),
      (
        flex: 5,
        widget: _buildSummaryMetric(
          icon: Icons.checklist_rtl_outlined,
          label: 'Opvolging',
          value: _actionProgressLabel(ticket),
        ),
      ),
      (
        flex: 6,
        widget: _buildSummaryMetric(
          icon: Icons.person_outline,
          label: 'Aangemaakt door',
          value: ticket.createdBy.displayName,
        ),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E9DD)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 860) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 66,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildStatusBadge(ticket),
                  ),
                ),
                const SizedBox(width: 12),
                ...List.generate(metrics.length, (index) {
                  return Expanded(
                    flex: metrics[index].flex,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 0 : 8,
                        right: index == metrics.length - 1 ? 0 : 8,
                      ),
                      child: metrics[index].widget,
                    ),
                  );
                }),
              ],
            );
          }

          final itemWidth = constraints.maxWidth >= 540
              ? (constraints.maxWidth - 14) / 2
              : constraints.maxWidth;

          return Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: itemWidth,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildStatusBadge(ticket),
                ),
              ),
              ...metrics.map(
                (metric) => SizedBox(width: itemWidth, child: metric.widget),
              ),
            ],
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
              const SizedBox(width: 16),
              SizedBox(width: 370, child: _buildSideColumn(ticket)),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPrimaryColumn(ticket),
            const SizedBox(height: 16),
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
        const SizedBox(height: 14),
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
        const SizedBox(height: 14),
        _buildActionsPanel(ticket),
      ],
    );
  }

  Widget _buildSideColumn(OvaTicket ticket) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEffectivenessPanel(ticket),
        const SizedBox(height: 14),
        _buildMetaPanel(ticket),
        if (ticket.isClosed) ...[
          const SizedBox(height: 14),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E9DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF6B7A62)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2B3424),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
        const gap = 18.0;
        final columnCount =
            ((constraints.maxWidth + gap) / (minItemWidth + gap)).floor().clamp(
              1,
              3,
            );
        final itemWidth =
            (constraints.maxWidth - (gap * (columnCount - 1))) / columnCount;

        return Wrap(
          spacing: gap,
          runSpacing: 14,
          children: fields.map((field) {
            return SizedBox(
              width: field.wide ? constraints.maxWidth : itemWidth,
              child: _buildInfoItem(field.label, field.value),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildInfoItem(String label, String value) {
    final empty = value.trim() == '-';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8A9386),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: empty ? const Color(0xFF8A9386) : const Color(0xFF243022),
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF4D9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFF5F8424)),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8A9386),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF243022),
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
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
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7A62),
            ),
          ),
          const SizedBox(height: 12),
          if (ticket.actions.isEmpty)
            _buildEmptyText('Geen opvolgacties geregistreerd.')
          else
            ...ticket.actions.map(_buildActionCard),
        ],
      ),
    );
  }

  Widget _buildClosurePanel(OvaTicket ticket) {
    return _buildSectionPanel(
      title: 'Afsluiting',
      icon: Icons.lock_outline,
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
      title: 'Meta',
      icon: Icons.history_outlined,
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

  Widget _buildEmptyText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF7D8678),
        height: 1.35,
      ),
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
    final Color bgColor;
    final Color textColor;

    if (ticket.isClosed) {
      bgColor = const Color(0xFFEAF4D9);
      textColor = const Color(0xFF6F972D);
    } else if (ticket.status.trim().toLowerCase() == 'open') {
      bgColor = const Color(0xFFFFF3D8);
      textColor = const Color(0xFF9A6400);
    } else {
      bgColor = const Color(0xFFFFE1DD);
      textColor = const Color(0xFFC43C33);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: textColor.withValues(alpha: 0.24)),
      ),
      child: Text(
        ticket.statusLabel,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildFieldsGrid(OvaTicket ticket) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Algemeen ──────────────────────────────────────────
        _buildSectionTitle('Algemeen'),
        const SizedBox(height: 12),
        _buildField('Type OVA', _buildReadOnlyText(ticket.ovaType ?? '-')),
        const SizedBox(height: 16),
        _buildField(
          'Datum vaststelling',
          _buildReadOnlyText(
            ticket.findingDate != null
                ? formatOvaDateTime(ticket.findingDate!)
                : formatOvaDateTime(ticket.createdAt),
          ),
        ),
        const SizedBox(height: 16),
        _buildField(
          'Redenen',
          _buildReadOnlyText(
            ticket.reasons.isEmpty ? '-' : ticket.reasons.join(', '),
          ),
        ),
        if (ticket.otherReason?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 16),
          _buildField(
            'Andere reden',
            _buildReadOnlyText(ticket.otherReason!.trim()),
          ),
        ],
        const SizedBox(height: 16),
        _buildField(
          'Omschrijving incident',
          _buildReadOnlyText(
            ticket.incidentDescription?.trim().isNotEmpty == true
                ? ticket.incidentDescription!.trim()
                : '-',
          ),
        ),

        const SizedBox(height: 28),
        const Divider(color: Color(0xFFE4E9DD)),
        const SizedBox(height: 20),

        // ── Oorzakenanalyse ───────────────────────────────────
        _buildSectionTitle('Oorzakenanalyse'),
        const SizedBox(height: 12),
        _buildField(
          'Methode',
          _buildReadOnlyText(ticket.causeAnalysisMethod ?? '-'),
        ),
        const SizedBox(height: 16),
        _buildField(
          'Notities',
          _buildReadOnlyText(
            ticket.causeAnalysisNotes?.trim().isNotEmpty == true
                ? ticket.causeAnalysisNotes!.trim()
                : '-',
          ),
        ),

        const SizedBox(height: 28),
        const Divider(color: Color(0xFFE4E9DD)),
        const SizedBox(height: 20),

        // ── Opvolgacties ──────────────────────────────────────
        _buildSectionTitle('Opvolgacties'),
        const SizedBox(height: 12),
        if (ticket.actions.isEmpty)
          _buildReadOnlyText('-')
        else
          ...ticket.actions.map((action) => _buildActionCard(action)),

        const SizedBox(height: 28),
        const Divider(color: Color(0xFFE4E9DD)),
        const SizedBox(height: 20),

        // ── Effectiviteit ─────────────────────────────────────
        _buildSectionTitle('Effectiviteit'),
        const SizedBox(height: 12),
        _buildField(
          'Datum effectiviteit',
          _buildReadOnlyText(
            ticket.effectivenessDate != null
                ? formatOvaDateTime(ticket.effectivenessDate!)
                : '-',
          ),
        ),
        const SizedBox(height: 16),
        _buildField(
          'Notities effectiviteit',
          _buildReadOnlyText(
            ticket.effectivenessNotes?.trim().isNotEmpty == true
                ? ticket.effectivenessNotes!.trim()
                : '-',
          ),
        ),

        if (ticket.isClosed) ...[
          const SizedBox(height: 28),
          const Divider(color: Color(0xFFE4E9DD)),
          const SizedBox(height: 20),

          // ── Afsluiting ────────────────────────────────────
          _buildSectionTitle('Afsluiting'),
          const SizedBox(height: 12),
          _buildField(
            'Gesloten op',
            _buildReadOnlyText(
              ticket.closedAt != null
                  ? formatOvaDateTime(ticket.closedAt!)
                  : '-',
            ),
          ),
          const SizedBox(height: 16),
          _buildField(
            'Gesloten door',
            _buildReadOnlyText(ticket.closedBy?.displayName ?? '-'),
          ),
          const SizedBox(height: 16),
          _buildField(
            'Sluitingsnotities',
            _buildReadOnlyText(
              ticket.closureNotes?.trim().isEmpty == true
                  ? '-'
                  : ticket.closureNotes ?? '-',
            ),
          ),
        ],

        const SizedBox(height: 28),
        const Divider(color: Color(0xFFE4E9DD)),
        const SizedBox(height: 20),

        // ── Meta ──────────────────────────────────────────────
        _buildSectionTitle('Meta'),
        const SizedBox(height: 12),
        _buildField(
          'Aangemaakt door',
          _buildReadOnlyText(ticket.createdBy.displayName),
        ),
        const SizedBox(height: 16),
        _buildField(
          'Aangemaakt op',
          _buildReadOnlyText(formatOvaDateTime(ticket.createdAt)),
        ),
        const SizedBox(height: 16),
        _buildField(
          'Laatst bewerkt door',
          _buildReadOnlyText(ticket.lastEditedBy.displayName),
        ),
        const SizedBox(height: 16),
        _buildField(
          'Laatst bewerkt op',
          _buildReadOnlyText(formatOvaDateTime(ticket.updatedAt)),
        ),
      ],
    );
  }

  Widget _buildField(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF9CA39A),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6B7A62),
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _buildActionCard(OvaFollowUpAction action) {
    final isOk = action.isOk;
    final statusColor = isOk
        ? const Color(0xFF5F8424)
        : const Color(0xFFC43C33);
    final statusBg = isOk ? const Color(0xFFEAF4D9) : const Color(0xFFFFE1DD);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCF8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4E9DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF3EA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  action.typeLabel,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF536348),
                    height: 1.1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  isOk ? 'OK' : 'NOK',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _display(action.description),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF243022),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          _buildActionMeta(
            icon: Icons.person_outline,
            label: action.assigneeLabel,
          ),
          const SizedBox(height: 5),
          _buildActionMeta(
            icon: Icons.event_outlined,
            label: 'Deadline ${formatOvaDate(action.dueDate)}',
          ),
        ],
      ),
    );
  }

  Widget _buildActionMeta({required IconData icon, required String label}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF7D8678)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF586154),
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyText(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF243022),
          height: 1.3,
        ),
      ),
    );
  }
}
