import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ova_assigned_action.dart';
import '../models/ova_ticket.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'ova_ticket_wizard_screen.dart';

// ---------------------------------------------------------------------------
// OvaActionsScreen
//
// Geen eigen Scaffold of AppBar — rendert inline binnen OvaDashboardScreen.
// ---------------------------------------------------------------------------

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
      if (!mounted) return;
      setState(() {
        _actions = response.map(OvaAssignedAction.fromJson).toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      if (!mounted) return;
      final updated = OvaFollowUpAction.fromJson(response);
      setState(() {
        _actions = _actions
            .map((e) => e.action.id == item.action.id
                ? OvaAssignedAction(action: updated, ticket: e.ticket)
                : e)
            .toList();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openTicket(int ticketId) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OvaTicketWizardScreen(ticketId: ticketId),
      ),
    );
    if (changed == true && mounted) await _loadActions();
  }

  @override
  Widget build(BuildContext context) {
    // Geen Scaffold — alleen body-content
    return RefreshIndicator(
      onRefresh: _loadActions,
      child: LayoutBuilder(
        builder: (context, viewportConstraints) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  minHeight: viewportConstraints.maxHeight - 48,
                ),
                padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E6DD)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dashboard > OVA > Acties',
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFF7B8077)),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'OVA Acties',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bekijk en beheer jouw openstaande opvolgacties. '
                      'Acties verdwijnen automatisch zodra het ticket naar '
                      'effectiviteitscontrole gaat of formeel afgesloten wordt.',
                      style: TextStyle(
                          color: Color(0xFF586154), height: 1.45),
                    ),
                    const SizedBox(height: 28),
                    if (_isLoading)
                      const SizedBox(
                        height: 260,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      _ActionErrorState(
                          message: _error!, onRetry: _loadActions)
                    else if (_actions.isEmpty)
                      const _ActionEmptyState()
                    else
                      _ActionsTable(
                        actions: _actions,
                        onOpenTicket: (item) =>
                            _openTicket(item.ticket.id),
                        onStatusChanged: _updateActionStatus,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lege staat
// ---------------------------------------------------------------------------

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
          Text('Geen openstaande acties',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text(
            'Zodra een opvolgactie aan jou is toegewezen en het ticket nog '
            'in de acties-stap staat, verschijnt ze hier automatisch.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Foutmelding staat
// ---------------------------------------------------------------------------

class _ActionErrorState extends StatelessWidget {
  const _ActionErrorState(
      {required this.message, required this.onRetry});

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
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(
              onPressed: onRetry,
              child: const Text('Opnieuw proberen')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tabel
// ---------------------------------------------------------------------------

class _ActionsTable extends StatelessWidget {
  const _ActionsTable({
    required this.actions,
    required this.onOpenTicket,
    required this.onStatusChanged,
  });

  final List<OvaAssignedAction> actions;
  final ValueChanged<OvaAssignedAction> onOpenTicket;
  final Future<void> Function(OvaAssignedAction, bool) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E6DD)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              color: const Color(0xFFF6F7F2),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              child: const Row(
                children: [
                  Expanded(
                    flex: 52,
                    child: Text('Omschrijving',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF545C50))),
                  ),
                  SizedBox(width: 12),
                  SizedBox(
                    width: 90,
                    child: Center(
                      child: Text('Status',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF545C50))),
                    ),
                  ),
                  SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text('Deadline',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF545C50))),
                    ),
                  ),
                ],
              ),
            ),
            // Rijen
            ...List.generate(actions.length, (i) {
              return _ActionsTableRow(
                item: actions[i],
                striped: i.isOdd,
                onOpenTicket: () => onOpenTicket(actions[i]),
                onStatusChanged: (ok) => onStatusChanged(actions[i], ok),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tabelrij
// ---------------------------------------------------------------------------

class _ActionsTableRow extends StatelessWidget {
  const _ActionsTableRow({
    required this.item,
    required this.striped,
    required this.onOpenTicket,
    required this.onStatusChanged,
  });

  final OvaAssignedAction item;
  final bool striped;
  final VoidCallback onOpenTicket;
  final ValueChanged<bool> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: striped ? const Color(0xFFF9FAF6) : Colors.white,
        border:
            const Border(top: BorderSide(color: Color(0xFFE8ECE3))),
      ),
      child: InkWell(
        onTap: onOpenTicket,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 52,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.action.description,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2F382E)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ticket #${item.ticket.id} · ${item.action.typeLabel}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF7B8077)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 90,
                child: Center(
                  child: _StatusDropdown(
                    isOk: item.action.isOk,
                    onChanged: onStatusChanged,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatOvaDate(item.action.dueDate),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF4D5548)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status dropdown badge
// ---------------------------------------------------------------------------

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown(
      {required this.isOk, required this.onChanged});

  final bool isOk;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await showMenu<bool>(
          context: context,
          position: _buttonPosition(context),
          items: [
            PopupMenuItem(
              value: true,
              child: Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Color(0xFF6B8F2A),
                        shape: BoxShape.circle)),
                const SizedBox(width: 8),
                const Text('OK'),
              ]),
            ),
            PopupMenuItem(
              value: false,
              child: Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Color(0xFFC43C33),
                        shape: BoxShape.circle)),
                const SizedBox(width: 8),
                const Text('NOK'),
              ]),
            ),
          ],
        );
        if (result != null) onChanged(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isOk
              ? const Color(0xFFEAF4D9)
              : const Color(0xFFFFECEB),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isOk
                ? const Color(0xFF98C74D)
                : const Color(0xFFE8A09C),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isOk ? 'OK' : 'NOK',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isOk
                    ? const Color(0xFF6B8F2A)
                    : const Color(0xFFC43C33),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: isOk
                    ? const Color(0xFF6B8F2A)
                    : const Color(0xFFC43C33)),
          ],
        ),
      ),
    );
  }

  RelativeRect _buttonPosition(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Navigator.of(context)
        .overlay!
        .context
        .findRenderObject() as RenderBox;
    if (box == null) return RelativeRect.fill;
    return RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(box.size.bottomLeft(Offset.zero),
            ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
  }
}