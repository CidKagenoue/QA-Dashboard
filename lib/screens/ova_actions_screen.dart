import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qa_dashboard/widgets/app_bars/main_app_bar.dart';

import '../models/ova_assigned_action.dart';
import '../models/ova_ticket.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'ova_ticket_wizard_screen.dart';

enum _ActionScope { mine, all }

class OvaActionsScreen extends StatefulWidget {
  const OvaActionsScreen({
    super.key,
    this.embedded = false,
    this.onNavigateBack,
  });

  final bool embedded;
  final VoidCallback? onNavigateBack;

  @override
  State<OvaActionsScreen> createState() => _OvaActionsScreenState();
}

class _OvaActionsScreenState extends State<OvaActionsScreen> {
  bool _isLoading = true;
  String? _error;
  List<OvaAssignedAction> _actions = const [];
  _ActionScope _selectedScope = _ActionScope.mine;
  bool _scopeInitialized = false;
  bool _canViewAllActions = false;
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
      final authService = context.read<AuthService>();
      final token = await authService.getValidAccessToken();
      final user = authService.user;
      final canViewAll = user != null && (user.isAdmin || user.access.ova);
      var requestedScope = _selectedScope;
      if (!_scopeInitialized) {
        requestedScope = canViewAll ? _ActionScope.all : _ActionScope.mine;
      } else if (!canViewAll && requestedScope == _ActionScope.all) {
        requestedScope = _ActionScope.mine;
      }

      final response = await ApiService.fetchOvaActions(
        token: token,
        scope: _scopeApiValue(requestedScope),
      );
      final rawActions = response['actions'];
      if (rawActions is! List) {
        throw Exception('Invalid OVA action list received from the server');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _scopeInitialized = true;
        _canViewAllActions =
            response['canViewAllActions'] == true || canViewAll;
        _selectedScope = response['scope'] == 'all'
            ? _ActionScope.all
            : _ActionScope.mine;
        _actions = rawActions
            .whereType<Map>()
            .map(
              (action) =>
                  OvaAssignedAction.fromJson(Map<String, dynamic>.from(action)),
            )
            .toList();
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

  String _scopeApiValue(_ActionScope scope) {
    switch (scope) {
      case _ActionScope.mine:
        return 'mine';
      case _ActionScope.all:
        return 'all';
    }
  }

  void _selectScope(_ActionScope scope) {
    if (_selectedScope == scope || !_canViewAllActions) {
      return;
    }

    setState(() {
      _selectedScope = scope;
    });
    _loadActions();
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
        builder: (_) => OvaTicketWizardScreen(
          ticketId: ticketId,
          embedded: widget.embedded,
        ),
      ),
    );

    if (result != null && mounted) {
      await _loadActions();
    }
  }

  String get _summaryText {
    if (_isLoading) {
      return _selectedScope == _ActionScope.all
          ? 'Openstaande opvolgacties binnen OVA.'
          : 'Openstaande opvolgacties die aan jou zijn toegewezen.';
    }

    if (_selectedScope == _ActionScope.all) {
      if (_actions.length == 1) {
        return '1 openstaande opvolgactie binnen OVA.';
      }

      return '${_actions.length} openstaande opvolgacties binnen OVA.';
    }

    if (_actions.length == 1) {
      return '1 openstaande opvolgactie die aan jou is toegewezen.';
    }

    return '${_actions.length} openstaande opvolgacties die aan jou zijn toegewezen.';
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
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
                if (widget.embedded && widget.onNavigateBack != null) ...[
                  TextButton.icon(
                    onPressed: widget.onNavigateBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('OVA overzicht'),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  _selectedScope == _ActionScope.all
                      ? 'Alle OVA-acties'
                      : 'Mijn acties-overzicht',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_summaryText),
                if (_canViewAllActions) ...[
                  const SizedBox(height: 18),
                  _ActionScopeTabs(
                    selectedScope: _selectedScope,
                    onSelected: _selectScope,
                  ),
                ],
                const SizedBox(height: 28),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  _ActionErrorState(message: _error!, onRetry: _loadActions)
                else if (_actions.isEmpty)
                  _ActionEmptyState(scope: _selectedScope)
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
    );

    if (widget.embedded) {
      return ColoredBox(color: const Color(0xFFF6F6F3), child: content);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F3),
      appBar: const MainAppBar(title: 'Mijn OVA-acties'),
      body: content,
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

class _ActionScopeTabs extends StatelessWidget {
  const _ActionScopeTabs({
    required this.selectedScope,
    required this.onSelected,
  });

  final _ActionScope selectedScope;
  final ValueChanged<_ActionScope> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionScopeChip(
          label: 'Mijn acties',
          selected: selectedScope == _ActionScope.mine,
          onTap: () => onSelected(_ActionScope.mine),
        ),
        _ActionScopeChip(
          label: 'Alle acties',
          selected: selectedScope == _ActionScope.all,
          onTap: () => onSelected(_ActionScope.all),
        ),
      ],
    );
  }
}

class _ActionScopeChip extends StatelessWidget {
  const _ActionScopeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFEAF4D9),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF4E721C) : const Color(0xFF4C5448),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFF98C74D) : const Color(0xFFD7DBD2),
      ),
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
                    width: 180,
                    child: _TableHeaderLabel('Verantwoordelijke'),
                  ),
                  SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: _TableHeaderLabel('Ticketnummer'),
                  ),
                  SizedBox(width: 12),
                  SizedBox(width: 110, child: _TableHeaderLabel('Deadline')),
                  SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: Center(child: _TableHeaderLabel('Status')),
                  ),
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
    return Material(
      color: striped ? const Color(0xFFF9FAF6) : Colors.white,
      child: InkWell(
        onTap: onOpenTicket,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE8ECE3))),
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
                width: 180,
                child: Text(
                  item.action.assigneeLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF4D5548),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
                child: Text(
                  formatOvaDate(item.action.dueDate),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF4D5548),
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
            ],
          ),
        ),
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onOpenTicket,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E6DD)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.action.description,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2F382E),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _InfoPill(label: 'Ticket #${item.ticket.id}'),
                  _InfoPill(label: item.action.assigneeLabel),
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
        ),
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
  const _ActionEmptyState({required this.scope});

  final _ActionScope scope;

  @override
  Widget build(BuildContext context) {
    final isAllScope = scope == _ActionScope.all;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE6C7)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.task_alt_rounded,
            size: 44,
            color: Color(0xFF6B8F2A),
          ),
          const SizedBox(height: 14),
          Text(
            isAllScope
                ? 'Geen openstaande OVA-acties'
                : 'Je hebt geen openstaande acties',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            isAllScope
                ? 'Zodra er een opvolgactie op een open OVA-ticket staat, verschijnt ze hier automatisch.'
                : 'Zodra een opvolgactie aan jou is toegewezen, verschijnt ze hier automatisch.',
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
