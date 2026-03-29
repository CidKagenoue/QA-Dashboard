import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ova_ticket.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'ova_follow_up_action_components.dart';

const List<String> kOvaTicketStepLabels = [
  'Basisinformatie',
  'Aanleiding',
  'Vaststelling',
  'Oorzakenanalyse',
  'Opvolgacties',
  'Effectiviteitscontrole',
  'Afsluiting',
];

const List<String> _kOvaTypeOptions = ['Near Miss', 'OVA 1', 'OVA 2', 'OVA 3'];

const List<String> _kReasonOptions = [
  'Klachten en externe incidenten',
  'Interne afwijking, incidenten en accidenten',
  'Doelstelling of rapport',
  'Verbetervoorstel',
  'Directiebeoordeling',
  'Interne en externe audit',
  'Leiderschap',
  'Risico en kans',
];

const List<String> _kCauseMethodOptions = ['5 Why', 'Fishbone', 'Andere'];

String formatOvaDate(DateTime value) {
  final localValue = value.toLocal();
  final day = localValue.day.toString().padLeft(2, '0');
  final month = localValue.month.toString().padLeft(2, '0');
  final year = localValue.year.toString();
  return '$day/$month/$year';
}

String formatOvaDateTime(DateTime value) {
  final localValue = value.toLocal();
  final day = localValue.day.toString().padLeft(2, '0');
  final month = localValue.month.toString().padLeft(2, '0');
  final year = localValue.year.toString();
  final hour = localValue.hour.toString().padLeft(2, '0');
  final minute = localValue.minute.toString().padLeft(2, '0');
  return '$day/$month/$year - $hour:$minute';
}

class OvaTicketWizardScreen extends StatefulWidget {
  const OvaTicketWizardScreen({super.key, this.ticketId});

  final int? ticketId;

  @override
  State<OvaTicketWizardScreen> createState() => _OvaTicketWizardScreenState();
}

class _OvaTicketWizardScreenState extends State<OvaTicketWizardScreen> {
  final TextEditingController _otherReasonController = TextEditingController();
  final TextEditingController _incidentController = TextEditingController();
  final TextEditingController _causeNotesController = TextEditingController();
  final TextEditingController _effectivenessNotesController =
      TextEditingController();

  DateTime _findingDate = DateTime.now();
  DateTime _effectivenessDate = DateTime.now();
  String? _ovaType;
  Set<String> _selectedReasons = <String>{};
  String? _causeMethod;
  List<EditableOvaFollowUpAction> _actions = const [];
  List<OvaTicketUser> _assignableUsers = const [];

  bool _isLoading = false;
  bool _isSaving = false;
  bool _didPersistChanges = false;
  String? _error;
  int _currentStep = 0;
  OvaTicket? _ticket;

  @override
  void initState() {
    super.initState();
    if (widget.ticketId != null) {
      _loadTicket();
    }
    _loadAssignableUsers();
  }

