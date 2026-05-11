// lib/screens/jap_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../services/domain_service.dart';
import 'package:qa_dashboard/services/jap_gpp_api_service.dart';
import '../models/jap_gpp_entry.dart';
import '../widgets/comments_section.dart';
import '../widgets/domain_dropdown_field.dart';
import '../models/jap_comment.dart';

class JapDetailScreen extends StatefulWidget {
  final JapEntry entry;
  final String token;
  final VoidCallback onClose;

  const JapDetailScreen({
    super.key,
    required this.entry,
    required this.token,
    required this.onClose,
  });

  @override
  State<JapDetailScreen> createState() => _JapDetailScreenState();
}

class _JapDetailScreenState extends State<JapDetailScreen> {
  late JapEntry _entry;
  late final TextEditingController _remarkController;
  late final TextEditingController _goalController;
  late final TextEditingController _domainController;
  late final TextEditingController _riskFieldController;
  late final TextEditingController _executorController;
  late final TextEditingController _budgetController;
  List<String> _domains = DomainService.defaultDomains;
  List<JapComment> _comments = [];
  bool _commentsLoading = true;
  bool _editingRemark = false;
  bool _editingAll = false;
  late DateTime _startDate;
  late DateTime _endDate;
  late JapRealisation _selectedRealisation;
  late JapPriority _selectedPriority;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _remarkController = TextEditingController(text: _entry.remark);
    _goalController = TextEditingController(text: _entry.goalMeasure);
    _domainController = TextEditingController(text: _entry.domain);
    _riskFieldController = TextEditingController(text: _entry.riskField);
    _executorController = TextEditingController(text: _entry.executor);
    _budgetController = TextEditingController(text: _entry.resourcesBudget);
    _startDate = _entry.startDate ?? DateTime(_entry.year, 1, 1);
    _endDate = _entry.endDate ?? DateTime(_entry.year, 12, 31);
    _selectedRealisation = _entry.realisation;
    _selectedPriority = _entry.priority;
    _loadDomains();
    _loadComments();
  }

  @override
  void dispose() {
    _remarkController.dispose();
    _goalController.dispose();
    _domainController.dispose();
    _riskFieldController.dispose();
    _executorController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _loadDomains() async {
    final currentDomain = _domainController.text.trim();
    if (currentDomain.isNotEmpty) {
      await DomainService.addDomain(currentDomain);
    }

    final domains = await DomainService.loadDomains();
    if (!mounted) return;

    setState(() => _domains = domains);
  }

  Future<void> _loadComments() async {
    try {
      final raw = await JapApiService.fetchJapComments(token: widget.token, id: _entry.id);
      if (!mounted) return;
      setState(() {
        _comments = raw.map((e) => JapComment.fromJson(e)).toList();
        _commentsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _commentsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF243022)),
                onPressed: widget.onClose,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'JAP-detail',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF243022),
                    ),
                  ),
                  Text(
                    'ID ${_entry.id.toString().padLeft(4, '0')}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7A62)),
                  ),
                ],
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _confirmDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Verwijderen'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD32F2F),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => setState(() => _editingAll = !_editingAll),
                icon: Icon(_editingAll ? Icons.visibility_outlined : Icons.edit_outlined, size: 18),
                label: Text(_editingAll ? 'Bekijken' : 'Bewerken'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF4A7A1E)),
              ),
            ],
          ),
        ),
        // Tab bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(
            children: [
              _buildTab('Basisinformatie', isSelected: true),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildCard(context),
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String label, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isSelected ? const Color(0xFF8CC63F) : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? const Color(0xFF243022) : const Color(0xFF6B7A62),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4E9DD)),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIdRow(),
              const SizedBox(height: 10),
              _buildStatusBadge(),
              const SizedBox(height: 16),
              _buildGoalSection(),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE4E9DD)),
              const SizedBox(height: 14),
              _buildDomainDateRow(),
              const SizedBox(height: 14),
              _buildRiskExecutorRow(),
              const SizedBox(height: 14),
              _buildPriorityRealisationRow(),
              const SizedBox(height: 14),
              _buildRemarksSection(),
            ],
          ),
        ),
        const SizedBox(height: 20),
        CommentsSection(
          comments: _comments,
          loading: _commentsLoading,
          onAdd: (text) async {
            final raw = await JapApiService.addJapComment(
              token: widget.token,
              id: _entry.id,
              author: 'Gebruiker',
              text: text,
            );
            setState(() => _comments.add(JapComment.fromJson(raw)));
          },
        ),
      ],
    );
  }

  Widget _buildIdRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'ID ${_entry.id.toString().padLeft(4, '0')}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF243022),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F8F2),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE4E9DD)),
          ),
          child: Text(
            _entry.year.toString(),
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF4D5548)),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Doelstelling – maatregel',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 6),
        _editingAll
            ? TextField(
                controller: _goalController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Doelstelling – maatregel',
                  isDense: true,
                ),
              )
            : Text(
                _goalController.text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF243022),
                ),
              ),
      ],
    );
  }

  Widget _buildDomainDateRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 220,
          child: _editingAll
              ? _buildEditableDomainDropdown()
              : _buildLabelValue('Domein', _entry.domain, bold: true),
        ),
        SizedBox(
          width: 180,
          child: _editingAll
              ? _buildEditableDateField('Start datum', _startDate, (date) => setState(() => _startDate = date))
              : _buildLabelValue('Start datum', _formatDate(_entry.startDate, '01/01/${_entry.year}')),
        ),
        SizedBox(
          width: 180,
          child: _editingAll
              ? _buildEditableDateField('Einddatum', _endDate, (date) => setState(() => _endDate = date))
              : _buildLabelValue('Einddatum', _formatDate(_entry.endDate, '31/12/${_entry.year}')),
        ),
      ],
    );
  }

  Widget _buildRiskExecutorRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 220,
          child: _editingAll
              ? _buildEditableTextField('Risicoveld', _riskFieldController)
              : _buildLabelValue('Risicoveld', _entry.riskField, bold: true),
        ),
        SizedBox(
          width: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Uitvoerder', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 4),
              _editingAll
                  ? TextField(
                      controller: _executorController,
                      decoration: const InputDecoration(isDense: true),
                    )
                  : Text(
                      _executorController.text.isNotEmpty ? _executorController.text : '—',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF243022)),
                    ),
            ],
          ),
        ),
        SizedBox(
          width: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Middelen / Budget', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 4),
              _editingAll
                  ? TextField(
                      controller: _budgetController,
                      decoration: const InputDecoration(isDense: true),
                    )
                  : Text(
                      _budgetController.text.isNotEmpty ? _budgetController.text : '—',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF243022)),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime? value, String fallback) {
    if (value == null) return fallback;
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  Widget _buildPriorityRealisationRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Prioriteit', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 6),
              _editingAll
                  ? DropdownButton<JapPriority>(
                      value: _selectedPriority,
                      isExpanded: true,
                      isDense: true,
                      items: const [
                        DropdownMenuItem(value: JapPriority.high, child: Text('Hoge prioriteit')),
                        DropdownMenuItem(value: JapPriority.medium, child: Text('Middelhoge prioriteit')),
                        DropdownMenuItem(value: JapPriority.low, child: Text('Lage prioriteit')),
                      ],
                      onChanged: (v) => setState(() => _selectedPriority = v!),
                    )
                  : _buildPriorityBadge(),
            ],
          ),
        ),
        SizedBox(
          width: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Realisatie', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 6),
              _editingAll
                  ? DropdownButton<JapRealisation>(
                      value: _selectedRealisation,
                      isExpanded: true,
                      isDense: true,
                      items: const [
                        DropdownMenuItem(value: JapRealisation.completed, child: Text('Uitgevoerd')),
                        DropdownMenuItem(value: JapRealisation.inProgress, child: Text('In uitvoering')),
                        DropdownMenuItem(value: JapRealisation.notYetCompleted, child: Text('Nog niet uitgevoerd')),
                        DropdownMenuItem(value: JapRealisation.fillIn, child: Text('Vul aan')),
                      ],
                      onChanged: (v) => setState(() => _selectedRealisation = v!),
                    )
                  : _buildRealisationLabel(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabelValue(String label, String value, {bool bold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 14 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: const Color(0xFF243022),
          ),
        ),
      ],
    );
  }

  Widget _buildEditableTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: const InputDecoration(isDense: true),
        ),
      ],
    );
  }

  Widget _buildEditableDomainDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Domein', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 4),
        DomainDropdownField(
          value: _domainController.text,
          domains: _domains,
          onChanged: (value) {
            setState(() => _domainController.text = value);
          },
          onDomainAdded: (value) {
            setState(() {
              _domainController.text = value;
              if (!_domains.any((domain) => domain.toLowerCase() == value.toLowerCase())) {
                _domains = [..._domains, value];
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildEditableDateField(String label, DateTime date, ValueChanged<DateTime> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) onChanged(picked);
          },
          child: InputDecorator(
            decoration: const InputDecoration(isDense: true),
            child: Text(_formatDate(date, '')),
          ),
        ),
      ],
    );
  }

  Widget _buildRemarksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Opmerkingen', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 6),
        if (_editingRemark)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _remarkController,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Voeg een opmerking toe...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _editingRemark = false),
                    child: const Text('Annuleren',
                        style: TextStyle(color: Color(0xFF6B7A62))),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await JapApiService.updateRemark(
                          token: widget.token,
                          id: _entry.id,
                          remark: _remarkController.text.trim(),
                        );
                          setState(() {
                            _editingRemark = false;
                          });
                          // Refresh notifications immediately
                          try {
                            await context.read<NotificationService>().loadNotifications(limit: 50);
                            await context.read<NotificationService>().refreshUnreadCount();
                          } catch (_) {}
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Fout bij opslaan: ${e.toString()}')),
                          );
                        }
                      }
                    },
                    child: const Text('Opslaan'),
                  ),
                ],
              ),
            ],
          )
        else if (_remarkController.text.isNotEmpty)
          GestureDetector(
            onTap: () => setState(() => _editingRemark = true),
            child: Text(
              _remarkController.text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF2F382E)),
            ),
          )
        else
          GestureDetector(
            onTap: () => setState(() => _editingRemark = true),
            child: Row(
              children: [
                Icon(Icons.add, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('Toevoegen',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              ],
            ),
          ),
        if (_editingAll) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  _goalController.text = _entry.goalMeasure;
                  _executorController.text = _entry.executor;
                  _domainController.text = _entry.domain;
                  _riskFieldController.text = _entry.riskField;
                  _budgetController.text = _entry.resourcesBudget;
                  _startDate = _entry.startDate ?? DateTime(_entry.year, 1, 1);
                  _endDate = _entry.endDate ?? DateTime(_entry.year, 12, 31);
                  setState(() {
                    _editingAll = false;
                    _selectedPriority = _entry.priority;
                    _selectedRealisation = _entry.realisation;
                  });
                },
                child: const Text('Annuleren',
                    style: TextStyle(color: Color(0xFF6B7A62))),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final updated = await JapApiService.updateJapEntry(
                      token: widget.token,
                      id: _entry.id,
                      payload: {
                        'doelstellingMaatregel': _goalController.text.trim(),
                        'domein': _domainController.text.trim(),
                        'risicoveld': _riskFieldController.text.trim(),
                        'uitvoerder': _executorController.text.trim(),
                        'middelenBudgetWerkuren': _budgetController.text.trim(),
                        'jaar': _entry.year,
                        'startdatum': _formatDate(_startDate, ''),
                        'einddatum': _formatDate(_endDate, ''),
                        'prioriteit': _priorityToString(_selectedPriority),
                        'realisatie': _realisationToString(_selectedRealisation),
                        'opmerking': _remarkController.text.trim(),
                      },
                    );
                    setState(() {
                      _entry = updated;
                      _goalController.text = updated.goalMeasure;
                      _domainController.text = updated.domain;
                      _riskFieldController.text = updated.riskField;
                      _executorController.text = updated.executor;
                      _budgetController.text = updated.resourcesBudget;
                      _startDate = updated.startDate ?? _startDate;
                      _endDate = updated.endDate ?? _endDate;
                      _selectedPriority = updated.priority;
                      _selectedRealisation = updated.realisation;
                      _editingAll = false;
                    });
                    // Refresh notifications immediately
                    try {
                      await context.read<NotificationService>().loadNotifications(limit: 50);
                      await context.read<NotificationService>().refreshUnreadCount();
                    } catch (_) {}
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Fout bij opslaan: ${e.toString()}')),
                      );
                    }
                  }
                },
                child: const Text('Opslaan'),
              ),
            ],
          ),
        ],
      ],
    );
  }
  

  Widget _buildStatusBadge() {
    final (label, backgroundColor, foregroundColor) = switch (_entry.realisation) {
      JapRealisation.completed => ('Uitgevoerd', const Color(0xFFEAF4D9), const Color(0xFF4A7A1E)),
      JapRealisation.inProgress => ('In uitvoering', const Color(0xFFE3F0FF), const Color(0xFF1565C0)),
      JapRealisation.notYetCompleted => ('Niet uitgevoerd', const Color(0xFFFFEDED), const Color(0xFFD32F2F)),
      JapRealisation.fillIn => ('Vul aan', const Color(0xFFF1F1F1), const Color(0xFF757575)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: foregroundColor),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('JAP verwijderen'),
        content: const Text('Weet je zeker dat je deze JAP wilt verwijderen? Deze actie kan niet ongedaan worden gemaakt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await JapApiService.deleteJapEntry(token: widget.token, id: _entry.id);
      if (!mounted) return;
      try {
        await context.read<NotificationService>().loadNotifications(limit: 50);
        await context.read<NotificationService>().refreshUnreadCount();
      } catch (_) {}
      widget.onClose();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('JAP verwijderd.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verwijderen mislukt: $e')),
      );
    }
  }

  Widget _buildPriorityBadge() {
    final (label, backgroundColor, foregroundColor) = switch (_entry.priority) {
      JapPriority.high => ('Hoge prioriteit', const Color(0xFFFFEDED), const Color(0xFFD32F2F)),
      JapPriority.medium => ('Middelhoge prioriteit', const Color(0xFFFFF8E1), const Color(0xFFF57F17)),
      JapPriority.low => ('Lage prioriteit', const Color(0xFFF1F1F1), const Color(0xFF757575)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: foregroundColor)),
    );
  }

  Widget _buildRealisationLabel() {
    final (label, color) = switch (_entry.realisation) {
      JapRealisation.inProgress => ('In Uitvoering', const Color(0xFF1565C0)),
      JapRealisation.completed => ('Uitgevoerd', const Color(0xFF2E7D32)),
      JapRealisation.notYetCompleted => ('Nog niet uitgevoerd', const Color(0xFFD32F2F)),
      JapRealisation.fillIn => ('Vul aan', const Color(0xFF6B7A62)),
    };

    return Text(label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color));
  }

  String _priorityToString(JapPriority p) {
    switch (p) {
      case JapPriority.high: return 'hoog';
      case JapPriority.medium: return 'middel';
      case JapPriority.low: return 'laag';
    }
  }

  String _realisationToString(JapRealisation r) {
    switch (r) {
      case JapRealisation.completed: return 'uitgevoerd';
      case JapRealisation.inProgress: return 'in_uitvoering';
      case JapRealisation.notYetCompleted: return 'neg_niet_uitgevoerd';
      case JapRealisation.fillIn: return 'vul_aan';
    }
  }
}