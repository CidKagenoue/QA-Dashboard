import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qa_dashboard/screens/account_management_screen.dart';
import '../widgets/app_bars/main_app_bar.dart';

import '../services/auth_service.dart';
import 'departments_screen.dart';
import 'ova_dashboard_screen.dart';

enum _HomeSection {
  dashboard,
  whsTours,
  ova,
  onderhoud,
  japGpp,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const _sidebarGreen = Color(0xFF8BC34A);
  static const _sidebarText = Color(0xFFFFFFFF);
  static const _sidebarSelected = Color(0xFF7CB342);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _HomeSection _selected = _HomeSection.dashboard;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MainAppBar(title: 'Vlotter',),
      body: Row(
        children: [
          Container(
            width: 200,
            color: HomeScreen._sidebarGreen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                _SidebarItem(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  selected: _selected == _HomeSection.dashboard,
                  onTap: () => setState(() => _selected = _HomeSection.dashboard),
                ),
                const SizedBox(height: 12),
                _SidebarItem(
                  icon: Icons.apartment_outlined,
                  label: 'WHS-Tours',
                  selected: _selected == _HomeSection.whsTours,
                  onTap: () => setState(() => _selected = _HomeSection.whsTours),
                ),
                const SizedBox(height: 12),
                _SidebarItem(
                  icon: Icons.info_outline_rounded,
                  label: 'OVA',
                  selected: _selected == _HomeSection.ova,
                  onTap: () => setState(() => _selected = _HomeSection.ova),
                ),
                const SizedBox(height: 12),
                _SidebarItem(
                  icon: Icons.build,
                  label: 'Onderhoud\nKeuringen',
                  selected: _selected == _HomeSection.onderhoud,
                  onTap: () => setState(() => _selected = _HomeSection.onderhoud),
                ),
                const SizedBox(height: 12),
                _SidebarItem(
                  icon: Icons.assignment,
                  label: 'JAP & GPP',
                  selected: _selected == _HomeSection.japGpp,
                  onTap: () => setState(() => _selected = _HomeSection.japGpp),
                ),
                const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: _buildSectionContent(_selected),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContent(_HomeSection section) {
    switch (section) {
      case _HomeSection.dashboard:
        return _DashboardContent();
      case _HomeSection.whsTours:
        return const Center(child: Text('WHS-Tours'));
      case _HomeSection.ova:
        return const OvaDashboardScreen();
      case _HomeSection.onderhoud:
        return const Center(child: Text('Onderhoud & Keuringen'));
      case _HomeSection.japGpp:
        return const Center(child: Text('JAP & GPP'));
    }
  }
}

class _DashboardContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final user = authService.user;
        if (user == null) {
          return const Center(child: Text('No user data available'));
        }

        final canOpenOva = user.isAdmin || user.access.basis || user.access.ova;
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
                      Text('Email: 24{user.email}'),
                      if (user.name != null && user.name!.isNotEmpty)
                        Text('Name: 24{user.name}'),
                      Text('User ID: 24{user.id}'),
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
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
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
                                      final state = context.findAncestorStateOfType<_HomeScreenState>();
                                      state?.setState(() {
                                        state._selected = _HomeSection.ova;
                                      });
                                    }
                                  : null,
                              icon: const Icon(
                                Icons.radio_button_checked,
                              ),
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
                                    builder: (context) => const DepartmentsScreen(),
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
                                    builder: (context) => const AccountManagementScreen(),
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
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? HomeScreen._sidebarSelected : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: HomeScreen._sidebarText, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                color: HomeScreen._sidebarText,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
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