  @override
  void dispose() {
    _otherReasonController.dispose();
    _incidentController.dispose();
    _causeNotesController.dispose();
    _effectivenessNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadTicket() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await context.read<AuthService>().getValidAccessToken();
      final response = await ApiService.fetchOvaTicket(
        token: token,
        ticketId: widget.ticketId!,
      );
      final ticket = OvaTicket.fromJson(response);
      if (!mounted) {
        return;
      }

      setState(() {
        _applyTicket(ticket);
        _didPersistChanges = true;
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

  Future<void> _loadAssignableUsers() async {
    try {
      final token = await context.read<AuthService>().getValidAccessToken();
      final response = await ApiService.fetchOvaAssignableUsers(token: token);
      if (!mounted) {
        return;
      }

      setState(() {
        _assignableUsers = response
            .map(OvaTicketUser.fromJson)
            .where((user) => user.id > 0)
            .toList();
      });
    } catch (_) {
      // A targeted message is shown when the action dialog needs this data.
    }
  }

  void _applyTicket(OvaTicket ticket) {
    _ticket = ticket;
    _findingDate = ticket.findingDate ?? _findingDate;
    _effectivenessDate = ticket.effectivenessDate ?? _effectivenessDate;
    _ovaType = ticket.ovaType;
    _selectedReasons = ticket.reasons.toSet();
    _otherReasonController.text = ticket.otherReason ?? '';
    _incidentController.text = ticket.incidentDescription ?? '';
    _causeMethod = ticket.causeAnalysisMethod;
    _causeNotesController.text = ticket.causeAnalysisNotes ?? '';
    _effectivenessNotesController.text = ticket.effectivenessNotes ?? '';
    _actions = ticket.actions
        .map(EditableOvaFollowUpAction.fromAction)
        .toList();
    _currentStep = ticket.isClosed
        ? 0
        : (ticket.currentStep - 1).clamp(0, 6).toInt();
  }

  Future<void> _pickFindingDate() async {
    final currentValue = _findingDate;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentValue,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentValue),
    );

    if (pickedTime == null || !mounted) {
      return;
    }

    setState(() {
      _findingDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _pickEffectivenessDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _effectivenessDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _effectivenessDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      );
    });
  }

  Future<void> _saveDraft() async {
    await _persistTicket();
  }

  Future<void> _goToNextStep() async {
    if (!_validateCurrentStep()) {
      return;
    }

    if (_currentStep == 4 && _actions.any((action) => !action.isOk)) {
      final shouldContinue = await _showProceedWithOpenActionsDialog();
      if (shouldContinue != true || !mounted) {
        return;
      }
    }

    await _persistTicket(advance: true);
  }

  Future<void> _finishTicket() async {
    await _persistTicket(complete: true, successMessage: 'Ticket afgesloten.');
  }

  Future<void> _persistTicket({
    bool advance = false,
    bool complete = false,
    bool silent = false,
    String? successMessage,
  }) async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final token = await context.read<AuthService>().getValidAccessToken();
      final payload = _buildPayload(advance: advance, complete: complete);

      final response = _ticket == null
          ? await ApiService.createOvaTicket(token: token, payload: payload)
          : await ApiService.updateOvaTicket(
              token: token,
              ticketId: _ticket!.id,
              payload: payload,
            );

      final ticket = OvaTicket.fromJson(response);
      if (!mounted) {
        return;
      }

      setState(() {
        _applyTicket(ticket);
      });

      final message =
          successMessage ??
          (advance
              ? 'Stap opgeslagen. Je kunt verder naar ${kOvaTicketStepLabels[_currentStep]}.'
              : 'Draft opgeslagen.');

