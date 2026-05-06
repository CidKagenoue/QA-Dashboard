// lib/screens/gpp_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import 'package:qa_dashboard/services/jap_gpp_api_service.dart';
import '../models/jap_gpp_entry.dart';

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
  late final TextEditingController _goalController;
  bool _editingAll = false;

  @override
  void initState() {
    super.initState();
    _goalController = TextEditingController(text: widget.entry.goalMeasure);
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF243022)),
                onPressed: widget.onClose,
              ),
              const Text(
                'GPP Detail',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF243022),
                ),
              ),
            ],
          ),
        ),
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
            padding: const EdgeInsets.all(24),
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
          const SizedBox(height: 20),
          _buildGoalSection(),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE4E9DD)),
          const SizedBox(height: 16),
          _buildYearsDomainRow(),
          const SizedBox(height: 20),
          if (_editingAll) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    _goalController.text = widget.entry.goalMeasure;
                    setState(() => _editingAll = false);
                  },
                  child: const Text('Annuleren', style: TextStyle(color: Color(0xFF6B7A62))),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await JapApiService.updateGppEntry(
                        token: widget.token,
                        id: widget.entry.id,
                        payload: {
                          'doelstellingMaatregel': _goalController.text.trim(),
                          'startJaar': widget.entry.startYear,
                          'eindJaar': widget.entry.endYear,
                        },
                      );
                      setState(() => _editingAll = false);
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
        Text('Doelstelling – maatregel', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 4),
        _editingAll
            ? TextField(
                controller: _goalController,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Doelstelling – maatregel'),
              )
            : Text(
                _goalController.text,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF243022)),
              ),
      ],
    );
  }

  Widget _buildYearsDomainRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildLabelValue('Periode', widget.entry.yearLabel, bold: true)),
        Expanded(child: _buildLabelValue('Domein', widget.entry.domain)),
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
}
