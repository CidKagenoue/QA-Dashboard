import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ova_assigned_action.dart';
import '../models/ova_ticket.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/design/app_breadcrumb.dart';
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
  final GlobalKey _primaryColumnKey = GlobalKey();
  double? _widePrimaryColumnHeight;
  static const double _headerActionWidth = 154;
  static const double _headerActionHeight = 44;

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
                backgroundColor: kDanger,
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
        backgroundColor: kBackground,
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
                      ? const EdgeInsets.all(22)
                      : const EdgeInsets.fromLTRB(32, 28, 32, 32),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(
                      compact ? kRadiusLg : kRadius2xl,
                    ),
                    border: Border.all(color: kBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Breadcrumb(
                        segments: ['Dashboard', 'OVA', 'Acties'],
                      ),
                      const SizedBox(height: 16),
                      _buildHeader(),
                      const SizedBox(height: 22),
                      _buildSummaryStrip(),
                      const SizedBox(height: 20),
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _BackButton(onTap: _close),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Opvolgactie',
                        style: TextStyle(
                          fontSize: 13,
                          color: kTextTertiary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusPill(isOk: _item.action.isOk),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '#${_item.action.id.toString().padLeft(4, '0')}',
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

        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: compact ? WrapAlignment.start : WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: _headerActionWidth,
              height: _headerActionHeight,
              child: _ActionStatusMenuButton(
                isOk: _item.action.isOk,
                isSaving: _isSaving,
                onChanged: _updateStatus,
              ),
            ),
            SizedBox(
              width: _headerActionWidth,
              height: _headerActionHeight,
              child: ElevatedButton(
                onPressed: _isDeleting ? null : _openEditWizard,
                style: ElevatedButton.styleFrom(
                  fixedSize: const Size(
                    _headerActionWidth,
                    _headerActionHeight,
                  ),
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.center,
                ),
                child: const _CenteredButtonContent(
                  icon: Icons.edit_outlined,
                  label: 'Bewerken',
                ),
              ),
            ),
            SizedBox(
              width: _headerActionWidth,
              height: _headerActionHeight,
              child: OutlinedButton(
                onPressed: _isDeleting || _isSaving ? null : _deleteAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: kDanger,
                  side: const BorderSide(color: kDangerBorder),
                  fixedSize: const Size(
                    _headerActionWidth,
                    _headerActionHeight,
                  ),
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.center,
                ),
                child: _isDeleting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kDanger,
                        ),
                      )
                    : const _CenteredButtonContent(
                        icon: Icons.delete_outline_rounded,
                        label: 'Verwijderen',
                      ),
              ),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 18), actions],
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
        icon: Icons.event_rounded,
        label: 'Deadline',
        value: _formatDate(_item.action.dueDate),
      ),
      _ActionMetricData(
        icon: Icons.schedule_rounded,
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
        value: _formatNumber(_item.ticket.id),
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
          if (constraints.maxWidth >= 900) {
            final widgets = <Widget>[];
            for (var i = 0; i < metrics.length; i++) {
              widgets.add(Expanded(child: _ActionMetric(data: metrics[i])));
              if (i != metrics.length - 1) {
                widgets.add(
                  const SizedBox(
                    height: 36,
                    child: VerticalDivider(width: 24, color: kBorderSubtle),
                  ),
                );
              }
            }
            return Row(children: widgets);
          }

          final itemWidth = constraints.maxWidth >= 560
              ? (constraints.maxWidth - 16) / 2
              : constraints.maxWidth;

          return Wrap(
            spacing: 16,
            runSpacing: 16,
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
          _schedulePrimaryColumnHeightMeasure();

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: KeyedSubtree(
                  key: _primaryColumnKey,
                  child: _buildPrimaryColumn(),
                ),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 460,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: _widePrimaryColumnHeight ?? 0,
                  ),
                  child: _buildTicketContextPanel(),
                ),
              ),
            ],
          );
        }

        if (_widePrimaryColumnHeight != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _widePrimaryColumnHeight = null);
            }
          });
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

  void _schedulePrimaryColumnHeightMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final renderBox =
          _primaryColumnKey.currentContext?.findRenderObject() as RenderBox?;
      final height = renderBox?.size.height;
      if (height == null || height <= 0) {
        return;
      }

      final current = _widePrimaryColumnHeight;
      if (current != null && (current - height).abs() < 0.5) {
        return;
      }

      setState(() {
        _widePrimaryColumnHeight = height;
      });
    });
  }

  Widget _buildPrimaryColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildActionPanel(),
        const SizedBox(height: 16),
        _buildResponsibilityPanel(),
        const SizedBox(height: 16),
        _buildMetaPanel(),
      ],
    );
  }

  Widget _buildActionPanel() {
    return _SectionPanel(
      title: 'Beschrijving',
      icon: Icons.assignment_turned_in_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _display(_item.action.description),
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              height: 1.5,
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
              _InfoField(
                label: 'Ticketnummer',
                value: _formatNumber(_item.ticket.id),
              ),
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
      icon: Icons.history_rounded,
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

  String _formatNumber(int value) {
    return '#${value.toString().padLeft(4, '0')}';
  }

  String _display(String? value, {String fallback = '-'}) {
    final normalized = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized == null || normalized.isEmpty) {
      return fallback;
    }
    return normalized;
  }
}