      if (!silent || successMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
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
          _isSaving = false;
        });
      }
    }
  }

  Map<String, dynamic> _buildPayload({
    required bool advance,
    required bool complete,
  }) {
    final payload = <String, dynamic>{
      'currentStep': complete
          ? 7
          : advance
          ? (_currentStep + 2).clamp(1, 7)
          : _recordedStepForSave(),
    };

    if (_currentStep >= 4 || _actions.isNotEmpty) {
      payload['actions'] = _actions.map((action) => action.toJson()).toList();
    }

    switch (_currentStep) {
      case 0:
        payload['findingDate'] = _findingDate.toUtc().toIso8601String();
        payload['ovaType'] = _normalizedText(_ovaType);
        break;
      case 1:
        payload['reasons'] = _selectedReasons.toList()..sort();
        payload['otherReason'] = _normalizedText(_otherReasonController.text);
        break;
      case 2:
        payload['incidentDescription'] = _normalizedText(
          _incidentController.text,
        );
        break;
      case 3:
        payload['causeAnalysisMethod'] = _normalizedText(_causeMethod);
        payload['causeAnalysisNotes'] = _normalizedText(
          _causeNotesController.text,
        );
        break;
      case 4:
        break;
      case 5:
        payload['effectivenessDate'] = DateTime.utc(
          _effectivenessDate.year,
          _effectivenessDate.month,
          _effectivenessDate.day,
        ).toIso8601String();
        payload['effectivenessNotes'] = _normalizedText(
          _effectivenessNotesController.text,
        );
        break;
    }

    if (complete) {
      payload['status'] = 'closed';
    }

    return payload;
  }

  int _recordedStepForSave() {
    final minimumStep = _currentStep + 1;
    final storedStep = _ticket?.currentStep ?? 1;
    return storedStep > minimumStep ? storedStep : minimumStep;
  }

  String? _normalizedText(String? value) {
    final normalizedValue = value?.trim();
    return normalizedValue == null || normalizedValue.isEmpty
        ? null
        : normalizedValue;
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return true;
      case 1:
        final hasReasons = _selectedReasons.isNotEmpty;
        final hasOtherReason =
            (_normalizedText(_otherReasonController.text) ?? '').isNotEmpty;
        if (hasReasons || hasOtherReason) {
          return true;
        }
        _showValidationMessage('Selecteer minstens een aanleiding.');
        return false;
      case 2:
        if ((_normalizedText(_incidentController.text) ?? '').isNotEmpty) {
          return true;
        }
        _showValidationMessage('Omschrijf eerst de vaststelling.');
        return false;
      case 3:
        if ((_normalizedText(_causeMethod) ?? '').isNotEmpty) {
          return true;
        }
        _showValidationMessage('Selecteer een analysemethode.');
        return false;
      case 4:
        if (_actions.isNotEmpty) {
          return true;
        }
        _showValidationMessage('Voeg minstens een opvolgactie toe.');
        return false;
      case 5:
        if ((_normalizedText(_effectivenessNotesController.text) ?? '')
            .isNotEmpty) {
          return true;
        }
        _showValidationMessage(
          'Geef een toelichting bij de effectiviteitscontrole.',
        );
        return false;
      default:
        return true;
    }
  }

  void _showValidationMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _resultSectionForExit() {
    if (!_didPersistChanges) {
      return null;
    }

    final normalizedStatus = _ticket?.status.trim().toLowerCase();
    if (normalizedStatus == 'closed' || normalizedStatus == 'completed') {
      return 'closed';
    }
    if (normalizedStatus == 'open') {
      return 'open';
    }

    return 'incomplete';
  }

  void _closeWizard() {
    Navigator.of(context).pop(_resultSectionForExit());
  }

  Future<bool?> _showProceedWithOpenActionsDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Niet alle opvolgacties zijn afgerond'),
          content: const Text(
            'Niet alle opvolgacties zijn afgerond. Weet u zeker dat u wilt doorgaan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuleren'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Doorgaan'),
            ),
          ],
        );
      },
    );
  }

  Future<List<OvaExternalResponsible>> _loadExternalSuggestions(
    String query,
  ) async {
    final token = await context.read<AuthService>().getValidAccessToken();
    final response = await ApiService.fetchOvaExternalContacts(
      token: token,
      query: query,
    );

    return response
        .map(OvaExternalResponsible.fromJson)
        .where((contact) => contact.id > 0)
        .toList();
  }

  Future<void> _openActionDialog({
    EditableOvaFollowUpAction? initialAction,
    required String type,
  }) async {
    if (_assignableUsers.isEmpty) {
      await _loadAssignableUsers();
    }

    if (!mounted) {
      return;
    }

    if (_assignableUsers.isEmpty) {
      _showValidationMessage(
        'Interne gebruikers konden niet geladen worden. Probeer het opnieuw.',
      );
      return;
    }

    final editedAction = await showDialog<EditableOvaFollowUpAction>(
      context: context,
      builder: (context) {
        return OvaFollowUpActionEditorDialog(
          defaultType: type,
          initialAction: initialAction,
          assignableUsers: _assignableUsers,
          loadExternalSuggestions: _loadExternalSuggestions,
        );
      },
    );

    if (editedAction == null || !mounted) {
      return;
    }

    final updatedActions = [..._actions];
    final existingIndex = updatedActions.indexWhere(
      (action) => action.matches(initialAction),
    );

    if (existingIndex >= 0) {
      updatedActions[existingIndex] = editedAction;
    } else {
      updatedActions.add(editedAction);
    }

    setState(() {
      _actions = updatedActions;
    });

    await _persistTicket(
      silent: true,
      successMessage: initialAction == null
          ? 'Opvolgactie opgeslagen.'
          : 'Opvolgactie bijgewerkt.',
    );
  }

  Future<void> _deleteAction(EditableOvaFollowUpAction action) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Opvolgactie verwijderen'),
          content: const Text(
            'Weet je zeker dat je deze opvolgactie wilt verwijderen?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuleren'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Verwijderen'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _actions = _actions.where((item) => !item.matches(action)).toList();
    });

    await _persistTicket(
      silent: true,
      successMessage: 'Opvolgactie verwijderd.',
    );
  }

  Future<void> _updateActionStatus(
    EditableOvaFollowUpAction action,
    bool isOk,
  ) async {
    setState(() {
      _actions = _actions
          .map(
            (item) => item.matches(action)
                ? item.copyWith(status: isOk ? 'ok' : 'nok')
                : item,
          )
          .toList();
    });

    await _persistTicket(silent: true);
  }

  void _jumpToStep(int index) {
    if (_ticket?.isClosed == true) {
      setState(() {
        _currentStep = index;
      });
      return;
    }

    final accessibleStep = _currentStep > ((_ticket?.currentStep ?? 1) - 1)
        ? _currentStep
        : ((_ticket?.currentStep ?? 1) - 1);
    if (index > accessibleStep) {
      return;
    }

    setState(() {
      _currentStep = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _ticket == null
        ? 'Nieuw OVA-ticket'
        : 'OVA-ticket #${_ticket!.id}';
    final isClosed = _ticket?.isClosed ?? false;

    return PopScope<String?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _closeWizard();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F3),
        appBar: AppBar(
          backgroundColor: const Color(0xFF8CC63F),
          foregroundColor: Colors.white,
          title: Text(title),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _ticket == null && widget.ticketId != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _WizardErrorState(
                      message: _error!,
                      onRetry: _loadTicket,
                    ),
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isClosed) ...[
                          _ClosedTicketBanner(ticket: _ticket!),
                          const SizedBox(height: 24),
                        ],
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
                                'Stappenplan OVA-ticket',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'De flow volgt nu de volledige OVA-opbouw: oorzakenanalyse, concrete opvolgacties, effectiviteitscontrole en formele afsluiting.',
                              ),
                              const SizedBox(height: 24),
                              _WizardStepper(
                                currentStep: _currentStep,
                                storedStep:
                                    (_ticket?.currentStep ?? (_currentStep + 1)),
                                onTap: _jumpToStep,
                                locked: isClosed,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0D000000),
                                blurRadius: 18,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kOvaTicketStepLabels[_currentStep],
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _stepDescription(_currentStep),
                                style: const TextStyle(
                                  color: Color(0xFF5D6656),
                                  height: 1.45,
                                ),
                              ),
                              if (isClosed) ...[
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F8F4),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFE1E5D9),
                                    ),
                                  ),
                                  child: const Text(
                                    'Dit gesloten ticket staat in alleen-lezen modus. Gebruik de stappen bovenaan of Vorige/Volgende om alle details te bekijken.',
                                    style: TextStyle(
                                      color: Color(0xFF566051),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 28),
                              IgnorePointer(
                                ignoring: isClosed,
                                child: _buildCurrentStep(),
                              ),
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
                              const SizedBox(height: 28),
                              _buildActionBar(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildActionBar() {
    final isClosed = _ticket?.isClosed ?? false;

    if (isClosed) {
      return Row(
        children: [
          if (_currentStep > 0)
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _currentStep -= 1;
                });
              },
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Vorige'),
            ),
          const Spacer(),
          if (_currentStep < 6) ...[
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _currentStep += 1;
                });
              },
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Volgende'),
            ),
            const SizedBox(width: 12),
          ],
          ElevatedButton.icon(
            onPressed: _closeWizard,
            icon: const Icon(Icons.list_alt_rounded),
            label: const Text('Terug naar tickets'),
          ),
        ],
      );
    }

    return Row(
      children: [
        if (_currentStep > 0)
          OutlinedButton.icon(
            onPressed: _isSaving
                ? null
                : () {
                    setState(() {
                      _currentStep -= 1;
                    });
                  },
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Vorige'),
          ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _isSaving ? null : _saveDraft,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Opslaan'),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _isSaving
              ? null
              : _currentStep == 6
              ? _finishTicket
              : _goToNextStep,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  _currentStep == 6
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                ),
          label: Text(_currentStep == 6 ? 'Ticket afsluiten' : 'Volgende'),
        ),
      ],
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildBasicInformationStep();
      case 1:
        return _buildReasonStep();
      case 2:
        return _buildIncidentStep();
      case 3:
        return _buildCauseAnalysisStep();
      case 4:
        return _buildFollowUpActionsStep();
      case 5:
        return _buildEffectivenessStep();
      case 6:
        return _buildClosureStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBasicInformationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'Datum vaststelling',
          subtitle:
              'De datum is standaard ingevuld. Je kunt ze aanpassen wanneer nodig.',
          child: Row(
            children: [
              Expanded(
                child: Text(
                  formatOvaDateTime(_findingDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2B3424),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pickFindingDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Aanpassen'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Type OVA',
          subtitle:
              'Dit veld is optioneel. Als de gebruiker het type nog niet weet, kan het ticket toch opgeslagen worden.',
          child: DropdownButtonFormField<String?>(
            initialValue: _ovaType,
            decoration: const InputDecoration(labelText: 'Type OVA'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Nog niet gekend'),
              ),
              ..._kOvaTypeOptions.map(
                (type) =>
                    DropdownMenuItem<String?>(value: type, child: Text(type)),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _ovaType = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReasonStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _kReasonOptions.map((option) {
            final isSelected = _selectedReasons.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedReasons.add(option);
                  } else {
                    _selectedReasons.remove(option);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _otherReasonController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Andere aanleiding',
            hintText: 'Vul hier extra context of een andere aanleiding in',
          ),
        ),
      ],
    );
  }

  Widget _buildIncidentStep() {
    return TextField(
      controller: _incidentController,
      minLines: 8,
      maxLines: 10,
      decoration: const InputDecoration(
        labelText: 'Omschrijving incident',
        alignLabelWithHint: true,
        hintText: 'Beschrijf wat er precies is vastgesteld...',
      ),
    );
  }

  Widget _buildCauseAnalysisStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'Analysemethode',
          subtitle:
              'Kies de methode waarmee de onderliggende oorzaak onderzocht werd.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _kCauseMethodOptions.map((method) {
              final isSelected = _causeMethod == method;
              return ChoiceChip(
                label: Text(method),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _causeMethod = method;
                  });
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _causeNotesController,
          minLines: 6,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Toelichting analyse',
            alignLabelWithHint: true,
            hintText:
                'Beschrijf de uitkomst van de analyse of geef bijkomende duiding.',
          ),
        ),
      ],
    );
  }

  Widget _buildFollowUpActionsStep() {
    final correctiveActions = _actions
        .where((action) => action.type == 'corrective')
        .toList();
    final preventiveActions = _actions
        .where((action) => action.type == 'preventive')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActionSection(
          title: 'Corrigerende acties',
          subtitle: 'Acties om de vastgestelde afwijking direct aan te pakken.',
          actions: correctiveActions,
          onAdd: () => _openActionDialog(type: 'corrective'),
          onEdit: (action) =>
              _openActionDialog(initialAction: action, type: action.type),
          onDelete: _deleteAction,
          onStatusChanged: _updateActionStatus,
        ),
        const SizedBox(height: 20),
        _ActionSection(
          title: 'Preventieve acties',
          subtitle:
              'Acties om herhaling te vermijden of het proces structureel te verbeteren.',
          actions: preventiveActions,
          onAdd: () => _openActionDialog(type: 'preventive'),
          onEdit: (action) =>
              _openActionDialog(initialAction: action, type: action.type),
          onDelete: _deleteAction,
          onStatusChanged: _updateActionStatus,
        ),
        if (_actions.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCE6C7)),
            ),
            child: Text(
              _actions.any((action) => !action.isOk)
                  ? 'Niet alle opvolgacties staan op OK. Bij doorgaan tonen we eerst een waarschuwing.'
                  : 'Alle opvolgacties staan op OK. Je kunt zonder waarschuwing verder naar de effectiviteitscontrole.',
              style: const TextStyle(color: Color(0xFF53604A), height: 1.4),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEffectivenessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'Datum controle',
          subtitle:
              'Deze datum staat standaard op vandaag en registreert wanneer de effectiviteit beoordeeld werd.',
          child: Row(
            children: [
              Expanded(
                child: Text(
                  formatOvaDate(_effectivenessDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2B3424),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pickEffectivenessDate,
                icon: const Icon(Icons.event_outlined),
                label: const Text('Aanpassen'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _effectivenessNotesController,
          minLines: 6,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Toelichting',
            alignLabelWithHint: true,
            hintText:
                'Beschrijf waarom de opvolgacties al dan niet voldoende effect hebben gehad.',
          ),
        ),
      ],
    );
  }

  Widget _buildClosureStep() {
    final ticket = _ticket;
    if (ticket != null && ticket.isClosed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF5FAEC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD5E4B4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_rounded, color: Color(0xFF6B8F2A)),
                SizedBox(width: 10),
                Text(
                  'Ticket gesloten',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2B3424),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Ticket gesloten op ${ticket.closedAt == null ? '-' : formatOvaDateTime(ticket.closedAt!)} door ${ticket.closedBy?.displayName ?? 'onbekend'}.',
              style: const TextStyle(color: Color(0xFF4C5845), height: 1.45),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE6C7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Klaar voor afsluiting',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2B3424),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Bij afsluiten registreren we automatisch de afsluitdatum en de gebruiker die dit ticket formeel afrondt.',
            style: TextStyle(color: Color(0xFF4C5845), height: 1.45),
          ),
          const SizedBox(height: 18),
          _SummaryRow(
            label: 'Effectiviteitscontrole',
            value: formatOvaDate(_effectivenessDate),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Aantal opvolgacties',
            value: _actions.length.toString(),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Status acties',
            value: _actions.any((action) => !action.isOk)
                ? 'Niet alles OK'
                : 'Alles OK',
          ),
        ],
      ),
    );
  }

  String _stepDescription(int index) {
    switch (index) {
      case 0:
        return 'Leg de basis vast. Type OVA is bewust niet verplicht, zodat het ticket meteen als draft kan worden opgeslagen.';
      case 1:
        return 'Selecteer een of meerdere aanleidingen of geef een vrije omschrijving mee.';
      case 2:
        return 'Beschrijf de vaststelling. Zodra deze eerste drie stappen opgeslagen zijn, kan iemand anders later verderwerken.';
      case 3:
        return 'Kies een analysemethode en leg de oorzakenanalyse vast.';
      case 4:
        return 'Maak corrigerende en preventieve opvolgacties aan, wijs ze toe en volg hun status op.';
      case 5:
        return 'Documenteer de effectiviteitscontrole. Een toelichting is hier verplicht.';
      case 6:
        return 'Sluit het ticket formeel af. De afsluitdatum en afsluitende gebruiker worden automatisch geregistreerd.';
      default:
        return '';
    }
  }
}

