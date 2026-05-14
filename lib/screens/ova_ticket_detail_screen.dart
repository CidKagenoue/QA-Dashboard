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
                    child: _buildMainCard(context, _ticket!),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9DD)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb
          const Text(
            'Dashboard > OVA > Tickets',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9CA39A),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),

          // Header row
          Row(
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
                    const Text(
                      'OVA Ticket',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF243022),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ticket #${ticket.id.toString().padLeft(4, '0')}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7A62),
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Action buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (isAdmin)
                    TextButton.icon(
                      onPressed: _isDeleting ? null : _confirmDelete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Verwijderen'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFD32F2F),
                      ),
                    ),
                  if (!ticket.isClosed)
                    ElevatedButton.icon(
                      onPressed: _isDeleting ? null : _openTicketWizard,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Bewerken'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8CC63F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content
          Expanded(child: SingleChildScrollView(child: _buildContent(ticket))),
        ],
      ),
    );
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
          // Status badge
          _buildStatusBadge(ticket),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE4E9DD)),
          const SizedBox(height: 16),

          // Editable velden
          _buildFieldsGrid(ticket),

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

  Widget _buildStatusBadge(OvaTicket ticket) {
    final Color bgColor;
    final Color textColor;

    if (ticket.isClosed) {
      bgColor = const Color(0xFFEAF4D9);
      textColor = const Color(0xFF6F972D);
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOk ? const Color(0xFFEAF4D9) : const Color(0xFFFFE1DD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOk ? const Color(0xFF98C74D) : const Color(0xFFF4A49E),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  action.typeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isOk
                        ? const Color(0xFF6F972D)
                        : const Color(0xFFC43C33),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                isOk ? 'OK' : 'NOK',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isOk
                      ? const Color(0xFF6F972D)
                      : const Color(0xFFC43C33),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            action.description,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF243022),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Verantwoordelijke: ${action.assigneeLabel}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF586154)),
          ),
          Text(
            'Vervaldatum: ${formatOvaDate(action.dueDate)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF586154)),
          ),
        ],
      ),
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
