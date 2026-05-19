import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ova_ticket.dart';

String formatOvaActionDate(DateTime value) {
  final localValue = value.toLocal();
  final day = localValue.day.toString().padLeft(2, '0');
  final month = localValue.month.toString().padLeft(2, '0');
  final year = localValue.year.toString();
  return '$day/$month/$year';
}

String _requiredLabel(String label) => '$label *';

class EditableOvaFollowUpAction {
  const EditableOvaFollowUpAction({
    this.id,
    required this.type,
    required this.description,
    required this.dueDate,
    required this.status,
    required this.assigneeType,
    this.internalAssignee,
    this.externalResponsible,
  });

  final int? id;
  final String type;
  final String description;
  final DateTime dueDate;
  final String status;
  final String assigneeType;
  final OvaTicketUser? internalAssignee;
  final OvaExternalResponsible? externalResponsible;

  bool get isOk => status.trim().toLowerCase() == 'ok';

  String get assigneeLabel {
    if (assigneeType == 'internal') {
      return internalAssignee?.displayName ?? 'Interne gebruiker';
    }

    final external = externalResponsible;
    if (external == null) {
      return 'Externe persoon';
    }

    final email = external.email?.trim();
    if (email != null && email.isNotEmpty) {
      return '${external.displayName} ($email)';
    }

    return external.displayName;
  }

  EditableOvaFollowUpAction copyWith({
    int? id,
    String? type,
    String? description,
    DateTime? dueDate,
    String? status,
    String? assigneeType,
    OvaTicketUser? internalAssignee,
    OvaExternalResponsible? externalResponsible,
  }) {
    return EditableOvaFollowUpAction(
      id: id ?? this.id,
      type: type ?? this.type,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      assigneeType: assigneeType ?? this.assigneeType,
      internalAssignee: internalAssignee ?? this.internalAssignee,
      externalResponsible: externalResponsible ?? this.externalResponsible,
    );
  }

  bool matches(EditableOvaFollowUpAction? other) {
    if (other == null) {
      return false;
    }

    if (id != null && other.id != null) {
      return id == other.id;
    }

    return identical(this, other);
  }

  factory EditableOvaFollowUpAction.fromAction(OvaFollowUpAction action) {
    return EditableOvaFollowUpAction(
      id: action.id,
      type: action.type,
      description: action.description,
      dueDate: action.dueDate,
      status: action.status,
      assigneeType: action.assigneeType,
      internalAssignee: action.internalAssignee,
      externalResponsible: action.externalResponsible,
    );
  }

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      if (id != null) 'id': id,
      'type': type,
      'description': description.trim(),
      'dueDate': _dateOnlyToUtc(dueDate).toIso8601String(),
      'status': status,
      'assigneeType': assigneeType,
    };

    if (assigneeType == 'internal') {
      payload['internalAssigneeId'] = internalAssignee?.id;
    } else {
      final external = externalResponsible;
      payload['externalResponsible'] = {
        if (external != null && external.id > 0) 'id': external.id,
        'firstName': external?.firstName,
        'lastName': external?.lastName,
        'email': external?.email,
      };
    }

    return payload;
  }
}

class OvaFollowUpActionEditorDialog extends StatefulWidget {
  const OvaFollowUpActionEditorDialog({
    super.key,
    required this.defaultType,
    required this.assignableUsers,
    required this.loadExternalSuggestions,
    this.initialAction,
  });

  final String defaultType;
  final EditableOvaFollowUpAction? initialAction;
  final List<OvaTicketUser> assignableUsers;
  final Future<List<OvaExternalResponsible>> Function(String query)
  loadExternalSuggestions;

  @override
  State<OvaFollowUpActionEditorDialog> createState() =>
      _OvaFollowUpActionEditorDialogState();
}

