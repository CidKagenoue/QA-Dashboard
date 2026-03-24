import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import 'account_management_screen.dart';
import 'login_screen.dart';

enum _AppSection {
  profile,
  notifications,
  accountManagement,
  departments,
  locations,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  _AppSection _selectedSection = _AppSection.accountManagement;

  Future<void> _handleLogout(AuthService authService) async {
    await authService.logout();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _selectSection(_AppSection section) {
    setState(() {
      _selectedSection = section;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final currentUser = authService.user;
    final isDesktopLayout = MediaQuery.of(context).size.width >= 940;
    final effectiveSection = authService.canManageAccounts
        ? _selectedSection
        : _selectedSection == _AppSection.accountManagement
        ? _AppSection.profile
        : _selectedSection;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF3F4EE),
      drawer: isDesktopLayout
          ? null
          : Drawer(
              child: _Sidebar(
                currentUserName: currentUser?.displayName ?? 'Gebruiker',
                currentUserEmail: currentUser?.email ?? '',
                canManageAccounts: authService.canManageAccounts,
                selectedSection: effectiveSection,
                onSelectSection: (section) {
                  Navigator.of(context).maybePop();
                  _selectSection(section);
                },
              ),
            ),
      body: Column(
        children: [
          _TopBar(
            onMenuPressed: isDesktopLayout
                ? null
                : () => _scaffoldKey.currentState?.openDrawer(),
            onNotificationsPressed: () =>
                _selectSection(_AppSection.notifications),
            onSettingsPressed: authService.canManageAccounts
                ? () => _selectSection(_AppSection.accountManagement)
                : null,
            onLogoutPressed: () => _handleLogout(authService),
          ),
          Expanded(
            child: Row(
              children: [
                if (isDesktopLayout)
                  _Sidebar(
                    currentUserName: currentUser?.displayName ?? 'Gebruiker',
                    currentUserEmail: currentUser?.email ?? '',
                    canManageAccounts: authService.canManageAccounts,
                    selectedSection: effectiveSection,
                    onSelectSection: _selectSection,
                  ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        color: const Color(0xFFF8F9F4),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: KeyedSubtree(
                            key: ValueKey<_AppSection>(effectiveSection),
                            child: _buildSectionContent(
                              effectiveSection,
                              authService.canManageAccounts,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContent(_AppSection section, bool canManageAccounts) {
    switch (section) {
      case _AppSection.accountManagement:
        if (!canManageAccounts) {
          return const _PlaceholderSection(
            title: 'Geen toegang',
            description:
                'Alleen admins kunnen Accountbeheer openen en gebruikersrechten beheren.',
            icon: Icons.lock_outline,
          );
        }

        return const AccountManagementScreen();
      case _AppSection.profile:
        return const _PlaceholderSection(
          title: 'Profiel',
          description:
              'Persoonlijke instellingen en profielinformatie kunnen hier worden beheerd.',
          icon: Icons.person_outline,
        );
      case _AppSection.notifications:
        return const _PlaceholderSection(
          title: 'Meldingen',
          description:
              'Hier komt het overzicht van systeemmeldingen en belangrijke updates.',
          icon: Icons.notifications_none,
        );
      case _AppSection.departments:
        return const _PlaceholderSection(
          title: 'Afdelingen',
          description:
              'Afdelingenbeheer is nog niet uitgewerkt in deze iteratie.',
          icon: Icons.apartment_outlined,
        );
      case _AppSection.locations:
        return const _PlaceholderSection(
          title: 'Locaties',
          description:
              'Locatiebeheer kan in een volgende stap op dezelfde shell worden aangesloten.',
          icon: Icons.location_on_outlined,
        );
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onNotificationsPressed,
    required this.onLogoutPressed,
    this.onMenuPressed,
    this.onSettingsPressed,
  });

  final VoidCallback onNotificationsPressed;
  final VoidCallback onLogoutPressed;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF88C63F), Color(0xFF97CF46)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              IconButton(
                onPressed: onMenuPressed,
                icon: const Icon(
                  Icons.menu_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Vlotter',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onNotificationsPressed,
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              IconButton(
                onPressed: onSettingsPressed,
                icon: const Icon(
                  Icons.settings_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              IconButton(
                onPressed: onLogoutPressed,
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.currentUserName,
    required this.currentUserEmail,
    required this.canManageAccounts,
    required this.selectedSection,
    required this.onSelectSection,
  });

  final String currentUserName;
  final String currentUserEmail;
  final bool canManageAccounts;
  final _AppSection selectedSection;
  final ValueChanged<_AppSection> onSelectSection;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 228,
      decoration: const BoxDecoration(
        color: Color(0xFFE3E4DE),
        border: Border(right: BorderSide(color: Color(0xFFD1D5CD))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 26),
          _SidebarItem(
            label: 'Profiel',
            icon: Icons.person_outline,
            isSelected: selectedSection == _AppSection.profile,
            onTap: () => onSelectSection(_AppSection.profile),
          ),
          _SidebarItem(
            label: 'Meldingen',
            icon: Icons.notifications_none,
            isSelected: selectedSection == _AppSection.notifications,
            onTap: () => onSelectSection(_AppSection.notifications),
          ),
          _SidebarItem(
            label: 'Accountbeheer',
            icon: Icons.manage_accounts_outlined,
            isSelected: selectedSection == _AppSection.accountManagement,
            isEnabled: canManageAccounts,
            onTap: canManageAccounts
                ? () => onSelectSection(_AppSection.accountManagement)
                : null,
          ),
          _SidebarItem(
            label: 'Afdelingen',
            icon: Icons.apartment_outlined,
            isSelected: selectedSection == _AppSection.departments,
            onTap: () => onSelectSection(_AppSection.departments),
          ),
          _SidebarItem(
            label: 'Locaties',
            icon: Icons.location_on_outlined,
            isSelected: selectedSection == _AppSection.locations,
            onTap: () => onSelectSection(_AppSection.locations),
          ),
          const Spacer(),
          Container(
            margin: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD1D5CD)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFEDF2E1),
                  foregroundColor: const Color(0xFF5E6B4A),
                  child: Text(
                    currentUserName.trim().isEmpty
                        ? '?'
                        : currentUserName.trim()[0].toUpperCase(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentUserName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2B3424),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentUserEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF636B60),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.onTap,
    this.isEnabled = true,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isSelected
        ? const Color(0xFFCBDAB7)
        : Colors.transparent;
    final foregroundColor = isEnabled
        ? const Color(0xFF40483C)
        : const Color(0xFF9AA394);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: foregroundColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: foregroundColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderSection extends StatelessWidget {
  const _PlaceholderSection({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: const Color(0xFF7EB83B)),
                const SizedBox(height: 18),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
