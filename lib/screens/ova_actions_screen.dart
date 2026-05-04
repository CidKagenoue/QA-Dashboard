import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qa_dashboard/widgets/app_bars/main_app_bar.dart';

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
  final Set<int> _savingActionIds = <int>{};

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
    if (item.action.isOk == isOk || _savingActionIds.contains(item.action.id)) {
      return;
    }

    setState(() {
      _savingActionIds.add(item.action.id);
    });

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

      final updated = OvaFollowUpAction.fromJson(response);
      setState(() {
        _actions = _actions
            .map(
              (entry) => entry.action.id == item.action.id
                  ? OvaAssignedAction(action: updated, ticket: entry.ticket)
                  : entry,
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
    } finally {
      if (mounted) {
        setState(() {
          _savingActionIds.remove(item.action.id);
        });
      }
    }
  }

  Future<void> _openTicket(int ticketId) async {
    final result = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) => OvaTicketWizardScreen(ticketId: ticketId),
      ),
    );

    if (result != null && mounted) {
      await _loadActions();
    }
  }

  String get _summaryText {
    if (_isLoading) {
      return 'Openstaande opvolgacties die aan jou zijn toegewezen.';
    }

    if (_actions.length == 1) {
      return '1 openstaande opvolgactie die aan jou is toegewezen.';
    }

    return '${_actions.length} openstaande opvolgacties die aan jou zijn toegewezen.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F3),
      appBar: const MainAppBar(title: 'Mijn OVA-acties'),
      body: RefreshIndicator(
        onRefresh: _loadActions,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
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
                    'Mijn acties-overzicht',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_summaryText),
                  const SizedBox(height: 28),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_error != null)
                    _ActionErrorState(message: _error!, onRetry: _loadActions)
                  else if (_actions.isEmpty)
                    const _ActionEmptyState()
                  else
                    _ActionsOverview(
                      actions: _actions,
                      savingActionIds: _savingActionIds,
                      onOpenTicket: (item) => _openTicket(item.ticket.id),
                      onStatusChanged: _updateActionStatus,
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

class _ActionsOverview extends StatelessWidget {
  const _ActionsOverview({
    required this.actions,
    required this.savingActionIds,
    required this.onOpenTicket,
    required this.onStatusChanged,
  });

  final List<OvaAssignedAction> actions;
  final Set<int> savingActionIds;
  final ValueChanged<OvaAssignedAction> onOpenTicket;
  final Future<void> Function(OvaAssignedAction, bool) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return _ActionsTable(
            actions: actions,
            savingActionIds: savingActionIds,
            onOpenTicket: onOpenTicket,
            onStatusChanged: onStatusChanged,
          );
        }

        return Column(
          children: List.generate(actions.length, (index) {
            final item = actions[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == actions.length - 1 ? 0 : 12,
              ),
              child: _ActionMobileTile(
                item: item,
                isSaving: savingActionIds.contains(item.action.id),
                onOpenTicket: () => onOpenTicket(item),
                onStatusChanged: (isOk) => onStatusChanged(item, isOk),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ActionsTable extends StatelessWidget {
  const _ActionsTable({
    required this.actions,
    required this.savingActionIds,
    required this.onOpenTicket,
    required this.onStatusChanged,
  });

  final List<OvaAssignedAction> actions;
  final Set<int> savingActionIds;
  final ValueChanged<OvaAssignedAction> onOpenTicket;
  final Future<void> Function(OvaAssignedAction, bool) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E6DD)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: const Color(0xFFF6F7F2),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: const Row(
                children: [
                  Expanded(flex: 44, child: _TableHeaderLabel('Omschrijving')),
                  SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: _TableHeaderLabel('Ticketnummer'),
                  ),
                  SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _TableHeaderLabel('Deadline'),
                    ),
                  ),
                  SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: Center(child: _TableHeaderLabel('Status')),
                  ),
                  SizedBox(width: 12),
                  SizedBox(width: 44),
                ],
              ),
            ),
            ...List.generate(actions.length, (index) {
              final item = actions[index];
              return _ActionsTableRow(
                item: item,
                striped: index.isOdd,
                isSaving: savingActionIds.contains(item.action.id),
                onOpenTicket: () => onOpenTicket(item),
                onStatusChanged: (isOk) => onStatusChanged(item, isOk),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ActionsTableRow extends StatelessWidget {
  const _ActionsTableRow({
    required this.item,
    required this.striped,
    required this.isSaving,
    required this.onOpenTicket,
    required this.onStatusChanged,
  });

  final OvaAssignedAction item;
  final bool striped;
  final bool isSaving;
  final VoidCallback onOpenTicket;
  final ValueChanged<bool> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: striped ? const Color(0xFFF9FAF6) : Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE8ECE3))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.action.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2F382E),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item.action.typeLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7B8077),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              '#${item.ticket.id}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4D5548),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                formatOvaDate(item.action.dueDate),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4D5548),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Center(
              child: _StatusDropdown(
                isOk: item.action.isOk,
                isSaving: isSaving,
                onChanged: onStatusChanged,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 44,
            child: IconButton(
              tooltip: 'Open ticket',
              onPressed: onOpenTicket,
              icon: const Icon(Icons.open_in_new_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionMobileTile extends StatelessWidget {
  const _ActionMobileTile({
    required this.item,
    required this.isSaving,
    required this.onOpenTicket,
    required this.onStatusChanged,
  });

  final OvaAssignedAction item;
  final bool isSaving;
  final VoidCallback onOpenTicket;
  final ValueChanged<bool> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E6DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.action.description,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2F382E),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Open ticket',
                onPressed: onOpenTicket,
                icon: const Icon(Icons.open_in_new_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _InfoPill(label: 'Ticket #${item.ticket.id}'),
              _InfoPill(
                label: 'Deadline ${formatOvaDate(item.action.dueDate)}',
              ),
              _InfoPill(label: item.action.typeLabel),
              _StatusDropdown(
                isOk: item.action.isOk,
                isSaving: isSaving,
                onChanged: onStatusChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({
    required this.isOk,
    required this.isSaving,
    required this.onChanged,
  });

  final bool isOk;
  final bool isSaving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isOk
        ? const Color(0xFF6B8F2A)
        : const Color(0xFFC43C33);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: isSaving
          ? null
          : () async {
              final result = await showMenu<bool>(
                context: context,
                position: _buttonPosition(context),
                items: [
                  _statusMenuItem(value: false, label: 'NOK'),
                  _statusMenuItem(value: true, label: 'OK'),
                ],
              );
              if (result != null) {
                onChanged(result);
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isOk ? const Color(0xFFEAF4D9) : const Color(0xFFFFECEB),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isOk ? const Color(0xFF98C74D) : const Color(0xFFE8A09C),
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
                color: foregroundColor,
              ),
            ),
            const SizedBox(width: 4),
            if (isSaving)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor,
                ),
              )
            else
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: foregroundColor,
              ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<bool> _statusMenuItem({
    required bool value,
    required String label,
  }) {
    final color = value ? const Color(0xFF6B8F2A) : const Color(0xFFC43C33);

    return PopupMenuItem<bool>(
      value: value,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  RelativeRect _buttonPosition(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

    if (box == null) {
      return RelativeRect.fill;
    }

    return RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(box.size.bottomLeft(Offset.zero), ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E6DD)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF545C50),
        ),
      ),
    );
  }
}

class _TableHeaderLabel extends StatelessWidget {
  const _TableHeaderLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF545C50),
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE6C7)),
      ),
      child: const Column(
        children: [
          Icon(Icons.task_alt_rounded, size: 44, color: Color(0xFF6B8F2A)),
          SizedBox(height: 14),
          Text(
            'Je hebt geen openstaande acties',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'Zodra een opvolgactie aan jou is toegewezen, verschijnt ze hier automatisch.',
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
        borderRadius: BorderRadius.circular(8),
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
