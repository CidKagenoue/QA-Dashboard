import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import 'account_management_page.dart';
import 'departments_screen.dart';
import 'login_screen.dart';
import 'ova_dashboard_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QA Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          Consumer<AuthService>(
            builder: (context, authService, child) {
              return IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await authService.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, child) {
          final user = authService.user;
          if (user == null) {
            return const Center(child: Text('No user data available'));
          }

          final canOpenOva =
              user.isAdmin || user.access.basis || user.access.ova;
          final hasFullOva = user.isAdmin || user.access.ova;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome!',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text('Email: ${user.email}'),
                        if (user.name != null && user.name!.isNotEmpty)
                          Text('Name: ${user.name}'),
                        Text('User ID: ${user.id}'),
                        const SizedBox(height: 8),
                        Text(
                          user.isAdmin ? 'Role: Administrator' : 'Role: User',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _AccessChip(
                              label: canOpenOva
                                  ? hasFullOva
                                        ? 'OVA volledig'
                                        : 'Basis OVA-acties'
                                  : 'Geen OVA-toegang',
                              color: canOpenOva
                                  ? const Color(0xFFE9F5D6)
                                  : const Color(0xFFF1F1EE),
                              textColor: canOpenOva
                                  ? const Color(0xFF567D1B)
                                  : const Color(0xFF5F665A),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dashboard Content',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            canOpenOva
                                ? 'Open de OVA-module en navigeer snel naar Tickets, Acties of Nieuwe Ticket.'
                                : 'Je hebt nog geen OVA-rechten. Vraag Basis (OVA Acties) of volledige OVA-toegang aan om dit startscherm te openen.',
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Beheerfuncties voor accounts en afdelingen blijven hieronder beschikbaar.',
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              ElevatedButton.icon(
                                onPressed: canOpenOva
                                    ? () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const OvaDashboardScreen(),
                                          ),
                                        );
                                      }
                                    : null,
                                icon: const Icon(Icons.radio_button_checked),
                                label: Text(
                                  hasFullOva
                                      ? 'Open OVA-module'
                                      : 'Open OVA-acties',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8CC63F),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const DepartmentsScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.business),
                                label: const Text('Manage Departments'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7CB342),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AccountManagementPage(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.manage_accounts),
                                label: Text(
                                  authService.canManageAccounts
                                      ? 'Manage Accounts'
                                      : 'Open Account Management',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F6D2A),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AccessChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _AccessChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
      ),
    );
  }
}