class _ActionSection extends StatelessWidget {
  const _ActionSection({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
  });

  final String title;
  final String subtitle;
  final List<EditableOvaFollowUpAction> actions;
  final VoidCallback onAdd;
  final ValueChanged<EditableOvaFollowUpAction> onEdit;
  final ValueChanged<EditableOvaFollowUpAction> onDelete;
  final Future<void> Function(EditableOvaFollowUpAction action, bool isOk)
  onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Opvolgactie aanmaken'),
            ),
          ),
          const SizedBox(height: 16),
          if (actions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDCE6C7)),
              ),
              child: const Text(
                'Nog geen acties toegevoegd in deze sectie.',
                style: TextStyle(color: Color(0xFF5D6656)),
              ),
            )
          else
            Column(
              children: actions
                  .map(
                    (action) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ActionCard(
                        action: action,
                        onEdit: () => onEdit(action),
                        onDelete: () => onDelete(action),
                        onStatusChanged: (isOk) =>
                            onStatusChanged(action, isOk),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
  });

  final EditableOvaFollowUpAction action;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6C7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  action.description,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2B3424),
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Bewerken',
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Verwijderen',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Verantwoordelijke', value: action.assigneeLabel),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Deadline',
            value: formatOvaActionDate(action.dueDate),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ChoiceChip(
                label: const Text('NOK'),
                selected: !action.isOk,
                onSelected: (_) => onStatusChanged(false),
              ),
              ChoiceChip(
                label: const Text('OK'),
                selected: action.isOk,
                onSelected: (_) => onStatusChanged(true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClosedTicketBanner extends StatelessWidget {
  const _ClosedTicketBanner({required this.ticket});

  final OvaTicket ticket;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAEC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD5E4B4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_clock_outlined, color: Color(0xFF6B8F2A)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Dit ticket is afgesloten op ${ticket.closedAt == null ? '-' : formatOvaDateTime(ticket.closedAt!)} door ${ticket.closedBy?.displayName ?? 'onbekend'}. Alle stappen blijven hieronder raadpleegbaar in alleen-lezen modus.',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 180,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF5D6656),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2B3424),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _WizardStepper extends StatelessWidget {
  const _WizardStepper({
    required this.currentStep,
    required this.storedStep,
    required this.onTap,
    required this.locked,
  });

  final int currentStep;
  final int storedStep;
  final ValueChanged<int> onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final accessibleStep = currentStep > (storedStep - 1)
        ? currentStep
        : (storedStep - 1);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(kOvaTicketStepLabels.length, (index) {
          final isCompleted = index < storedStep - 1;
          final isCurrent = index == currentStep;
          final isReachable = locked || index <= accessibleStep;
          final circleColor = isCurrent || isCompleted
              ? const Color(0xFF8CC63F)
              : Colors.white;
          final borderColor = isReachable
              ? const Color(0xFF8CC63F)
              : const Color(0xFFD4D8CF);

          return Padding(
            padding: EdgeInsets.only(right: index == 6 ? 0 : 18),
            child: InkWell(
              onTap: isReachable ? () => onTap(index) : null,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  children: [
                    SizedBox(
                      width: 112,
                      child: Text(
                        kOvaTicketStepLabels[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isReachable
                              ? const Color(0xFF2B3424)
                              : const Color(0xFF98A095),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: circleColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor, width: 2),
                      ),
                      child: isCompleted
                          ? const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE6C7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2B3424),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF5D6656), height: 1.45),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _WizardErrorState extends StatelessWidget {
  const _WizardErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 42,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Opnieuw laden'),
          ),
        ],
      ),
    );
  }
}
