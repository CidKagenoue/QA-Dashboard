// lib/screens/jap_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../widgets/app_bars/main_app_bar.dart';
import 'package:qa_dashboard/services/jap_gpp_api_service.dart';
import '../models/jap_gpp_entry.dart';

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
  late final TextEditingController _remarkController;
  late final TextEditingController _goalController;
  late final TextEditingController _executorController;
  bool _editingRemark = false;
  bool _editingAll = false;
  late JapRealisation _selectedRealisation;
  late JapPriority _selectedPriority;

  @override
  void initState() {
    super.initState();
    _remarkController = TextEditingController(text: widget.entry.remark);
    _goalController = TextEditingController(text: widget.entry.goalMeasure);
    _executorController = TextEditingController(text: widget.entry.executor);
    _selectedRealisation = widget.entry.realisation;
    _selectedPriority = widget.entry.priority;
  }

  @override
  void dispose() {
    _remarkController.dispose();
    _goalController.dispose();
    _executorController.dispose();
    super.dispose();
  }

  // jap_detail_screen.dart

@override
Widget build(BuildContext context) {
    return Column(
      children: [
        _buildBreadcrumb(context),
        _buildTabBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildCard(context),
          ),
        ),
      ],
    );
  }


  Widget _buildBreadcrumb(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onClose,
            child: Text('Dashboard', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
          ),
          GestureDetector(
            onTap: widget.onClose,
            child: Text('JAP & GPP', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
          ),
          Text('JAP', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          const Spacer(),
          TextButton(
            onPressed: widget.onClose,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Sluiten',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF243022),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: [
          _buildTab('Basisinformatie', isSelected: true),
        ],
      ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9DD)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIdRow(),
          const SizedBox(height: 12),
          _buildStatusBadge(),
          const SizedBox(height: 20),
          _buildGoalSection(),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE4E9DD)),
          const SizedBox(height: 16),
          _buildDomainDateRow(),
          const SizedBox(height: 20),
          _buildRiskExecutorRow(),
          const SizedBox(height: 20),
          _buildPriorityRealisationRow(),
          const SizedBox(height: 20),
          _buildRemarksSection(),
        ],
      ),
    );
  }

  Widget _buildIdRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'ID ${widget.entry.id.toString().padLeft(4, '0')}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF243022),
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _editingAll = !_editingAll),
          child: Icon(
            _editingAll ? Icons.edit : Icons.edit_outlined,
            size: 18,
            color: _editingAll ? const Color(0xFF8CC63F) : Colors.grey[400],
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
        const SizedBox(height: 4),
        _editingAll
            ? TextField(
                controller: _goalController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Doelstelling – maatregel',
                ),
              )
            : Text(
                _goalController.text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF243022),
                ),
              ),
      ],
    );
  }

  Widget _buildDomainDateRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildLabelValue('Domein', widget.entry.domain, bold: true)),
        Expanded(child: _buildLabelValue('Start datum', '01/01/${widget.entry.year}')),
        Expanded(child: _buildLabelValue('Einddatum', '31/12/${widget.entry.year}')),
      ],
    );
  }

  Widget _buildRiskExecutorRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildLabelValue('Risicoveld', 'Algemeen', bold: true)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Uitvoerder', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 4),
              _editingAll
                  ? TextField(controller: _executorController)
                  : Text(
                      _executorController.text.isNotEmpty ? _executorController.text : '—',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF243022)),
                    ),
            ],
          ),
        ),
        const Expanded(child: SizedBox()),
      ],
    );
  }

  Widget _buildPriorityRealisationRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Prioriteit', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 6),
              _editingAll
                  ? DropdownButton<JapPriority>(
                      value: _selectedPriority,
                      isExpanded: true,
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Realisatie', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 6),
              _editingAll
                  ? DropdownButton<JapRealisation>(
                      value: _selectedRealisation,
                      isExpanded: true,
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
        const Expanded(child: SizedBox()),
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
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: const Color(0xFF243022),
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
        const SizedBox(height: 8),
        if (_editingRemark)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _remarkController,
                autofocus: true,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Voeg een opmerking toe...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
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
                          id: widget.entry.id,
                          remark: _remarkController.text.trim(),
                        );
                          setState(() => _editingRemark = false);
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
                  _goalController.text = widget.entry.goalMeasure;
                  _executorController.text = widget.entry.executor;
                  setState(() {
                    _editingAll = false;
                    _selectedPriority = widget.entry.priority;
                    _selectedRealisation = widget.entry.realisation;
                  });
                },
                child: const Text('Annuleren',
                    style: TextStyle(color: Color(0xFF6B7A62))),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await JapApiService.updateJapEntry(
                      token: widget.token,
                      id: widget.entry.id,
                      payload: {
                        'doelstellingMaatregel': _goalController.text.trim(),
                        'uitvoerder': _executorController.text.trim(),
                        'prioriteit': _priorityToString(_selectedPriority),
                        'realisatie': _realisationToString(_selectedRealisation),
                        'opmerking': _remarkController.text.trim(),
                      },
                    );
                    setState(() => _editingAll = false);
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
    final (label, backgroundColor, foregroundColor) = switch (widget.entry.realisation) {
      JapRealisation.completed => ('Actief', const Color(0xFFEAF4D9), const Color(0xFF4A7A1E)),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: foregroundColor)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 16, color: foregroundColor),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge() {
    final (label, backgroundColor, foregroundColor) = switch (widget.entry.priority) {
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
    final (label, color) = switch (widget.entry.realisation) {
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