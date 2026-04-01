import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ova_assigned_action.dart';
import '../models/ova_ticket.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'ova_ticket_wizard_screen.dart';

class OvaActionsScreen extends StatefulWidget {
  const OvaActionsScreen({super.key});

  @override
  State<OvaActionsScreen> createState() => _OvaActionsScreenState();
}

class _OvaActionsScreenState extends State<OvaActionsScreen> {
  bool _isLoading = true;
  String? _error;
  List<OvaAssignedAction> _actions = const [];

  @override
  void initState() {
    super.initState();
    _loadActions();
  }

  Future<void> _loadActions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await context.read<AuthService>().getValidAccessToken();
      final response = await ApiService.fetchMyOvaActions(token: token);
      if (!mounted) {
        return;
      }

      setState(() {
        _actions = response.map(OvaAssignedAction.fromJson).toList();
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

  Future<void> _updateActionStatus(OvaAssignedAction item, bool isOk) async {
    try {
      final token = await context.read<AuthService>().getValidAccessToken();
      final response = await ApiService.updateOvaAction(
        token: token,
        actionId: item.action.id,
        payload: {'status': isOk ? 'ok' : 'nok'},
      );
      if (!mounted) {
        return;
      }

      final updatedAction = OvaFollowUpAction.fromJson(response);
      setState(() {
        _actions = _actions
            .map(
              (existing) => existing.action.id == item.action.id
                  ? OvaAssignedAction(
                      action: updatedAction,
                      ticket: existing.ticket,
                    )
                  : existing,
            )
            .toList();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _openTicket(int ticketId) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => OvaTicketWizardScreen(ticketId: ticketId),
      ),
    );

    if (changed == true && mounted) {
      await _loadActions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8CC63F),
        foregroundColor: Colors.white,
        title: const Text('Mijn OVA-acties'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadActions,
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
                  Text(
                    'Openstaande opvolgacties',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Acties verdwijnen automatisch uit deze lijst zodra het ticket doorgaat naar de effectiviteitscontrole of formeel wordt afgesloten.',
                  ),
                  const SizedBox(height: 28),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_error != null)
                    _ActionErrorState(message: _error!, onRetry: _loadActions)
                  else if (_actions.isEmpty)
                    const _ActionEmptyState()
                  else
                    Column(
                      children: _actions
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _AssignedActionCard(
                                item: item,
                                onOpenTicket: () => _openTicket(item.ticket.id),
                                onStatusChanged: (isOk) =>
                                    _updateActionStatus(item, isOk),
                              ),
                            ),
                          )
                          .toList(),
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

class _AssignedActionCard extends StatelessWidget {
  const _AssignedActionCard({
    required this.item,
    required this.onOpenTicket,
    required this.onStatusChanged,
  });

  final OvaAssignedAction item;
  final VoidCallback onOpenTicket;
  final ValueChanged<bool> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE6C7)),
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
                      item.action.description,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2B3424),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ticket #${item.ticket.id} • ${item.action.typeLabel}',
                      style: const TextStyle(color: Color(0xFF5D6656)),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: onOpenTicket,
                child: const Text('Open ticket'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Deadline: ${formatOvaDate(item.action.dueDate)}',
            style: const TextStyle(color: Color(0xFF4F5847)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ChoiceChip(
                label: const Text('NOK'),
                selected: !item.action.isOk,
                onSelected: (_) => onStatusChanged(false),
              ),
              ChoiceChip(
                label: const Text('OK'),
                selected: item.action.isOk,
                onSelected: (_) => onStatusChanged(true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionEmptyState extends StatelessWidget {
  const _ActionEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6C7)),
      ),
      child: const Column(
        children: [
          Icon(Icons.task_alt_rounded, size: 44, color: Color(0xFF6B8F2A)),
          SizedBox(height: 14),
          Text(
            'Geen openstaande acties',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'Zodra een opvolgactie aan jou is toegewezen en het ticket nog in de acties-stap staat, verschijnt ze hier automatisch.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ActionErrorState extends StatelessWidget {
  const _ActionErrorState({required this.message, required this.onRetry});

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