class _OvaFollowUpActionEditorDialogState
    extends State<OvaFollowUpActionEditorDialog> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;

  late String _type;
  late String _assigneeType;
  late DateTime _dueDate;
  OvaTicketUser? _selectedInternalUser;
  OvaExternalResponsible? _selectedExternalResponsible;
  List<OvaExternalResponsible> _suggestions = const [];
  bool _isLoadingSuggestions = false;
  String? _error;
  Timer? _debounce;
  int _lookupVersion = 0;

  @override
  void initState() {
    super.initState();
    final initialAction = widget.initialAction;
    final external = initialAction?.externalResponsible;

    _descriptionController = TextEditingController(
      text: initialAction?.description ?? '',
    );
    _firstNameController = TextEditingController(
      text: external?.firstName ?? '',
    );
    _lastNameController = TextEditingController(text: external?.lastName ?? '');
    _emailController = TextEditingController(text: external?.email ?? '');

    _type = initialAction?.type ?? widget.defaultType;
    _assigneeType = initialAction?.assigneeType ?? 'internal';
    _dueDate =
        initialAction?.dueDate ?? DateTime.now().add(const Duration(days: 7));
    _selectedInternalUser = initialAction?.internalAssignee;
    _selectedExternalResponsible = external;

    _firstNameController.addListener(_scheduleLookup);
    _lastNameController.addListener(_scheduleLookup);
    _emailController.addListener(_scheduleLookup);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _descriptionController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _scheduleLookup() {
    if (_assigneeType != 'external') {
      return;
    }

    _selectedExternalResponsible = null;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _lookupSuggestions);
  }

  Future<void> _lookupSuggestions() async {
    final query = [
      _firstNameController.text.trim(),
      _lastNameController.text.trim(),
      _emailController.text.trim(),
    ].where((part) => part.isNotEmpty).join(' ');

    if (query.length < 2) {
      if (mounted) {
        setState(() {
          _suggestions = const [];
          _isLoadingSuggestions = false;
        });
      }
      return;
    }

    final lookupVersion = ++_lookupVersion;
    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      final suggestions = await widget.loadExternalSuggestions(query);
      if (!mounted || lookupVersion != _lookupVersion) {
        return;
      }

      setState(() {
        _suggestions = suggestions;
      });
    } catch (_) {
      if (!mounted || lookupVersion != _lookupVersion) {
        return;
      }

      setState(() {
        _suggestions = const [];
      });
    } finally {
      if (mounted && lookupVersion == _lookupVersion) {
        setState(() {
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  Future<void> _pickDeadline() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _dueDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
    });
  }

  void _applySuggestion(OvaExternalResponsible suggestion) {
    setState(() {
      _selectedExternalResponsible = suggestion;
      _firstNameController.text = suggestion.firstName;
      _lastNameController.text = suggestion.lastName;
      _emailController.text = suggestion.email ?? '';
      _suggestions = const [];
    });
  }

  void _save() {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      setState(() {
        _error = 'Geef een omschrijving voor de opvolgactie.';
      });
      return;
    }

    if (_assigneeType == 'internal' && _selectedInternalUser == null) {
      setState(() {
        _error = 'Selecteer een verantwoordelijke.';
      });
      return;
    }

    if (_assigneeType == 'external') {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      if (firstName.isEmpty || lastName.isEmpty) {
        setState(() {
          _error =
              'Voor een externe verantwoordelijke zijn voor- en achternaam verplicht.';
        });
        return;
      }
    }

    final externalResponsible = OvaExternalResponsible(
      id: _selectedExternalResponsible?.id ?? 0,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
    );

    Navigator.of(context).pop(
      EditableOvaFollowUpAction(
        id: widget.initialAction?.id,
        type: _type,
        description: description,
        dueDate: _dueDate,
        status: widget.initialAction?.status ?? 'nok',
        assigneeType: _assigneeType,
        internalAssignee: _assigneeType == 'internal'
            ? _selectedInternalUser
            : null,
        externalResponsible: _assigneeType == 'external'
            ? externalResponsible
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialAction == null
            ? 'Opvolgactie aanmaken'
            : 'Opvolgactie bewerken',
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _requiredLabel('Sectie'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('Corrigerend'),
                    selected: _type == 'corrective',
                    onSelected: (_) {
                      setState(() {
                        _type = 'corrective';
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Preventief'),
                    selected: _type == 'preventive',
                    onSelected: (_) {
                      setState(() {
                        _type = 'preventive';
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: _requiredLabel('Omschrijving'),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_requiredLabel('Deadline')}: ${formatOvaActionDate(_dueDate)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2B3424),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickDeadline,
                    icon: const Icon(Icons.event_outlined),
                    label: const Text('Selecteer datum'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                _requiredLabel('Verantwoordelijke'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('Interne gebruiker'),
                    selected: _assigneeType == 'internal',
                    onSelected: (_) {
                      setState(() {
                        _assigneeType = 'internal';
                        _error = null;
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Externe persoon'),
                    selected: _assigneeType == 'external',
                    onSelected: (_) {
                      setState(() {
                        _assigneeType = 'external';
                        _error = null;
                      });
                      _scheduleLookup();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_assigneeType == 'internal')
                DropdownButtonFormField<OvaTicketUser>(
                  initialValue: _selectedInternalUser,
                  decoration: InputDecoration(
                    labelText: _requiredLabel('Dashboard gebruiker'),
                  ),
                  items: widget.assignableUsers
                      .map(
                        (user) => DropdownMenuItem<OvaTicketUser>(
                          value: user,
                          child: Text(user.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedInternalUser = value;
                    });
                  },
                ),
              if (_assigneeType == 'external') ...[
                TextField(
                  controller: _firstNameController,
                  decoration: InputDecoration(
                    labelText: _requiredLabel('Voornaam'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lastNameController,
                  decoration: InputDecoration(
                    labelText: _requiredLabel('Achternaam'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'E-mail (optioneel)',
                  ),
                ),
                const SizedBox(height: 12),
                if (_isLoadingSuggestions)
                  const LinearProgressIndicator(minHeight: 2),
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Historiek suggesties',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ..._suggestions.map(
                    (suggestion) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => _applySuggestion(suggestion),
                        borderRadius: BorderRadius.circular(14),
                        child: Ink(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAF4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFDCE6C7)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.history_rounded,
                                color: Color(0xFF6B8F2A),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  suggestion.email == null ||
                                          suggestion.email!.trim().isEmpty
                                      ? suggestion.displayName
                                      : '${suggestion.displayName} (${suggestion.email})',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuleren'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Opslaan')),
      ],
    );
  }
}

DateTime _dateOnlyToUtc(DateTime value) {
  return DateTime.utc(value.year, value.month, value.day);
}
