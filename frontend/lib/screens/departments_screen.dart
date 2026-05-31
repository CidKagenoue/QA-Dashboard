import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qa_dashboard/models/branch.dart';
import '../services/auth_service.dart';
import '../services/department_api_service.dart';
import '../services/branch_api_service.dart';
import '../models/department.dart';
import '../models/user.dart';
import '../widgets/design/design_system.dart';

class DepartmentsScreen extends StatefulWidget {
  const DepartmentsScreen({super.key});

  @override
  State<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends State<DepartmentsScreen> {
  List<Department> _departments = [];
  List<Branch> _branches = [];
  Department? _selected;
  Branch? _selectedBranch;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (_hasAdminAccess()) {
      _loadData();
    }
  }

  void _showError(String prefix, Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$prefix: $error')));
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
      final results = await Future.wait<dynamic>([
        DepartmentApiService.getDepartments(token),
        BranchApiService.getBranches(token),
      ]);
      final departments = results[0] as List<Department>;
      final branches = results[1] as List<Branch>;
      if (!mounted) return;
      setState(() {
        _departments = departments;
        _branches = branches;
        if (_selectedBranch != null) {
          _selectedBranch = _branches.firstWhere(
            (b) => b.id == _selectedBranch!.id,
            orElse: () =>
                _branches.isNotEmpty ? _branches.first : _selectedBranch!,
          );
        } else if (_branches.isNotEmpty) {
          _selectedBranch = _branches.first;
        }
        _syncSelectedDepartment();
      });
    } catch (e) {
      _showError('Fout bij laden', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openDepartmentDialog({Department? dept}) async {
    final controller = TextEditingController(text: dept?.name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(dept == null ? 'Afdeling toevoegen' : 'Afdeling bewerken'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Naam afdeling'),
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
      await _saveDepartment(
        id: dept?.id,
        name: result,
        leaderIds: dept?.leaders.map((u) => u.id).toList() ?? [],
        linkToSelectedBranch: dept == null,
      );
    }
  }

  Future<void> _deleteDepartment(Department dept) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Afdeling verwijderen'),
        content: Text('Wil je "${dept.name}" verwijderen?'),
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
      setState(() => _isLoading = true);
      try {
        final token = await auth.getValidAccessToken();
        await DepartmentApiService.deleteDepartment(token: token, id: dept.id);
        if (_selected?.id == dept.id) {
          _selected = null;
        }
        await _loadData();
      } catch (e) {
        _showError('Fout bij verwijderen', e);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openLeadersPopup() async {
    if (_selected == null) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    final token = await auth.getValidAccessToken();

    List<User> allUsers = [];
    try {
      allUsers = await DepartmentApiService.getAllUsers(token);
    } catch (e) {
      _showError('Fout bij laden van gebruikers', e);
      return;
    }
    if (!mounted) return;

    final selected = <int>{..._selected!.leaders.map((u) => u.id)};
    final searchController = TextEditingController();

    final result = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final query = searchController.text.toLowerCase();
          final filtered = allUsers
              .where((u) => ((u.name ?? u.email)).toLowerCase().contains(query))
              .toList();

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadiusLg),
            ),
            child: SizedBox(
              width: 320,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Leidinggevenden kiezen',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary,
                        ),
                      ),
                    ),
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Zoeken op naam of e-mail',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: kTextTertiary,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: kBorderSubtle),
                        itemBuilder: (_, i) {
                          final user = filtered[i];
                          final isChecked = selected.contains(user.id);
                          return InkWell(
                            onTap: () => setDialogState(() {
                              if (isChecked) {
                                selected.remove(user.id);
                              } else {
                                selected.add(user.id);
                              }
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      (user.name ?? user.email),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: kTextPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: isChecked
                                          ? kBrandGreenDark
                                          : kSurfaceMuted,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isChecked
                                            ? kBrandGreenDark
                                            : kBorder,
                                      ),
                                    ),
                                    child: isChecked
                                        ? const Icon(
                                            Icons.check_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Annuleren'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.of(ctx).pop(selected.toList()),
                          child: const Text('Opslaan'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
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
    bool linkToSelectedBranch = false,
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

      if (linkToSelectedBranch && _selectedBranch != null) {
        final departmentIds = _selectedBranch!.departmentIds.toSet()
          ..add(saved.id);
        await BranchApiService.saveBranch(
          token: token,
          id: _selectedBranch!.id,
          name: _selectedBranch!.name,
          departmentIds: departmentIds.toList()..sort(),
        );
      }

      await _loadData();
      if (!mounted) return;
      setState(() {
        _selected = _visibleDepartments.firstWhere(
          (d) => d.id == saved.id,
          orElse: () => _visibleDepartments.isNotEmpty
              ? _visibleDepartments.first
              : saved,
        );
      });
    } catch (e) {
      _showError('Fout bij opslaan', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Department> get _visibleDepartments {
    final selectedBranch = _selectedBranch;
    if (selectedBranch == null) {
      return _departments;
    }

    final departmentIds = selectedBranch.departmentIds.toSet();
    return _departments.where((department) {
      return departmentIds.contains(department.id) &&
          department.name.trim().toLowerCase() != 'ander';
    }).toList();
  }

  void _syncSelectedDepartment() {
    final visibleDepartments = _visibleDepartments;
    if (_selected != null &&
        visibleDepartments.any(
          (department) => department.id == _selected!.id,
        )) {
      _selected = visibleDepartments.firstWhere(
        (department) => department.id == _selected!.id,
      );
      return;
    }

    _selected = visibleDepartments.isNotEmpty ? visibleDepartments.first : null;
  }

  void _selectBranch(int? branchId) {
    setState(() {
      _selectedBranch = branchId == null
          ? null
          : _branches.firstWhere(
              (branch) => branch.id == branchId,
              orElse: () => _branches.first,
            );
      _syncSelectedDepartment();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canManageDepartments =
        context.watch<AuthService>().user?.isAdmin ?? false;

    if (!canManageDepartments) {
      return Container(
        color: kBackground,
        padding: const EdgeInsets.all(32),
        child: Center(
          child: AppEmptyState.emphasis(
            icon: Icons.lock_outline_rounded,
            title: 'Geen toegang tot Afdelingen',
            message:
                'Afdelingen beheren is alleen beschikbaar voor admins. Log in met een admin-account om afdelingen en leidinggevenden te bekijken en te wijzigen.',
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
              const AppBreadcrumb(segments: ['Instellingen', 'Afdelingen']),
              const SizedBox(height: 16),
              const Text(
                'Afdelingen',
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
                'Beheer afdelingen per vestiging en wijs leidinggevenden toe.',
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
                          _buildDepartmentsPanel(),
                          const SizedBox(height: 16),
                          _buildLeadersPanel(),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildDepartmentsPanel()),
                        const SizedBox(width: 16),
                        Expanded(child: _buildLeadersPanel()),
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

  Widget _buildDepartmentsPanel() {
    final visibleDepartments = _visibleDepartments;

    return AppSectionPanel(
      title: 'Afdelingen per vestiging',
      icon: Icons.apartment_rounded,
      trailing: IconButton(
        icon: const Icon(Icons.add_rounded, size: 26),
        tooltip: 'Afdeling toevoegen',
        color: kBrandGreenDeep,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(42),
          backgroundColor: kBrandGreenSubtle,
        ),
        onPressed: _selectedBranch == null
            ? null
            : () => _openDepartmentDialog(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _selectedBranch?.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Vestiging',
              isDense: true,
            ),
            items: _branches
                .map(
                  (branch) => DropdownMenuItem<int>(
                    value: branch.id,
                    child: Text(branch.name),
                  ),
                )
                .toList(),
            onChanged: _branches.isEmpty ? null : _selectBranch,
          ),
          const SizedBox(height: 16),
          if (visibleDepartments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Geen afdelingen gekoppeld aan deze vestiging.',
                style: TextStyle(fontSize: 13.5, color: kTextTertiary),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: kSurfaceMuted,
                borderRadius: BorderRadius.circular(kRadiusMd),
                border: Border.all(color: kBorder),
              ),
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: visibleDepartments.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: kBorderSubtle),
                itemBuilder: (context, index) {
                  final dept = visibleDepartments[index];
                  final isSelected = _selected?.id == dept.id;
                  return Material(
                    color: isSelected ? kBrandGreenSubtle : Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _selected = dept),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.folder_open_rounded,
                              size: 18,
                              color: isSelected
                                  ? kBrandGreenDeep
                                  : kTextTertiary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                dept.name,
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
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              color: kTextTertiary,
                              onPressed: () =>
                                  _openDepartmentDialog(dept: dept),
                              tooltip: 'Bewerken',
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                              ),
                              color: kDanger,
                              onPressed: () => _deleteDepartment(dept),
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
        ],
      ),
    );
  }

  Widget _buildLeadersPanel() {
    final leaders = _selected?.leaders ?? const <User>[];
    return AppSectionPanel(
      title: 'Leidinggevenden',
      icon: Icons.supervisor_account_outlined,
      trailing: IconButton(
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 24),
        tooltip: 'Leidinggevenden kiezen',
        color: kBrandGreenDeep,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(42),
          backgroundColor: kBrandGreenSubtle,
        ),
        onPressed: _selected == null ? null : _openLeadersPopup,
      ),
      child: _selected == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Selecteer eerst een afdeling om de leidinggevenden te zien.',
                style: TextStyle(fontSize: 13.5, color: kTextTertiary),
              ),
            )
          : leaders.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Geen leidinggevenden gekoppeld.',
                style: TextStyle(fontSize: 13.5, color: kTextTertiary),
              ),
            )
          : Column(
              children: List.generate(leaders.length, (index) {
                final leader = leaders[index];
                return Container(
                  margin: EdgeInsets.only(
                    bottom: index == leaders.length - 1 ? 0 : 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
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
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          ((leader.name ?? leader.email).isNotEmpty
                                  ? (leader.name ?? leader.email)[0]
                                  : '?')
                              .toUpperCase(),
                          style: const TextStyle(
                            color: kBrandGreenDeep,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          leader.name ?? leader.email,
                          style: const TextStyle(
                            fontSize: 14,
                            color: kTextPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: kTextTertiary,
                        tooltip: 'Verwijderen',
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
                    ],
                  ),
                );
              }),
            ),
    );
  }
}
