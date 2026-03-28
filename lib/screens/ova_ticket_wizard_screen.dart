import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ova_ticket.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

const List<String> kOvaTicketStepLabels = [
  'Basisinformatie',
  'Aanleiding & Identificatie',
  'Vaststelling',
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

  DateTime _findingDate = DateTime.now();
  String? _ovaType;
  Set<String> _selectedReasons = <String>{};

  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasChanges = false;
  String? _error;
  int _currentStep = 0;
  OvaTicket? _ticket;

  @override
  void initState() {
    super.initState();
    if (widget.ticketId != null) {
      _loadTicket();
    }
  }

  @override
  void dispose() {
    _otherReasonController.dispose();
    _incidentController.dispose();
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

  void _applyTicket(OvaTicket ticket) {
    _ticket = ticket;
    _findingDate = ticket.findingDate ?? _findingDate;
    _ovaType = ticket.ovaType;
    _selectedReasons = ticket.reasons.toSet();
    _otherReasonController.text = ticket.otherReason ?? '';
    _incidentController.text = ticket.incidentDescription ?? '';
    _currentStep = (ticket.currentStep - 1).clamp(0, 2).toInt();
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

  Future<void> _saveDraft() async {
    await _persistTicket();
  }

  Future<void> _goToNextStep() async {
    if (!_validateCurrentStep()) {
      return;
    }

    await _persistTicket(advance: _currentStep < 2);
  }

  Future<void> _persistTicket({
    bool advance = false,
    bool silent = false,
  }) async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final token = await context.read<AuthService>().getValidAccessToken();
      final payload = _buildPayload(advance: advance);

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
        _hasChanges = true;
      });

      if (!silent) {
        final message = advance && _currentStep < 2
            ? 'Stap opgeslagen. Je kunt verder naar ${kOvaTicketStepLabels[_currentStep]}.'
            : 'Ticket opgeslagen.';
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

  Map<String, dynamic> _buildPayload({required bool advance}) {
    final payload = <String, dynamic>{
      'currentStep': advance
          ? (_currentStep + 2).clamp(1, 3)
          : _recordedStepForSave(),
    };

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
        _showValidationMessage(
          'Selecteer minstens een aanleiding of vul vrije tekst in.',
        );
        return false;
      case 2:
        if ((_normalizedText(_incidentController.text) ?? '').isNotEmpty) {
          return true;
        }
        _showValidationMessage('Omschrijf eerst de vaststelling.');
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

  void _jumpToStep(int index) {
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

  void _closeWizard() {
    Navigator.of(context).pop(_hasChanges);
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildReasonStep();
      case 2:
        return _buildFindingStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBasicInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'Datum en tijd van vaststelling',
          subtitle:
              'We registreren hier wanneer de afwijking of melding werd vastgesteld.',
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
                icon: const Icon(Icons.event_outlined),
                label: const Text('Aanpassen'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Type OVA',
          subtitle:
              'Het type is optioneel zodat je het ticket meteen als draft kunt bewaren.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _kOvaTypeOptions.map((option) {
              final isSelected = _ovaType == option;

              return ChoiceChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _ovaType = isSelected ? null : option;
                  });
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildReasonStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'Aanleiding & identificatie',
          subtitle:
              'Kies een of meerdere aanleidingen zodat meteen duidelijk is vanuit welke trigger dit ticket werd gestart.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _kReasonOptions.map((reason) {
              final isSelected = _selectedReasons.contains(reason);

              return FilterChip(
                label: Text(reason),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedReasons = {..._selectedReasons, reason};
                    } else {
                      _selectedReasons = _selectedReasons
                          .where((value) => value != reason)
                          .toSet();
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _otherReasonController,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Vrije toelichting',
            alignLabelWithHint: true,
            hintText:
                'Gebruik dit veld wanneer de aanleiding niet volledig door de opties hierboven gedekt wordt.',
          ),
        ),
      ],
    );
  }

  Widget _buildFindingStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'Vaststelling',
          subtitle:
              'Beschrijf helder wat er werd vastgesteld. Na deze stap kan het ticket als werkbare basis verder door iemand anders worden opgenomen.',
          child: TextField(
            controller: _incidentController,
            minLines: 8,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Omschrijving vaststelling',
              alignLabelWithHint: true,
              hintText:
                  'Beschrijf wat er precies werd vastgesteld, waar dit gebeurde en welke impact of context al gekend is.',
            ),
          ),
        ),
      ],
    );
  }

  String _stepDescription(int index) {
    switch (index) {
      case 0:
        return 'Leg de basis vast. Type OVA is niet verplicht zodat je snel een draft kunt starten.';
      case 1:
        return 'Selecteer een of meerdere aanleidingen of voeg een vrije identificatie toe.';
      case 2:
        return 'Beschrijf de vaststelling. Na deze drie stappen kan het ticket verder opgenomen worden.';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _ticket == null
        ? 'Nieuw OVA-ticket'
        : 'OVA-ticket #${_ticket!.id}';

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _closeWizard();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F3),
        appBar: AppBar(
          backgroundColor: const Color(0xFF8CC63F),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _closeWizard,
          ),
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
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                'Nieuw OVA Ticket Aanmaken',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Deze flow ondersteunt voorlopig de eerste drie stappen van het ticket. Je kunt tussentijds opslaan zodat later verder gewerkt kan worden.',
                              ),
                              const SizedBox(height: 24),
                              _WizardStepper(
                                currentStep: _currentStep,
                                storedStep:
                                    (_ticket?.currentStep ??
                                    (_currentStep + 1)),
                                onTap: _jumpToStep,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
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
                                kOvaTicketStepLabels[_currentStep],
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _stepDescription(_currentStep),
                                style: const TextStyle(
                                  color: Color(0xFF5D6656),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildCurrentStep(),
                              if (_error != null) ...[
                                const SizedBox(height: 18),
                                _InlineError(message: _error!),
                              ],
                              const SizedBox(height: 28),
                              Row(
                                children: [
                                  if (_currentStep > 0)
                                    OutlinedButton(
                                      onPressed: _isSaving
                                          ? null
                                          : () {
                                              setState(() {
                                                _currentStep -= 1;
                                              });
                                            },
                                      child: const Text('Vorige stap'),
                                    ),
                                  if (_currentStep > 0)
                                    const SizedBox(width: 12),
                                  OutlinedButton.icon(
                                    onPressed: _isSaving ? null : _saveDraft,
                                    icon: const Icon(Icons.save_outlined),
                                    label: const Text('Opslaan'),
                                  ),
                                  const Spacer(),
                                  ElevatedButton.icon(
                                    onPressed: _isSaving ? null : _goToNextStep,
                                    icon: _isSaving
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Icon(
                                            _currentStep < 2
                                                ? Icons.arrow_forward_rounded
                                                : Icons.check_rounded,
                                          ),
                                    label: Text(
                                      _currentStep < 2
                                          ? 'Opslaan en verder'
                                          : 'Stap opslaan',
                                    ),
                                  ),
                                ],
                              ),
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
}

class _WizardStepper extends StatelessWidget {
  const _WizardStepper({
    required this.currentStep,
    required this.storedStep,
    required this.onTap,
  });

  final int currentStep;
  final int storedStep;
  final ValueChanged<int> onTap;

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
          final isReachable = index <= accessibleStep;
          final circleColor = isCurrent || isCompleted
              ? const Color(0xFF8CC63F)
              : Colors.white;
          final borderColor = isReachable
              ? const Color(0xFF8CC63F)
              : const Color(0xFFD4D8CF);

          return Padding(
            padding: EdgeInsets.only(
              right: index == kOvaTicketStepLabels.length - 1 ? 0 : 18,
            ),
            child: InkWell(
              onTap: isReachable ? () => onTap(index) : null,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  children: [
                    SizedBox(
                      width: 148,
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6F6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1C9C9)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.w600,
        ),
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
