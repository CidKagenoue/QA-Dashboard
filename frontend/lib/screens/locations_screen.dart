import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qa_dashboard/models/branch.dart';

import '../services/auth_service.dart';
import '../services/location_api_service.dart';
import '../models/location.dart';
import '../widgets/design/design_system.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  List<Branch> _branches = [];
  Branch? _selected;
  bool _isLoading = false;

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fout bij laden: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _hasAdminAccess() {
    final auth = Provider.of<AuthService>(context, listen: false);
    return auth.user?.isAdmin ?? false;
  }

  Future<void> _openBranchDialog({Branch? branch}) async {
    final controller = TextEditingController(text: branch?.name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          branch == null ? 'Vestiging toevoegen' : 'Vestiging bewerken',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Naam vestiging'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.of(ctx).pop(name);
            },
            child: const Text('Opslaan'),
          ),
        ],
      ),
    );
    if (result != null) {
      await _saveBranch(id: branch?.id, name: result);
    }
  }

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
            style: ElevatedButton.styleFrom(backgroundColor: kDanger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Verwijderen'),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fout bij verwijderen: $e')));
        }
      }
    }
  }

  Future<void> _saveBranch({int? id, required String name}) async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final token = await auth.getValidAccessToken();
      final saved = await LocationApiService.saveBranch(
        token: token,
        id: id,
        name: name,
      );
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
          SnackBar(
            content: Text('Fout: $e'),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  Future<void> _openLocationDialog({Location? location}) async {
    final controller = TextEditingController(text: location?.name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          location == null ? 'Locatie toevoegen' : 'Locatie bewerken',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Naam locatie'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.of(ctx).pop(name);
            },
            child: const Text('Opslaan'),
          ),
        ],
      ),
    );
    if (result != null && _selected != null) {
      await _saveLocation(
        id: location?.id,
        name: result,
        branchId: _selected!.id,
      );
    }
  }

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
            style: ElevatedButton.styleFrom(backgroundColor: kDanger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Verwijderen'),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fout bij verwijderen: $e')));
        }
      }
    }
  }

  Future<void> _saveLocation({
    int? id,
    required String name,
    required int branchId,
  }) async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final token = await auth.getValidAccessToken();
      await LocationApiService.saveLocation(
        token: token,
        id: id,
        name: name,
        branchId: branchId,
      );
      if (!mounted) return;
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fout bij opslaan: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManageLocations =
        context.watch<AuthService>().user?.isAdmin ?? false;

    if (!canManageLocations) {
      return Container(
        color: kBackground,
        padding: const EdgeInsets.all(32),
        child: Center(
          child: AppEmptyState.emphasis(
            icon: Icons.lock_outline_rounded,
            title: 'Geen toegang tot Locaties',
            message:
                'Locaties beheren is alleen beschikbaar voor admins. Log in met een admin-account om vestigingen en locaties te bekijken en te wijzigen.',
          ),
        ),
      );
    }

    return Container(
      color: kBackground,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
        child: Container(
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(kRadius2xl),
            border: Border.all(color: kBorder),
          ),
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppBreadcrumb(segments: ['Instellingen', 'Locaties']),
              const SizedBox(height: 16),
              const Text(
                'Locaties',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                  letterSpacing: -0.4,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Beheer vestigingen en de locaties die eronder vallen.',
                style: TextStyle(
                  fontSize: 14.5,
                  color: kTextSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const SizedBox(
                  height: 320,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 880;
                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBranchesPanel(),
                          const SizedBox(height: 16),
                          _buildLocationsPanel(),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildBranchesPanel()),
                        const SizedBox(width: 16),
                        Expanded(child: _buildLocationsPanel()),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBranchesPanel() {
    return AppSectionPanel(
      title: 'Vestigingen',
      icon: Icons.business_outlined,
      trailing: IconButton(
        icon: const Icon(Icons.add_rounded, size: 20),
        tooltip: 'Vestiging toevoegen',
        color: kBrandGreenDeep,
        onPressed: () => _openBranchDialog(),
      ),
      child: _branches.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Nog geen vestigingen toegevoegd.',
                style: TextStyle(fontSize: 13.5, color: kTextTertiary),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                color: kSurfaceMuted,
                borderRadius: BorderRadius.circular(kRadiusMd),
                border: Border.all(color: kBorder),
              ),
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _branches.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: kBorderSubtle),
                itemBuilder: (context, index) {
                  final branch = _branches[index];
                  final isSelected = _selected?.id == branch.id;
                  return Material(
                    color:
                        isSelected ? kBrandGreenSubtle : Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _selected = branch),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_city_rounded,
                              size: 18,
                              color: isSelected
                                  ? kBrandGreenDeep
                                  : kTextTertiary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                branch.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? kBrandGreenDeep
                                      : kTextPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.edit_outlined, size: 18),
                              color: kTextTertiary,
                              onPressed: () =>
                                  _openBranchDialog(branch: branch),
                              tooltip: 'Bewerken',
                            ),
                            IconButton(
                              icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18),
                              color: kDanger,
                              onPressed: () => _deleteBranch(branch),
                              tooltip: 'Verwijderen',
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildLocationsPanel() {
    final locations = _selected?.locations ?? const <Location>[];

    return AppSectionPanel(
      title: 'Locaties',
      icon: Icons.place_outlined,
      trailing: IconButton(
        icon: const Icon(Icons.add_rounded, size: 20),
        tooltip: 'Locatie toevoegen',
        color: kBrandGreenDeep,
        onPressed: _branches.isEmpty
            ? null
            : () {
                if (_selected == null && _branches.isNotEmpty) {
                  setState(() => _selected = _branches.first);
                }
                _openLocationDialog();
              },
      ),
      child: _selected == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Selecteer eerst een vestiging om de locaties te zien.',
                style: TextStyle(fontSize: 13.5, color: kTextTertiary),
              ),
            )
          : locations.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'Nog geen locaties gekoppeld aan deze vestiging.',
                    style: TextStyle(fontSize: 13.5, color: kTextTertiary),
                  ),
                )
              : Column(
                  children: List.generate(locations.length, (index) {
                    final location = locations[index];
                    return Container(
                      margin: EdgeInsets.only(
                          bottom: index == locations.length - 1 ? 0 : 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: kSurfaceMuted,
                        borderRadius: BorderRadius.circular(kRadiusMd),
                        border: Border.all(color: kBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: kBrandGreenSoft,
                              borderRadius:
                                  BorderRadius.circular(kRadiusSm),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.place_outlined,
                                size: 16, color: kBrandGreenDeep),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              location.name,
                              style: const TextStyle(
                                fontSize: 14,
                                color: kTextPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            color: kTextTertiary,
                            tooltip: 'Bewerken',
                            onPressed: () =>
                                _openLocationDialog(location: location),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18),
                            color: kDanger,
                            tooltip: 'Verwijderen',
                            onPressed: () => _deleteLocation(location),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
    );
  }
}
