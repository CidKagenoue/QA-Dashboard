import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/department_api_service.dart';
import '../models/department.dart';
import 'profile_screen.dart';

class DepartmentsScreen extends StatefulWidget {
  const DepartmentsScreen({super.key});

  @override
  State<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends State<DepartmentsScreen> {
  List<Department> _departments = [];
  Department? _selected;
  bool _isLoading = false;

  Route _buildSmoothRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        final slide = Tween<Offset>(
          begin: const Offset(-0.04, 0),
          end: Offset.zero,
        ).animate(curved);

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: slide,
            child: child,
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      final token = await auth.getValidAccessToken();
      final departments =
          await DepartmentApiService.getDepartments(token);
      setState(() {
        _departments = departments;
        if (_departments.isNotEmpty) {
          _selected = _departments.first;
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openLeadersPopup() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final token = await auth.getValidAccessToken();
    final allUsers = await DepartmentApiService.getAllUsers(token);

    if (!mounted) {
      return;
    }

    final currentLeaderIds =
        _selected?.leaders.map((u) => u.id).toSet() ?? {};

    final result = await showDialog<Set<int>>(
      context: context,
      builder: (context) {
        final selectedIds = Set<int>.from(currentLeaderIds);
        final searchController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setState) {
            final query = searchController.text.toLowerCase();
            final filtered = allUsers.where((u) {
              if (query.isEmpty) return true;
              return (u.name ?? u.email).toLowerCase().contains(query);
            }).toList();

            return AlertDialog(
              title: const Text('Pop Up Leidinggevenden'),
              content: SizedBox(
                width: 300,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Zoeken',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final user = filtered[index];
                          final isSelected = selectedIds.contains(user.id);
                          return ListTile(
                            title: Text(user.name ?? user.email),
                            trailing: Icon(
                              Icons.circle,
                              size: 16,
                              color: isSelected
                                  ? const Color(0xFF7CB342)
                                  : Colors.grey[300],
                            ),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  selectedIds.remove(user.id);
                                } else {
                                  selectedIds.add(user.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuleren'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(selectedIds),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7CB342),
                  ),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && _selected != null) {
      await _saveDepartment(
        id: _selected!.id,
        name: _selected!.name,
        leaderIds: result.toList(),
      );
    }
  }

  Future<void> _saveDepartment({
    int? id,
    required String name,
    required List<int> leaderIds,
  }) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    setState(() => _isLoading = true);
    try {
      final token = await auth.getValidAccessToken();
      final saved = await DepartmentApiService.saveDepartment(
        token: token,
        id: id,
        name: name,
        leaderIds: leaderIds,
      );
      await _loadData();
      setState(() {
        _selected = _departments.firstWhere((d) => d.id == saved.id);
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7CB342),
        foregroundColor: Colors.white,
        title: const Text(
          'vlotter',
          style: TextStyle(color: Colors.white),
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
              width: 220,
              color: const Color(0xFFE6E6E6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SidebarItem(
                      'Profiel',
                      onTap: () {
                        Navigator.of(context).pushReplacement(_buildSmoothRoute(const AccountScreen()));
                      },
                    ),
                    const SizedBox(height: 20),
                    const _SidebarItem('Meldingen'),
                    const SizedBox(height: 20),
                    const _SidebarItem('Accountbeheer'),
                    const SizedBox(height: 20),
                    const _SidebarItem('Afdelingen', selected: true),
                    const SizedBox(height: 20),
                    const _SidebarItem('Locaties'),
                  ],
                ),
              ),
            ),

            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1600),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Row(
                            children: [
                              Expanded(
                                child: Card(
                                  child: Column(
                                    children: [
                                      const ListTile(
                                        title: Text('Afdelingen'),
                                      ),
                                      const Divider(height: 1),
                                      Expanded(
                                        child: ListView.builder(
                                          itemCount: _departments.length,
                                          itemBuilder: (context, index) {
                                            final dept = _departments[index];
                                            final selected = _selected?.id == dept.id;
                                            return ListTile(
                                              selected: selected,
                                              title: Text(dept.name),
                                              onTap: () {
                                                setState(() => _selected = dept);
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Card(
                                  child: Column(
                                    children: [
                                      ListTile(
                                        title: const Text('Leidinggevenden'),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.add),
                                          onPressed: _selected == null ? null : _openLeadersPopup,
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      Expanded(
                                        child: _selected == null
                                            ? const Center(
                                                child: Text('Geen afdeling geselecteerd'),
                                              )
                                            : ListView.builder(
                                                itemCount: _selected!.leaders.length,
                                                itemBuilder: (context, index) {
                                                  final leader = _selected!.leaders[index];
                                                  return ListTile(
                                                    title: Text(leader.name ?? leader.email),
                                                    trailing: IconButton(
                                                      icon: const Icon(Icons.delete_outline),
                                                      onPressed: () async {
                                                        final remaining = _selected!.leaders
                                                            .where((u) => u.id != leader.id)
                                                            .map((u) => u.id)
                                                            .toList();
                                                        await _saveDepartment(
                                                          id: _selected!.id,
                                                          name: _selected!.name,
                                                          leaderIds: remaining,
                                                        );
                                                      },
                                                    ),
                                                  );
                                                },
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
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
            fontSize: 16,
            color: selected ? Colors.black : Colors.black54,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}