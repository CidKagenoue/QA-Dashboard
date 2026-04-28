// lib/screens/jap_gpp_screen.dart
import 'package:flutter/material.dart';

class JapGppScreen extends StatelessWidget {
  const JapGppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ModulePlaceholder(
      moduleName: 'JAP & GPP',
      icon: Icons.folder_open_outlined,
      description:
          'De JAP & GPP module is momenteel in ontwikkeling. '
          'Hier zal je JAP- en GPP-documenten en -processen kunnen beheren.',
    );
  }
}

class _ModulePlaceholder extends StatelessWidget {
  const _ModulePlaceholder({
    required this.moduleName,
    required this.icon,
    required this.description,
  });

  final String moduleName;
  final IconData icon;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE4E9DD)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4D9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 48, color: const Color(0xFF8CC63F)),
            ),
            const SizedBox(height: 24),
            Text(
              moduleName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E2A18),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF6B7A62),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5FAEC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD5E4B4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.construction_rounded,
                      size: 16, color: Color(0xFF6B8F2A)),
                  SizedBox(width: 8),
                  Text(
                    'Binnenkort beschikbaar',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B8F2A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}