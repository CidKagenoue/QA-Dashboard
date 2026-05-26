import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ova_assigned_action.dart';
import '../models/ova_ticket.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'ova_ticket_detail_screen.dart';
import 'ova_ticket_wizard_screen.dart';

part 'ova_action_detail_widgets.dart';

class OvaActionDetailScreen extends StatefulWidget {
  const OvaActionDetailScreen({super.key, required this.initialAction});

  final OvaAssignedAction initialAction;

  @override
  State<OvaActionDetailScreen> createState() => _OvaActionDetailScreenState();
}

class _OvaActionDetailScreenState extends State<OvaActionDetailScreen> {
  late OvaAssignedAction _item;
  OvaTicket? _ticket;
  bool _isLoadingTicket = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _changed = false;
  String? _ticketError;

  @override
  void initState() {
    super.initState();
    _item = widget.initialAction;
    _loadTicket();
  }

  Future<void> _loadTicket() async {
    setState(() {
      _isLoadingTicket = true;
      _ticketError = null;
    });

    try {
      final token = await context.read<AuthService>().getValidAccessToken();
      final response = await ApiService.fetchOvaTicket(
        token: token,
        ticketId: _item.ticket.id,
      );

      if (!mounted) {
        return;
      }

      final ticket = OvaTicket.fromJson(response);
      final refreshedAction = _findAction(ticket, _item.action.id);
      setState(() {
        _ticket = ticket;
        if (refreshedAction != null) {
          _item = OvaAssignedAction(
            action: refreshedAction,
            ticket: _item.ticket,
          );
        } else {
          _ticketError = 'Deze actie staat niet meer op het gekoppelde ticket.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _ticketError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTicket = false;
        });
      }
    }
  }

  OvaFollowUpAction? _findAction(OvaTicket ticket, int actionId) {
    for (final action in ticket.actions) {
      if (action.id == actionId) {
        return action;
      }
    }
    return null;
  }

