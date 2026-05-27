import 'package:flutter/material.dart';
import 'package:qa_dashboard/screens/profile_screen.dart';
import 'package:qa_dashboard/screens/departments_screen.dart';
import 'package:qa_dashboard/screens/locations_screen.dart';
import 'package:qa_dashboard/screens/account_management_screen.dart';
import 'package:qa_dashboard/screens/notifications_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bars/main_app_bar.dart';
import '../widgets/design/app_breadcrumb.dart';
import '../widgets/resizable_sidebar.dart';

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
      appBar: const MainAppBar(title: 'Vlotter'),
      body: AppBreadcrumbNavigation(
        onNavigateTo: _navigateFromBreadcrumb,
        child: Row(
          children: [
            ResizableSidebar(
              title: 'INSTELLINGEN',
              storageKey: 'settingsSidebar',
              defaultWidth: 240,
              childBuilder: (context, expanded) => Column(
                children: [
                  _SidebarItem(
                    icon: Icons.person_outline_rounded,
                    title: 'Profiel',
                    expanded: expanded,
                    selected: _selected == _SettingsSection.profiel,
                    onTap: () =>
                        setState(() => _selected = _SettingsSection.profiel),
                  ),
                  _SidebarItem(
                    icon: Icons.notifications_none_rounded,
                    title: 'Meldingen',
                    expanded: expanded,
                    selected: _selected == _SettingsSection.meldingen,
                    onTap: () =>
                        setState(() => _selected = _SettingsSection.meldingen),
                  ),
                  _SidebarItem(
                    icon: Icons.manage_accounts_outlined,
                    title: 'Accountbeheer',
                    expanded: expanded,
                    selected: _selected == _SettingsSection.accountbeheer,
                    onTap: () => setState(
                      () => _selected = _SettingsSection.accountbeheer,
                    ),
                  ),
                  _SidebarItem(
                    icon: Icons.apartment_rounded,
                    title: 'Afdelingen',
                    expanded: expanded,
                    selected: _selected == _SettingsSection.afdelingen,
                    onTap: () =>
                        setState(() => _selected = _SettingsSection.afdelingen),
                  ),
                  _SidebarItem(
                    icon: Icons.place_outlined,
                    title: 'Locaties',
                    expanded: expanded,
                    selected: _selected == _SettingsSection.locaties,
                    onTap: () =>
                        setState(() => _selected = _SettingsSection.locaties),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Expanded(child: _buildSectionContent(_selected)),
          ],
        ),
      ),
    );
  }

  void _navigateFromBreadcrumb(String key) {
    setState(() {
      switch (key) {
        case 'settings':
        case 'settingsProfile':
          _selected = _SettingsSection.profiel;
          break;
        case 'settingsNotifications':
          _selected = _SettingsSection.meldingen;
          break;
        case 'settingsAccounts':
          _selected = _SettingsSection.accountbeheer;
          break;
        case 'settingsDepartments':
          _selected = _SettingsSection.afdelingen;
          break;
        case 'settingsLocations':
          _selected = _SettingsSection.locaties;
          break;
      }
    });
  }

  Widget _buildSectionContent(_SettingsSection section) {
    switch (section) {
      case _SettingsSection.profiel:
        return const ProfileScreen();
      case _SettingsSection.meldingen:
        return const NotificationsScreen();
      case _SettingsSection.accountbeheer:
        return const AccountManagementScreen();
      case _SettingsSection.afdelingen:
        return const DepartmentsScreen();
      case _SettingsSection.locaties:
        return const LocationsScreen();
    }
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool expanded;
  final bool selected;
  final VoidCallback? onTap;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.expanded,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? kBrandGreenDeep : kTextSecondary;
    final bg = selected ? kBrandGreenSoft : Colors.transparent;
    final borderColor = selected ? kBrandGreenSoft : Colors.transparent;

    final item = Padding(
      padding: EdgeInsets.fromLTRB(12, 2, expanded ? 12 : 10, 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadiusMd),
          hoverColor: selected ? kBrandGreenSubtle : kSurfaceHover,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(kRadiusMd),
            ),
            child: Row(
              mainAxisAlignment:
                  expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(icon, color: fg, size: 20),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (selected)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: kBrandGreenDeep,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Tooltip(message: title, child: item);
  }
}
