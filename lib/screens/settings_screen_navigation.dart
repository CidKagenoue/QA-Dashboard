import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qa_dashboard/screens/login_screen.dart';
import 'package:qa_dashboard/screens/profile_screen.dart';
import 'package:qa_dashboard/screens/departments_screen.dart';
import 'package:qa_dashboard/screens/locations_screen.dart';
import 'package:qa_dashboard/screens/account_management_screen.dart';
import 'package:qa_dashboard/services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenNavigationState();
}

enum _SettingsSection {
  profiel,
  meldingen,
  accountbeheer,
  afdelingen,
  locaties,
}

class _SettingsScreenNavigationState extends State<SettingsScreen> {
  _SettingsSection _selected = _SettingsSection.profiel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF8BC34A),
        foregroundColor: Colors.white,
        title: const Text('Vlotter', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          Consumer<AuthService>(
            builder: (context, authService, child) {
              return IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
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
      body: Row(
        children: [
          Container(
            width: 220,
            color: const Color(0xFFE6E6E6),
            height: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  _SidebarItem(
                    icon: Icons.person,
                    title: 'Profiel',
                    selected: _selected == _SettingsSection.profiel,
                    onTap: () =>
                        setState(() => _selected = _SettingsSection.profiel),
                  ),
                  const SizedBox(height: 20),
                  _SidebarItem(
                    icon: Icons.notifications,
                    title: 'Meldingen',
                    selected: _selected == _SettingsSection.meldingen,
                    onTap: () =>
                        setState(() => _selected = _SettingsSection.meldingen),
                  ),
                  const SizedBox(height: 20),
                  _SidebarItem(
                    icon: Icons.manage_accounts,
                    title: 'Accountbeheer',
                    selected: _selected == _SettingsSection.accountbeheer,
                    onTap: () => setState(
                      () => _selected = _SettingsSection.accountbeheer,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SidebarItem(
                    icon: Icons.apartment,
                    title: 'Afdelingen',
                    selected: _selected == _SettingsSection.afdelingen,
                    onTap: () =>
                        setState(() => _selected = _SettingsSection.afdelingen),
                  ),
                  const SizedBox(height: 20),
                  _SidebarItem(
                    icon: Icons.location_on,
                    title: 'Locaties',
                    selected: _selected == _SettingsSection.locaties,
                    onTap: () =>
                        setState(() => _selected = _SettingsSection.locaties),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
          // Remove Expanded to avoid ParentDataWidget error
          Expanded(
            child: Center(child: _buildSectionContent(_selected)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContent(_SettingsSection section) {
    switch (section) {
      case _SettingsSection.profiel:
        return const ProfileScreen();
      case _SettingsSection.meldingen:
        return const Text('Meldingen (hier komen je notificaties)');
      case _SettingsSection.accountbeheer:
        return AccountManagementScreen();
      case _SettingsSection.afdelingen:
        return DepartmentsScreen();
      case _SettingsSection.locaties:
        return LocationsScreen();
    }
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback? onTap;

  const _SidebarItem({
    required this.icon,
    required this.title,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconColor = selected
        ? const Color(0xFF7CB342)
        : Colors.grey.shade400;
    final Color textColor = selected ? Colors.black : Colors.grey.shade600;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: textColor,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
