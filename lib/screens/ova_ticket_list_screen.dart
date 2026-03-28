import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ova_ticket.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'ova_ticket_wizard_screen.dart';

class OvaTicketListScreen extends StatefulWidget {
  const OvaTicketListScreen({super.key});

  @override
  State<OvaTicketListScreen> createState() => _OvaTicketListScreenState();
}

class _OvaTicketListScreenState extends State<OvaTicketListScreen> {
  bool _isLoading = true;
  String? _error;
  List<OvaTicket> _tickets = const [];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await context.read<AuthService>().getValidAccessToken();
      final response = await ApiService.fetchOvaTickets(token: token);
      if (!mounted) {
        return;
      }

      setState(() {
        _tickets = response.map(OvaTicket.fromJson).toList();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

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

  Future<void> _openTicket({int? ticketId}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => OvaTicketWizardScreen(ticketId: ticketId),
      ),
    );

    if (changed == true && mounted) {
      await _loadTickets();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.user;
    final canCreate = user != null && (user.isAdmin || user.access.ova);
    final activeTickets = _tickets.where((ticket) => !ticket.isClosed).toList();
    final closedTickets = _tickets.where((ticket) => ticket.isClosed).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8CC63F),
        foregroundColor: Colors.white,
        title: const Text('OVA Tickets'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTickets,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OVA-tickets',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Onvolledige tickets blijven zichtbaar zolang ze in behandeling zijn. Afgesloten tickets tonen we apart zodat de formele afronding en historiek bewaard blijven.',
                            ),
                          ],
                        ),
                      ),
                      if (canCreate) const SizedBox(width: 16),
                      if (canCreate)
                        ElevatedButton.icon(
                          onPressed: () => _openTicket(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Nieuw ticket'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_error != null)
                    _ErrorState(message: _error!, onRetry: _loadTickets)
                  else if (_tickets.isEmpty)
                    _EmptyTicketState(
                      canCreate: canCreate,
                      onCreate: canCreate ? () => _openTicket() : null,
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (activeTickets.isNotEmpty) ...[
                          const _TicketSectionHeading(title: 'Lopende tickets'),
                          ...activeTickets.map(
                            (ticket) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _TicketCard(
                                ticket: ticket,
                                onOpen: () => _openTicket(ticketId: ticket.id),
                              ),
                            ),
                          ),
                        ],
                        if (closedTickets.isNotEmpty) ...[
                          if (activeTickets.isNotEmpty)
                            const SizedBox(height: 12),
                          const _TicketSectionHeading(
                            title: 'Gesloten tickets',
                          ),
                          ...closedTickets.map(
                            (ticket) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _TicketCard(
                                ticket: ticket,
                                onOpen: () => _openTicket(ticketId: ticket.id),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onOpen});

  final OvaTicket ticket;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final stepLabel =
        kOvaTicketStepLabels[(ticket.currentStep - 1).clamp(0, 6).toInt()];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE6C7)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFE4F0CC),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Color(0xFF6B8F2A),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Ticket #${ticket.id}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2B3424),
                      ),
                    ),
                    _StatusChip(
                      label: ticket.statusLabel,
                      color: ticket.isClosed
                          ? const Color(0xFF3C7D3A)
                          : ticket.isOpen
                          ? const Color(0xFF315D7A)
                          : const Color(0xFF6B8F2A),
                      backgroundColor: ticket.isClosed
                          ? const Color(0xFFDFF0DE)
                          : ticket.isOpen
                          ? const Color(0xFFE3F0FA)
                          : const Color(0xFFEAF3D7),
                    ),
                    _StatusChip(
                      label: 'Stap ${ticket.currentStep}/7',
                      color: const Color(0xFF56624A),
                      backgroundColor: const Color(0xFFEDEFE9),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  ticket.findingDate == null
                      ? 'Datum vaststelling nog niet ingevuld'
                      : 'Datum vaststelling: ${formatOvaDateTime(ticket.findingDate!)}',
                  style: const TextStyle(color: Color(0xFF5F6A57)),
                ),
                if ((ticket.ovaType ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Type OVA: ${ticket.ovaType}',
                    style: const TextStyle(color: Color(0xFF5F6A57)),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Volgende focus: $stepLabel',
                  style: const TextStyle(
                    color: Color(0xFF3E4638),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Laatst aangepast door ${ticket.lastEditedBy.displayName} op ${formatOvaDateTime(ticket.updatedAt)}',
                  style: const TextStyle(color: Color(0xFF6D7765)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          ElevatedButton(
            onPressed: onOpen,
            child: Text(ticket.isClosed ? 'Bekijken' : 'Openen'),
          ),
        ],
      ),
    );
  }
}

class _TicketSectionHeading extends StatelessWidget {
  const _TicketSectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2B3424),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

class _EmptyTicketState extends StatelessWidget {
  const _EmptyTicketState({required this.canCreate, this.onCreate});

  final bool canCreate;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6C7)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 44, color: Color(0xFF6B8F2A)),
          const SizedBox(height: 14),
          const Text(
            'Nog geen OVA-tickets gevonden',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            canCreate
                ? 'Maak een eerste ticket aan en sla het tussentijds op als draft zodra stap 1, 2 of 3 klaar is.'
                : 'Zodra een ticket gestart is, verschijnt het hier zodat jij het verder kunt opvolgen.',
            textAlign: TextAlign.center,
          ),
          if (onCreate != null) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nieuw ticket'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6F6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1C9C9)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Opnieuw proberen'),
          ),
        ],
      ),
    );
  }
}
