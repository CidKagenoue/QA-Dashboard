import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qa_dashboard/services/jap_gpp_api_service.dart';
import '../models/jap_gpp_entry.dart';
import '../services/domain_service.dart';
import '../services/notification_service.dart';
import '../widgets/comments_section.dart';
import '../widgets/domain_dropdown_field.dart';
import '../models/jap_comment.dart';

class GppDetailScreen extends StatefulWidget {
  final GppEntry entry;
  final String token;
  final VoidCallback onClose;

  const GppDetailScreen({
    super.key,
    required this.entry,
    required this.token,
    required this.onClose,
  });

  @override
  State<GppDetailScreen> createState() => _GppDetailScreenState();
}

class _GppDetailScreenState extends State<GppDetailScreen> {
  late GppEntry _entry;
  late final TextEditingController _goalController;
  late final TextEditingController _domainController;
  late final TextEditingController _riskFieldController;
  late final TextEditingController _executorController;
  late final TextEditingController _resourcesController;
  late final TextEditingController _remarkController;
  List<JapComment> _comments = [];
  bool _commentsLoading = true;
  List<String> _domains = DomainService.defaultDomains;
  late DateTime _startDate;
  late DateTime _endDate;
  late String _priority;
  late String _realisation;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _goalController = TextEditingController(text: _entry.goalMeasure);
    _domainController = TextEditingController(text: _entry.domain);
    _riskFieldController = TextEditingController(text: _entry.riskField);
    _executorController = TextEditingController(text: _entry.executor);
    _resourcesController = TextEditingController(text: _entry.resourcesBudget);
    _remarkController = TextEditingController(text: _entry.remark);
    _startDate = _entry.startDate ?? DateTime(_entry.startYear, 1, 1);
    _endDate = _entry.endDate ?? DateTime(_entry.endYear, 12, 31);
    _priority = _normalisePriority(_entry.priority);
    _realisation = _normaliseRealisation(_entry.realisation);
    _loadDomains();
    _loadComments();
  }

  @override
  void dispose() {
    _goalController.dispose();
    _domainController.dispose();
    _riskFieldController.dispose();
    _executorController.dispose();
    _resourcesController.dispose();
    _remarkController.dispose();
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
      final raw = await JapApiService.fetchGppComments(token: widget.token, id: _entry.id);
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
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummary(),
                const SizedBox(height: 20),
                _buildDetailsSection(),
                const SizedBox(height: 20),
                _buildGeneratedYears(),
                const SizedBox(height: 20),
                CommentsSection(
                  comments: _comments,
                  loading: _commentsLoading,
                  onAdd: (text) async {
                    final raw = await JapApiService.addGppComment(
                      token: widget.token,
                      id: _entry.id,
                      author: 'Gebruiker',
                      text: text,
                    );
                    setState(() => _comments.add(JapComment.fromJson(raw)));
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
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
                'GPP-lijn',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF243022)),
              ),
              Text(
                'ID ${_entry.id.toString().padLeft(4, '0')}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7A62)),
              ),
            ],
          ),
          const Spacer(),
          if (_editing)
            TextButton(
              onPressed: _saving ? null : _cancelEditing,
              child: const Text('Annuleren'),
            ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _saving ? null : _confirmDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Verwijderen'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFD32F2F)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _saving ? null : (_editing ? _save : () => setState(() => _editing = true)),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(_editing ? Icons.save_outlined : Icons.edit_outlined, size: 18),
            label: Text(_editing ? 'Opslaan' : 'Bewerken'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8CC63F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Row(
      children: [
        _buildMiniChip('GPP ${_entry.startYear} - ${_entry.endYear}'),
        const SizedBox(width: 8),
        _buildStatusPill(_realisation),
        const Spacer(),
        _buildMiniChip(_entry.yearLabel),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final columnWidth = wide ? (constraints.maxWidth - 14) / 2 : constraints.maxWidth;

        Widget field(
          String label,
          TextEditingController? controller, {
          int maxLines = 1,
          String? priority,
          String? realisation,
          bool isDate = false,
          DateTime? date,
          ValueChanged<DateTime>? onDateChanged,
        }) {
          return SizedBox(
            width: label == 'Doelstelling – maatregel' || label == 'Opmerking' || !wide ? constraints.maxWidth : columnWidth,
            child: _buildDetailRow(
              label,
              controller,
              maxLines: maxLines,
              priority: priority,
              realisation: realisation,
              isDate: isDate,
              date: date,
              onDateChanged: onDateChanged,
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4E9DD)),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gegevens',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF243022)),
              ),
              const SizedBox(height: 14),
              field('Doelstelling – maatregel', _goalController, maxLines: 3),
              const SizedBox(height: 12),
              if (wide)
                Wrap(
                  spacing: 14,
                  runSpacing: 12,
                  children: [
                    field('Domein', _domainController),
                    field('Risicoveld', _riskFieldController),
                    field('Prioriteit', null, priority: _priority),
                    field('Realisatie', null, realisation: _realisation),
                    field('Uitvoerder', _executorController),
                    field('Middelen / Budget / Werkuren', _resourcesController),
                    field(
                      'Startdatum',
                      null,
                      isDate: true,
                      date: _startDate,
                      onDateChanged: (date) => setState(() => _startDate = date),
                    ),
                    field(
                      'Einddatum',
                      null,
                      isDate: true,
                      date: _endDate,
                      onDateChanged: (date) => setState(() => _endDate = date),
                    ),
                    field('Opmerking', _remarkController, maxLines: 3),
                  ],
                )
              else ...[
                field('Domein', _domainController),
                const SizedBox(height: 12),
                field('Risicoveld', _riskFieldController),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: field('Prioriteit', null, priority: _priority)),
                    const SizedBox(width: 12),
                    Expanded(child: field('Realisatie', null, realisation: _realisation)),
                  ],
                ),
                const SizedBox(height: 12),
                field('Uitvoerder', _executorController),
                const SizedBox(height: 12),
                field('Middelen / Budget / Werkuren', _resourcesController),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: field(
                        'Startdatum',
                        null,
                        isDate: true,
                        date: _startDate,
                        onDateChanged: (date) => setState(() => _startDate = date),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: field(
                        'Einddatum',
                        null,
                        isDate: true,
                        date: _endDate,
                        onDateChanged: (date) => setState(() => _endDate = date),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                field('Opmerking', _remarkController, maxLines: 3),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    TextEditingController? controller, {
    int maxLines = 1,
    String? priority,
    String? realisation,
    bool isDate = false,
    DateTime? date,
    ValueChanged<DateTime>? onDateChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7A62)),
        ),
        const SizedBox(height: 8),
        if (controller != null)
          label == 'Domein'
              ? _editableDomainField()
              : _editableField(controller, maxLines: maxLines)
        else if (priority != null)
          _buildPriorityPill(priority)
        else if (realisation != null)
          _buildRealisationText(realisation)
        else if (isDate && date != null && onDateChanged != null)
          _editableDateField(date, onDateChanged),
      ],
    );
  }

  Widget _editableField(TextEditingController controller, {int maxLines = 1}) {
    if (!_editing) {
      return Text(
        controller.text.isEmpty ? '-' : controller.text,
        style: const TextStyle(fontSize: 13, color: Color(0xFF2F382E)),
      );
    }
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _editableDomainField() {
    if (!_editing) {
      return Text(
        _domainController.text.isEmpty ? '-' : _domainController.text,
        style: const TextStyle(fontSize: 13, color: Color(0xFF2F382E)),
      );
    }

    return DomainDropdownField(
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
    );
  }

  Widget _editableDateField(DateTime date, ValueChanged<DateTime> onChanged) {
    if (!_editing) {
      return Text(
        _formatDate(date),
        style: const TextStyle(fontSize: 13, color: Color(0xFF2F382E)),
      );
    }
    return InkWell(
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
        decoration: InputDecoration(
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Text(_formatDate(date)),
      ),
    );
  }

  Widget _buildGeneratedYears() {
    final years = <int>[];
    final firstYear = _startDate.year <= _endDate.year ? _startDate.year : _endDate.year;
    final lastYear = _startDate.year <= _endDate.year ? _endDate.year : _startDate.year;
    for (int year = firstYear; year <= lastYear; year += 1) {
      years.add(year);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E9DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              'JAP per jaar',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF243022)),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE4E9DD)),
          for (final year in years)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      year.toString(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF243022)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _goalController.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF2F382E)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildStatusPill(_realisation),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriorityPill(String value) {
    final (label, bg, fg) = value == 'hoog'
        ? ('Hoge prioriteit', const Color(0xFFFFEDED), const Color(0xFFD32F2F))
        : value == 'middel'
            ? ('Middelhoge prioriteit', const Color(0xFFFFF8E1), const Color(0xFFF57F17))
            : ('Lage prioriteit', const Color(0xFFF1F1F1), const Color(0xFF757575));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _buildRealisationText(String value) {
    final (label, color) = value == 'uitgevoerd'
        ? ('Uitgevoerd', const Color(0xFF2E7D32))
        : value == 'neg_niet_uitgevoerd'
            ? ('Nog niet uitgevoerd', const Color(0xFFD32F2F))
            : value == 'in_uitvoering'
                ? ('In uitvoering', const Color(0xFF1565C0))
                : ('Vul aan', const Color(0xFF6B7A62));
    return Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color));
  }

  Widget _buildStatusPill(String value) {
    final color = value == 'uitgevoerd'
        ? const Color(0xFF2E7D32)
        : value == 'neg_niet_uitgevoerd'
            ? const Color(0xFFD32F2F)
            : value == 'in_uitvoering'
                ? const Color(0xFF1565C0)
                : const Color(0xFF6B7A62);
    final background = Color.alphaBlend(color.withOpacity(0.10), Colors.white);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: _buildRealisationText(value),
    );
  }

  Widget _buildMiniChip(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4E9DD)),
      ),
      child: Text(
        value,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF4D5548)),
      ),
    );
  }

  void _cancelEditing() {
    _goalController.text = _entry.goalMeasure;
    _domainController.text = _entry.domain;
    _riskFieldController.text = _entry.riskField;
    _executorController.text = _entry.executor;
    _resourcesController.text = _entry.resourcesBudget;
    _remarkController.text = _entry.remark;
    setState(() {
      _startDate = _entry.startDate ?? DateTime(_entry.startYear, 1, 1);
      _endDate = _entry.endDate ?? DateTime(_entry.endYear, 12, 31);
      _priority = _normalisePriority(_entry.priority);
      _realisation = _normaliseRealisation(_entry.realisation);
      _editing = false;
    });
  }

  Future<void> _save() async {
    if (_goalController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doelstelling is verplicht.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = await JapApiService.updateGppEntry(
        token: widget.token,
        id: _entry.id,
        payload: {
          'doelstellingMaatregel': _goalController.text.trim(),
          'domein': _domainController.text.trim(),
          'risicoveld': _riskFieldController.text.trim(),
          'prioriteit': _priority,
          'realisatie': _realisation,
          'uitvoerder': _executorController.text.trim(),
          'middelenBudgetWerkuren': _resourcesController.text.trim(),
          'startJaar': _startDate.year,
          'eindJaar': _endDate.year,
          'startdatum': _formatDate(_startDate),
          'einddatum': _formatDate(_endDate),
          'opmerking': _remarkController.text.trim(),
        },
      );

      if (!mounted) return;
      setState(() {
        _entry = updated;
        _editing = false;
      });

      try {
        await context.read<NotificationService>().loadNotifications(limit: 50);
        await context.read<NotificationService>().refreshUnreadCount();
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij opslaan: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('GPP verwijderen'),
        content: const Text('Weet je zeker dat je deze GPP wilt verwijderen? De gekoppelde JAP-regels worden ook verwijderd.'),
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
      await JapApiService.deleteGppEntry(token: widget.token, id: _entry.id);
      if (!mounted) return;
      try {
        await context.read<NotificationService>().loadNotifications(limit: 50);
        await context.read<NotificationService>().refreshUnreadCount();
      } catch (_) {}
      widget.onClose();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPP verwijderd.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verwijderen mislukt: $e')),
      );
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  String _normalisePriority(String value) {
    final text = value.toLowerCase();
    if (text.contains('hoog')) return 'hoog';
    if (text.contains('middel')) return 'middel';
    return 'laag';
  }

  String _normaliseRealisation(String value) {
    final text = value.toLowerCase();
    if (text.contains('nog') || text.contains('niet')) return 'neg_niet_uitgevoerd';
    if (text.contains('uitgevoerd')) return 'uitgevoerd';
    if (text.contains('uitvoering')) return 'in_uitvoering';
    return 'vul_aan';
  }
}
