import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qa_dashboard/models/branch.dart';

import '../services/auth_service.dart';
import '../services/branch_api_service.dart';
import '../widgets/design/design_system.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  List<Branch> _branches = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (_hasAdminAccess()) {
      _loadData();
    }
  }

  bool _hasAdminAccess() {
    final auth = Provider.of<AuthService>(context, listen: false);
    return auth.user?.isAdmin ?? false;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      final token = await auth.getValidAccessToken();
      final branches = await BranchApiService.getBranches(token);
      if (!mounted) return;
      setState(() => _branches = branches);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fout bij laden: $error')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openBranchDialog({Branch? branch}) async {
    final controller = TextEditingController(text: branch?.name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.of(context).pop(name);
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

  Future<void> _saveBranch({int? id, required String name}) async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final token = await auth.getValidAccessToken();
      await BranchApiService.saveBranch(token: token, id: id, name: name);
      await _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout: $error'),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  Future<void> _deleteBranch(Branch branch) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vestiging verwijderen'),
        content: Text('Wil je "${branch.name}" verwijderen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kDanger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final token = await auth.getValidAccessToken();
      await BranchApiService.deleteBranch(token: token, id: branch.id);
      await _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fout bij verwijderen: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManageBranches =
        context.watch<AuthService>().user?.isAdmin ?? false;

    if (!canManageBranches) {
      return Container(
        color: kBackground,
        padding: const EdgeInsets.all(32),
        child: Center(
          child: AppEmptyState.emphasis(
            icon: Icons.lock_outline_rounded,
            title: 'Geen toegang tot Locaties',
            message:
                'Vestigingen beheren is alleen beschikbaar voor admins. Log in met een admin-account om vestigingen te bekijken en te wijzigen.',
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
                'Beheer vestigingen.',
                style: TextStyle(
                  fontSize: 14.5,
                  color: kTextSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _buildBranchesPanel(),
                  ),
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
        icon: const Icon(Icons.add_rounded, size: 26),
        tooltip: 'Vestiging toevoegen',
        color: kBrandGreenDeep,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(42),
          backgroundColor: kBrandGreenSubtle,
        ),
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_city_rounded,
                          size: 18,
                          color: kBrandGreenDeep,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            branch.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          color: kTextTertiary,
                          onPressed: () => _openBranchDialog(branch: branch),
                          tooltip: 'Bewerken',
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          color: kDanger,
                          onPressed: () => _deleteBranch(branch),
                          tooltip: 'Verwijderen',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