  Future<void> _updateStatus(bool isOk) async {
    if (_item.action.isOk == isOk || _isSaving || _isDeleting) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final token = await context.read<AuthService>().getValidAccessToken();
      final response = await ApiService.updateOvaAction(
        token: token,
        actionId: _item.action.id,
        payload: {'status': isOk ? 'ok' : 'nok'},
      );

      if (!mounted) {
        return;
      }

      final updatedAction = OvaFollowUpAction.fromJson(response);
      setState(() {
        _item = OvaAssignedAction(action: updatedAction, ticket: _item.ticket);
        _changed = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Actiestatus bijgewerkt')));
      await _loadTicket();
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
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteAction() async {
    if (_isDeleting || _isSaving) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Opvolgactie verwijderen'),
          content: const Text(
            'Weet je zeker dat je deze opvolgactie permanent wilt verwijderen?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuleren'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
              ),
              child: const Text('Verwijderen'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isDeleting = true;
    });

    try {
      final token = await context.read<AuthService>().getValidAccessToken();
      await ApiService.deleteOvaAction(token: token, actionId: _item.action.id);

      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('Opvolgactie verwijderd')),
      );
      navigator.pop(true);
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
          _isDeleting = false;
        });
      }
    }
  }

  Future<void> _openTicketDetail() async {
    if (_isDeleting) {
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => OvaTicketDetailScreen(
          ticket: _ticket,
          ticketId: _item.ticket.id,
          onClose: () => Navigator.of(context).pop(true),
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {
        _changed = true;
      });
      await _loadTicket();
    }
  }

  Future<void> _openEditWizard() async {
    if (_isDeleting) {
      return;
    }

    final result = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (context) =>
            OvaTicketWizardScreen(ticketId: _item.ticket.id, embedded: true),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _changed = true;
      });
      await _loadTicket();
    }
  }

  void _close() {
    Navigator.of(context).pop(_changed);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _close();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F3),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final outerPadding = compact
                ? const EdgeInsets.all(16)
                : const EdgeInsets.fromLTRB(24, 20, 24, 24);

            return ListView(
              padding: outerPadding,
              children: [
                Container(
                  width: double.infinity,
                  padding: compact
                      ? const EdgeInsets.all(20)
                      : const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(compact ? 18 : 24),
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
                          fontSize: 11,
                          color: Color(0xFF7B8077),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildSummaryStrip(),
                      const SizedBox(height: 18),
                      _buildResponsiveContent(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        final title = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: _close,
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Terug naar acties',
              color: const Color(0xFF243022),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Opvolgactie #${_item.action.id.toString().padLeft(4, '0')}',
                    style: const TextStyle(
                      fontSize: 30,
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

        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: compact ? WrapAlignment.start : WrapAlignment.end,
          children: [
            _ActionStatusMenuButton(
              isOk: _item.action.isOk,
              isSaving: _isSaving,
              onChanged: _updateStatus,
            ),
            _HeaderIconButton(
              icon: Icons.edit_outlined,
              tooltip: 'Bewerken',
              onPressed: _isDeleting ? null : _openEditWizard,
              foregroundColor: const Color(0xFF5F8424),
              borderColor: const Color(0xFF98C74D),
              backgroundColor: Colors.white,
            ),
            _HeaderIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Verwijderen',
              onPressed: _isDeleting || _isSaving ? null : _deleteAction,
              isLoading: _isDeleting,
              foregroundColor: const Color(0xFFD32F2F),
              borderColor: const Color(0xFFF1B5B5),
              backgroundColor: Colors.white,
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 16), actions],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 18),
            actions,
          ],
        );
      },
    );
  }

  Widget _buildSummaryStrip() {
    final metrics = [
      _ActionMetricData(
        icon: Icons.category_outlined,
        label: 'Type',
        value: _item.action.typeLabel,
      ),
      _ActionMetricData(
        icon: Icons.flag_outlined,
        label: 'Status',
        value: _item.action.isOk ? 'OK' : 'NOK',
      ),
      _ActionMetricData(
        icon: Icons.event_outlined,
        label: 'Deadline',
        value: _formatDate(_item.action.dueDate),
      ),
      _ActionMetricData(
        icon: Icons.schedule_outlined,
        label: 'Timing',
        value: _deadlineStatusLabel(),
      ),
      _ActionMetricData(
        icon: Icons.person_outline,
        label: 'Verantwoordelijke',
        value: _item.action.assigneeLabel,
      ),
      _ActionMetricData(
        icon: Icons.confirmation_number_outlined,
        label: 'Ticket',
        value: '#${_item.ticket.id}',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E9DD)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return Row(
              children: metrics.map<Widget>((metric) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _ActionMetric(data: metric),
                  ),
                );
              }).toList(),
            );
          }

          final itemWidth = constraints.maxWidth >= 560
              ? (constraints.maxWidth - 14) / 2
              : constraints.maxWidth;

          return Wrap(
            spacing: 14,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...metrics.map(
                (metric) => SizedBox(
                  width: itemWidth,
                  child: _ActionMetric(data: metric),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResponsiveContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1040) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildActionPanel(),
                    const SizedBox(height: 16),
                    _buildResponsibilityPanel(),
                    const SizedBox(height: 16),
                    _buildMetaPanel(),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(width: 460, child: _buildTicketContextPanel()),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPrimaryColumn(),
            const SizedBox(height: 16),
            _buildSideColumn(),
          ],
        );
      },
    );
  }

  Widget _buildPrimaryColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildActionPanel(),
        const SizedBox(height: 14),
        _buildResponsibilityPanel(),
        const SizedBox(height: 14),
        _buildMetaPanel(),
      ],
    );
  }

  Widget _buildActionPanel() {
    return _SectionPanel(
      title: 'Actie',
      icon: Icons.assignment_turned_in_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _display(_item.action.description),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF243022),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsibilityPanel() {
    return _SectionPanel(
      title: 'Verantwoordelijkheid',
      icon: Icons.person_pin_circle_outlined,
      child: _InfoGrid(
        minItemWidth: 180,
        fields: [
          _InfoField(
            label: 'Verantwoordelijke',
            value: _item.action.assigneeLabel,
          ),
          _InfoField(
            label: 'Toewijzing',
            value: _assigneeTypeLabel(_item.action.assigneeType),
          ),
          _InfoField(label: 'Contact', value: _contactLabel(_item.action)),
        ],
      ),
    );
  }

  Widget _buildSideColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildTicketContextPanel()],
    );
  }

  Widget _buildTicketContextPanel() {
    final ticket = _ticket;
    final branchLabel = ticket?.branchLabel ?? _item.ticket.branchLabel;
    final departmentLabel =
        ticket?.departmentLabel ?? _item.ticket.departmentLabel;
    final findingDate = ticket?.findingDate ?? _item.ticket.findingDate;

    return _SectionPanel(
      title: 'Gekoppeld ticket',
      icon: Icons.description_outlined,
      trailing: TextButton.icon(
        onPressed: _openTicketDetail,
        icon: const Icon(Icons.open_in_new_rounded, size: 16),
        label: const Text('Openen'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoadingTicket) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 14),
          ],
          if (_ticketError != null) ...[
            _InlineError(message: _ticketError!, onRetry: _loadTicket),
            const SizedBox(height: 14),
          ],
          _InfoGrid(
            minItemWidth: 150,
            fields: [
              _InfoField(label: 'Ticketnummer', value: '#${_item.ticket.id}'),
              _InfoField(
                label: 'Status ticket',
                value: ticket?.statusLabel ?? _item.ticket.statusLabel,
              ),
              _InfoField(
                label: 'OVA-type',
                value: _display(ticket?.ovaType ?? _item.ticket.ovaType),
              ),
              _InfoField(
                label: 'Datum vaststelling',
                value: findingDate == null ? '-' : _formatDate(findingDate),
              ),
              _InfoField(label: 'Vestiging', value: _display(branchLabel)),
              _InfoField(label: 'Afdeling', value: _display(departmentLabel)),
              if (ticket != null)
                _InfoField(
                  label: 'Aanleiding',
                  value: _reasonsLabel(ticket),
                  wide: true,
                ),
              if (ticket != null)
                _InfoField(
                  label: 'Incident',
                  value: _display(ticket.incidentDescription),
                  wide: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaPanel() {
    return _SectionPanel(
      title: 'Historiek',
      icon: Icons.history_outlined,
      child: _InfoGrid(
        minItemWidth: 150,
        fields: [
          _InfoField(
            label: 'Aangemaakt op',
            value: _formatDateTime(_item.action.createdAt),
          ),
          _InfoField(
            label: 'Laatst bewerkt',
            value: _formatDateTime(_item.action.updatedAt),
          ),
          if (_ticket != null)
            _InfoField(
              label: 'Ticket opvolging',
              value: _ticketActionProgressLabel(_ticket!),
            ),
        ],
      ),
    );
  }

  String _deadlineStatusLabel() {
    if (_item.action.isOk) {
      return 'Afgerond';
    }

    final today = _todayStart();
    final dueDate = _dateOnly(_item.action.dueDate);
    final days = dueDate.difference(today).inDays;

    if (days < 0) {
      final overdueDays = days.abs();
      return overdueDays == 1 ? '1 dag te laat' : '$overdueDays dagen te laat';
    }
    if (days == 0) {
      return 'Vandaag deadline';
    }
    if (days == 1) {
      return 'Morgen deadline';
    }
    return 'Nog $days dagen';
  }

  String _assigneeTypeLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'external':
        return 'Externe persoon';
      case 'internal':
      default:
        return 'Interne gebruiker';
    }
  }

  String _contactLabel(OvaFollowUpAction action) {
    if (action.assigneeType.trim().toLowerCase() == 'external') {
      final email = action.externalResponsible?.email?.trim();
      return email == null || email.isEmpty ? '-' : email;
    }

    return action.internalAssignee?.email.trim().isNotEmpty == true
        ? action.internalAssignee!.email
        : '-';
  }

  String _reasonsLabel(OvaTicket ticket) {
    final values = <String>[
      ...ticket.reasons
          .map((reason) => reason.trim())
          .where((reason) => reason.isNotEmpty),
      if (_display(ticket.otherReason) != '-')
        'Andere: ${_display(ticket.otherReason)}',
    ];

    return values.isEmpty ? '-' : values.join(', ');
  }

  String _ticketActionProgressLabel(OvaTicket ticket) {
    if (ticket.actions.isEmpty) {
      return 'Geen acties';
    }

    final done = ticket.actions.where((action) => action.isOk).length;
    return '$done/${ticket.actions.length} acties OK';
  }

  DateTime _todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    return '$day/$month/$year';
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${_formatDate(local)} $hour:$minute';
  }

  String _display(String? value, {String fallback = '-'}) {
    final normalized = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized == null || normalized.isEmpty) {
      return fallback;
    }
    return normalized;
  }
}
