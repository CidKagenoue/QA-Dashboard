import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qa_dashboard/models/branch.dart';
import '../services/auth_service.dart';
import '../services/department_api_service.dart';
import '../services/location_api_service.dart';
import '../models/department.dart';
import '../theme/app_theme.dart';
import '../models/user.dart';

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

  // Use shared green from app_theme.dart

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
        LocationApiService.getBranches(token),
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
          decoration: const InputDecoration(
            labelText: 'Naam afdeling',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kAppGreen),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.of(ctx).pop(name);
            },
            child: const Text('Opslaan', style: TextStyle(color: Colors.white)),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Verwijderen',
              style: TextStyle(color: Colors.white),
            ),
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
              borderRadius: BorderRadius.circular(8),
            ),
            child: SizedBox(
              width: 280,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Zoeken',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        isDense: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final user = filtered[i];
                          final isChecked = selected.contains(user.id);
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            title: Text(
                              (user.name ?? user.email),
                              style: const TextStyle(fontSize: 14),
                            ),
                            trailing: GestureDetector(
                              onTap: () => setDialogState(() {
                                if (isChecked) {
                                  selected.remove(user.id);
                                } else {
                                  selected.add(user.id);
                                }
                              }),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: isChecked
                                      ? kAppGreen
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: isChecked
                                    ? const Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                            onTap: () => setDialogState(() {
                              if (isChecked) {
                                selected.remove(user.id);
                              } else {
                                selected.add(user.id);
                              }
                            }),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAppGreen,
                          minimumSize: const Size(48, 32),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                        ),
                        onPressed: () =>
                            Navigator.of(ctx).pop(selected.toList()),
                        child: const Text(
                          'OK',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
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
        await LocationApiService.saveBranch(
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
      return _buildAccessDeniedState(
        title: 'Afdelingen beheren is alleen beschikbaar voor admins.',
        description:
            'Log in met een admin-account om afdelingen en leidinggevenden te bekijken en te wijzigen.',
      );
    } else if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildDepartmentsCard()),
            const SizedBox(width: 16),
            Expanded(child: _buildLeadersCard()),
          ],
        ),
      );
    }
  }

  Widget _buildDepartmentsCard() {
    final visibleDepartments = _visibleDepartments;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Afdelingen per vestiging',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _selectedBranch?.id,
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
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: visibleDepartments.isEmpty
                ? const Center(
                    child: Text(
                      'Geen afdelingen gekoppeld aan deze vestiging',
                      style: TextStyle(color: Colors.black45),
                    ),
                  )
                : ListView.builder(
                    itemCount: visibleDepartments.length,
                    itemBuilder: (context, index) {
                      final dept = visibleDepartments[index];
                      final isSelected = _selected?.id == dept.id;
                      return Container(
                        color: isSelected ? const Color(0xFFE8F5E9) : null,
                        child: ListTile(
                          dense: true,
                          title: Text(
                            dept.name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: isSelected
                                      ? Colors.black87
                                      : Colors.black38,
                                ),
                                onPressed: () =>
                                    _openDepartmentDialog(dept: dept),
                                tooltip: 'Bewerken',
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: isSelected
                                      ? Colors.black87
                                      : Colors.black38,
                                ),
                                onPressed: () => _deleteDepartment(dept),
                                tooltip: 'Verwijderen',
                              ),
                            ],
                          ),
                          onTap: () => setState(() => _selected = dept),
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
                heroTag: 'add_dept',
                backgroundColor: kAppGreen,
                onPressed: _selectedBranch == null
                    ? null
                    : () => _openDepartmentDialog(),
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

  Widget _buildLeadersCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: const [
                Text(
                  'Leidinggevenden',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _selected == null
                ? const Center(
                    child: Text(
                      'Selecteer een afdeling',
                      style: TextStyle(color: Colors.black45),
                    ),
                  )
                : _selected!.leaders.isEmpty
                ? const Center(
                    child: Text(
                      'Geen leidinggevenden',
                      style: TextStyle(color: Colors.black45),
                    ),
                  )
                : ListView.builder(
                    itemCount: _selected!.leaders.length,
                    itemBuilder: (context, index) {
                      final leader = _selected!.leaders[index];
                      return ListTile(
                        dense: true,
                        title: Text(leader.name ?? leader.email),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.black38,
                          ),
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
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerRight,
              child: FloatingActionButton.small(
                heroTag: 'add_leader',
                backgroundColor: kAppGreen,
                onPressed: _selected == null ? null : _openLeadersPopup,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
