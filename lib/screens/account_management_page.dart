import 'package:flutter/material.dart';

import 'account_management_screen.dart';
import 'departments_screen.dart';
import 'locations_screen.dart';
import 'profile_screen.dart';

class AccountManagementPage extends StatelessWidget {
  const AccountManagementPage({super.key});

  static const _green = Color(0xFF7CB342);

  Route _buildSmoothRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, animation, secondaryAnimation) => page,
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-0.04, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text(
          'Vlotter',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: 180,
              color: const Color(0xFFE6E6E6),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SidebarItem(
                    'Profiel',
                    onTap: () => Navigator.of(
                      context,
                    ).pushReplacement(_buildSmoothRoute(const ProfileScreen())),
                  ),
                  const SizedBox(height: 20),
                  const _SidebarItem('Meldingen'),
                  const SizedBox(height: 20),
                  const _SidebarItem('Accountbeheer', selected: true),
                  const SizedBox(height: 20),
                  _SidebarItem(
                    'Afdelingen',
                    onTap: () => Navigator.of(context).pushReplacement(
                      _buildSmoothRoute(const DepartmentsScreen()),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SidebarItem(
                    'Locaties',
                    onTap: () => Navigator.of(context).pushReplacement(
                      _buildSmoothRoute(const LocationsScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(child: AccountManagementScreen()),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback? onTap;

  const _SidebarItem(this.title, {this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            color: selected ? Colors.black : Colors.black54,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
