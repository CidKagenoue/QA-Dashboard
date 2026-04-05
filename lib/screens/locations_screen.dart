import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qa_dashboard/models/branch.dart';

import '../services/auth_service.dart';
import '../services/location_api_service.dart';
import '../models/location.dart';
import 'profile_screen.dart';
import 'departments_screen.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  List<Branch> _branches = [];
  Branch? _selected;
  bool _isLoading = false;

  static const _green = Color(0xFF7CB342);

  Route _buildSmoothRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, animation, __) => page,
      transitionsBuilder: (_, animation, __, child) {
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
  void initState() {
    super.initState();
    if (_hasAdminAccess()) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      final token = await auth.getValidAccessToken();
      final branches = await LocationApiService.getBranches(token);
      if (!mounted) return;
      setState(() {
        _branches = branches;
        if (_selected != null) {
          _selected = _branches.firstWhere(
            (b) => b.id == _selected!.id,
            orElse: () => _branches.isNotEmpty ? _branches.first : _selected!,
          );
        } else if (_branches.isNotEmpty) {
          _selected = _branches.first;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij laden: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _hasAdminAccess() {
    final auth = Provider.of<AuthService>(context, listen: false);
    return auth.user?.isAdmin ?? false;
  }

  // ── Vestiging toevoegen / bewerken ────────────────────────────────────────
  Future<void> _openBranchDialog({Branch? branch}) async {
    final controller = TextEditingController(text: branch?.name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            branch == null ? 'Vestiging toevoegen' : 'Vestiging bewerken'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Naam vestiging',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _green),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.of(ctx).pop(name);
            },
            child:
                const Text('Opslaan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result != null) {
      await _saveBranch(id: branch?.id, name: result);
    }
  }

  // ── Vestiging verwijderen ─────────────────────────────────────────────────
  Future<void> _deleteBranch(Branch branch) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vestiging verwijderen'),
        content: Text('Wil je "${branch.name}" verwijderen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Verwijderen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final auth = Provider.of<AuthService>(context, listen: false);
        final token = await auth.getValidAccessToken();
        await LocationApiService.deleteBranch(token: token, id: branch.id);
        if (!mounted) return;
        if (_selected?.id == branch.id) _selected = null;
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fout bij verwijderen: $e')),
          );
        }
      }
    }
  }

  Future<void> _saveBranch({int? id, required String name}) async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final token = await auth.getValidAccessToken();
      final saved = await LocationApiService.saveBranch(
          token: token, id: id, name: name);
      await _loadData();
      if (!mounted) return;
      setState(() {
        _selected = _branches.firstWhere(
          (b) => b.id == saved.id,
          orElse: () => _branches.isNotEmpty ? _branches.first : _selected!,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout: $e'), duration: const Duration(seconds: 10)),
        );
      }
    }
  }

  // ── Locatie toevoegen / bewerken ──────────────────────────────────────────
  Future<void> _openLocationDialog({Location? location}) async {
    final controller = TextEditingController(text: location?.name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            location == null ? 'Locatie toevoegen' : 'Locatie bewerken'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Naam locatie',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _green),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.of(ctx).pop(name);
            },
            child:
                const Text('Opslaan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result != null && _selected != null) {
      await _saveLocation(
          id: location?.id, name: result, branchId: _selected!.id);
    }
  }

  // ── Locatie verwijderen ───────────────────────────────────────────────────
  Future<void> _deleteLocation(Location location) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Locatie verwijderen'),
        content: Text('Wil je "${location.name}" verwijderen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Verwijderen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final auth = Provider.of<AuthService>(context, listen: false);
        final token = await auth.getValidAccessToken();
        await LocationApiService.deleteLocation(token: token, id: location.id);
        if (!mounted) return;
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fout bij verwijderen: $e')),
          );
        }
      }
    }
  }

  Future<void> _saveLocation(
    {int? id, required String name, required int branchId}) async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final token = await auth.getValidAccessToken();
      await LocationApiService.saveLocation(
          token: token, id: id, name: name, branchId: branchId);
      if (!mounted) return;
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij opslaan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManageLocations = context.watch<AuthService>().user?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text(
          'Vlotter',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {}),
          IconButton(
              icon: const Icon(Icons.settings_outlined), onPressed: () {}),
        ],
      ),
      body: SafeArea(
        child: Row(
          children: [
            // ── Sidebar ───────────────────────────────────────────────────
            Container(
              width: 180,
              color: const Color(0xFFE6E6E6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SidebarItem('Profiel',
                      onTap: () => Navigator.of(context).pushReplacement(
                          _buildSmoothRoute(const ProfileScreen()))),
                  const SizedBox(height: 20),
                  const _SidebarItem('Meldingen'),
                  const SizedBox(height: 20),
                  const _SidebarItem('Accountbeheer'),
                  const SizedBox(height: 20),
                  _SidebarItem('Afdelingen',
                      onTap: () => Navigator.of(context).pushReplacement(
                          _buildSmoothRoute(const DepartmentsScreen()))),
                  const SizedBox(height: 20),
                  const _SidebarItem('Locaties', selected: true),
                ],
              ),
            ),
            // ── Main content ──────────────────────────────────────────────
            Expanded(
              child: !canManageLocations
                  ? _buildAccessDeniedState(
                      title: 'Locaties beheren is alleen beschikbaar voor admins.',
                      description:
                          'Log in met een admin-account om vestigingen en locaties te bekijken en te wijzigen.',
                    )
                  : _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildBranchesCard()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildLocationsCard()),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchesCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: const [
              // ✅ FIX: "Branches" → "Vestigingen"
              Text('Vestigingen',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _branches.length,
              itemBuilder: (context, index) {
                final branch = _branches[index];
                final isSelected = _selected?.id == branch.id;
                return Container(
                  color: isSelected ? const Color(0xFFE8F5E9) : null,
                  child: ListTile(
                    dense: true,
                    title: Text(branch.name,
                        style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined,
                              size: 18,
                              color: isSelected
                                  ? Colors.black87
                                  : Colors.black38),
                          onPressed: () =>
                              _openBranchDialog(branch: branch),
                          tooltip: 'Bewerken',
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 18,
                              color: isSelected
                                  ? Colors.black87
                                  : Colors.black38),
                          onPressed: () => _deleteBranch(branch),
                          tooltip: 'Verwijderen',
                        ),
                      ],
                    ),
                    onTap: () => setState(() => _selected = branch),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerRight,
              child: FloatingActionButton.small(
                heroTag: 'add_branch',
                backgroundColor: _green,
                onPressed: () => _openBranchDialog(),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: const [
              Text('Locaties',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _selected == null
                ? const Center(
                    child: Text('Selecteer een vestiging',
                        style: TextStyle(color: Colors.black45)))
                : (_selected!.locations.isEmpty)
                    ? const Center(
                        child: Text('Geen locaties',
                            style: TextStyle(color: Colors.black45)))
                    : ListView.builder(
                        itemCount: _selected!.locations.length,
                        itemBuilder: (context, index) {
                          final location = _selected!.locations[index];
                          return ListTile(
                            dense: true,
                            title: Text(location.name),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18, color: Colors.black38),
                                  tooltip: 'Bewerken',
                                  onPressed: () =>
                                      _openLocationDialog(location: location),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18, color: Colors.black38),
                                  tooltip: 'Verwijderen',
                                  onPressed: () =>
                                      _deleteLocation(location),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerRight,
              child: FloatingActionButton.small(
                heroTag: 'add_location',
                backgroundColor: _green,
                onPressed: _branches.isEmpty ? null : () {
                  if (_selected == null && _branches.isNotEmpty) {
                    setState(() => _selected = _branches.first);
                  }
                  _openLocationDialog();
                },
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessDeniedState({
    required String title,
    required String description,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 48,
                    color: Color(0xFF7C8A72),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
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
