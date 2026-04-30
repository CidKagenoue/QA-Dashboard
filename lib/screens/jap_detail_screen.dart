// lib/screens/jap_detail_screen.dart

import 'package:flutter/material.dart';
import '../models/jap_gpp_entry.dart';

class JapDetailScreen extends StatelessWidget {
  final JapEntry entry;
  final String token;

  const JapDetailScreen({
    super.key,
    required this.entry,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F2),
      body: Column(
        children: [
          _buildBreadcrumb(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 16),
                  _buildCard(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Row(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text(
                  'Dashboard',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right, size: 14, color: Colors.grey[400]),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text(
                  'JAP & GPP',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right, size: 14, color: Colors.grey[400]),
              ),
              Text(
                'JAP',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          _buildTabBar(),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIdRow(),
          const SizedBox(height: 12),
          _buildStatusBadge(),
          const SizedBox(height: 20),
          _buildGoalRow(),
          const SizedBox(height: 24),
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
          'ID ${entry.id.toString().padLeft(4, '0')}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF243022),
          ),
        ),
        Icon(Icons.edit_outlined, size: 18, color: Colors.grey[500]),
      ],
    );
  }

  Widget _buildGoalRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Doelstelling – maatregel',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 4),
              Text(
                entry.goalMeasure,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF243022),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Text(
          '01.01.${entry.year}',
          style: const TextStyle(fontSize: 13, color: Color(0xFF2F382E)),
        ),
        const SizedBox(width: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Uitvoerder',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            Text(
              '31.12.${entry.year}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF2F382E)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDomainDateRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Domein', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 4),
              Text(
                entry.domain,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF243022),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Start datum', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 4),
              Text(
                '01/01/${entry.year}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF2F382E)),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Einddatum', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 4),
              Text(
                '31/12/${entry.year}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF2F382E)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRiskExecutorRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Risicoveld', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 4),
              const Text(
                'Algemeen',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF243022),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Uitvoerder', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 4),
              Text(
                entry.executor.isNotEmpty ? entry.executor : '—',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF243022),
                ),
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
              const SizedBox(height: 4),
              _buildPriorityBadge(),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Realisatie', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 4),
              _buildRealisationLabel(),
            ],
          ),
        ),
        const Expanded(child: SizedBox()),
      ],
    );
  }

  Widget _buildRemarksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Opmerkingen', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 8),
        entry.remark.isNotEmpty
            ? Text(
                entry.remark,
                style: const TextStyle(fontSize: 13, color: Color(0xFF2F382E)),
              )
            : GestureDetector(
                onTap: () {},
                child: const Row(
                  children: [
                    Icon(Icons.add, size: 14, color: Color(0xFF6B7A62)),
                    SizedBox(width: 4),
                    Text(
                      'Toevoegen',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7A62)),
                    ),
                  ],
                ),
              ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final (label, backgroundColor, foregroundColor) = switch (entry.realisation) {
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
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: foregroundColor,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 16, color: foregroundColor),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge() {
    final (label, backgroundColor, foregroundColor) = switch (entry.priority) {
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
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foregroundColor,
        ),
      ),
    );
  }

  Widget _buildRealisationLabel() {
    final (label, color) = switch (entry.realisation) {
      JapRealisation.inProgress => ('In Uitvoering', const Color(0xFF1565C0)),
      JapRealisation.completed => ('Uitgevoerd', const Color(0xFF2E7D32)),
      JapRealisation.notYetCompleted => ('Nog niet uitgevoerd', const Color(0xFFD32F2F)),
      JapRealisation.fillIn => ('Vul aan', const Color(0xFF6B7A62)),
    };

    return Text(
      label,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
    );
  }
}