import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/department.dart';
import '../models/user.dart';
import '../services/account_management_service.dart';
import '../services/auth_service.dart';
import '../services/department_api_service.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showNoAccessSection = true;
  bool _showAllAccountsSection = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AccountManagementService, AuthService>(
      builder: (context, accountManagementService, authService, child) {
        final currentUserId = authService.user?.id;
        final manageableAccounts = accountManagementService.accounts
            .where((account) => account.id != currentUserId)
            .toList();
        final query = _searchController.text.trim().toLowerCase();
        final filteredAccounts = manageableAccounts
            .where((account) => _matchesQuery(account, query))
            .toList();
        final accountsWithoutAccess = filteredAccounts
            .where((account) => !account.hasAnyAccess)
            .toList();

        if (accountManagementService.isLoading &&
            !accountManagementService.hasLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!accountManagementService.canManageAccounts) {
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
                          'Accountbeheer geopend',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Je zit op de juiste pagina, maar dit account heeft momenteel geen adminrechten om accounts te beheren.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Log in met een admin-account om gebruikers aan te maken, rechten aan te passen en accounts te verwijderen.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: accountManagementService.refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instellingen Accountbeheer',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Beheer gebruikers en bepaal direct wie toegang heeft tot Basis, WHS-Tours, OVA, JAP & GPP en Onderhoud & Keuringen.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 520,
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: 'Zoeken op naam of e-mail',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: accountManagementService.canManageAccounts
                          ? _showCreateAccountDialog
                          : null,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nieuw'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _AccountSection(
                  title: 'Accounts zonder toegang',
                  count: accountsWithoutAccess.length,
                  isExpanded: _showNoAccessSection,
                  onToggle: () {
                    setState(() {
                      _showNoAccessSection = !_showNoAccessSection;
                    });
                  },
                  child: accountsWithoutAccess.isEmpty
                      ? const _EmptySectionState(
                          title: 'Geen accounts zonder toegang',
                          description:
                              'Elke gebruiker heeft momenteel minstens één module of admin-recht toegewezen.',
                        )
                      : _AccountGrid(
                          accounts: accountsWithoutAccess,
                          currentUserId: currentUserId,
                          isUpdating: accountManagementService.isUpdating,
                          isDeleting: accountManagementService.isDeleting,
                          onAccessChanged: _handleAccountUpdate,
                          onEdit: _handleEditAccount,
                          onDelete: _handleDeleteAccount,
                        ),
                ),
                const SizedBox(height: 26),
                _AccountSection(
                  title: 'Alle accounts',
                  count: filteredAccounts.length,
                  isExpanded: _showAllAccountsSection,
                  onToggle: () {
                    setState(() {
                      _showAllAccountsSection = !_showAllAccountsSection;
                    });
                  },
                  child: filteredAccounts.isEmpty
                      ? _EmptySectionState(
                          title: query.isEmpty
                              ? 'Nog geen accounts gevonden'
                              : 'Geen zoekresultaten',
                          description: query.isEmpty
                              ? 'Maak een eerste account aan of pas filters aan zodra er meer gebruikers zijn.'
                              : 'Probeer een andere naam of e-mail om het juiste account te vinden.',
                        )
                      : _AccountGrid(
                          accounts: filteredAccounts,
                          currentUserId: currentUserId,
                          isUpdating: accountManagementService.isUpdating,
                          isDeleting: accountManagementService.isDeleting,
                          onAccessChanged: _handleAccountUpdate,
                          onEdit: _handleEditAccount,
                          onDelete: _handleDeleteAccount,
                        ),
                ),
                if (accountManagementService.isLoading &&
                    accountManagementService.hasLoaded)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreateAccountDialog() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CreateAccountDialog(),
    );

    if (!mounted || created != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Account aangemaakt. Afdelingen en rechten zijn opgeslagen.',
        ),
      ),
    );
  }

  Future<void> _handleAccountUpdate(
    User account,
    bool isAdmin,
    AccountAccess access,
  ) async {
    try {
      await context.read<AccountManagementService>().updateAccount(
        account: account,
        isAdmin: isAdmin,
        access: access,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage(error)),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _handleEditAccount(User account) async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditAccountDialog(account: account),
    );

    if (!mounted || updated != true) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Account is aangepast.')));
  }

  Future<void> _handleDeleteAccount(User account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Account verwijderen?'),
          content: Text(
            'Het account van ${account.displayName} wordt definitief verwijderd.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              child: const Text('Verwijderen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await context.read<AccountManagementService>().deleteAccount(account.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${account.displayName} is verwijderd.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage(error)),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  bool _matchesQuery(User account, String query) {
    if (query.isEmpty) {
      return true;
    }

    return account.displayName.toLowerCase().contains(query) ||
        account.email.toLowerCase().contains(query) ||
        account.departments.any(
          (department) => department.name.toLowerCase().contains(query),
        );
  }

  String _errorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.title,
    required this.count,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
  });

  final String title;
  final int count;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  color: const Color(0xFF475145),
                ),
                const SizedBox(width: 8),
                Text(
                  '$title $count',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF293224),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Divider(height: 1),
        if (isExpanded) ...[const SizedBox(height: 20), child],
      ],
    );
  }
}

class _AccountGrid extends StatelessWidget {
  const _AccountGrid({
    required this.accounts,
    required this.currentUserId,
    required this.isUpdating,
    required this.isDeleting,
    required this.onAccessChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final List<User> accounts;
  final int? currentUserId;
  final bool Function(int accountId) isUpdating;
  final bool Function(int accountId) isDeleting;
  final Future<void> Function(User account, bool isAdmin, AccountAccess access)
  onAccessChanged;
  final Future<void> Function(User account) onEdit;
  final Future<void> Function(User account) onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = _calculateCardWidth(constraints.maxWidth);

        return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: accounts.map((account) {
            final updating = isUpdating(account.id);
            final deleting = isDeleting(account.id);
            final isCurrentUser = currentUserId == account.id;

            return SizedBox(
              width: cardWidth,
              child: _AccountCard(
                account: account,
                isCurrentUser: isCurrentUser,
                isUpdating: updating,
                isDeleting: deleting,
                onAccessChanged: onAccessChanged,
                onEdit: isCurrentUser ? null : onEdit,
                onDelete: isCurrentUser ? null : onDelete,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  double _calculateCardWidth(double availableWidth) {
    if (availableWidth >= 1260) {
      return (availableWidth - 36) / 3;
    }
    if (availableWidth >= 860) {
      return (availableWidth - 18) / 2;
    }

    return availableWidth.clamp(260.0, 420.0).toDouble();
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.isCurrentUser,
    required this.isUpdating,
    required this.isDeleting,
    required this.onAccessChanged,
    this.onEdit,
    this.onDelete,
  });

  final User account;
  final bool isCurrentUser;
  final bool isUpdating;
  final bool isDeleting;
  final Future<void> Function(User account, bool isAdmin, AccountAccess access)
  onAccessChanged;
  final Future<void> Function(User account)? onEdit;
  final Future<void> Function(User account)? onDelete;

  @override
  Widget build(BuildContext context) {
    final isBusy = isUpdating || isDeleting;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isDeleting ? 0.45 : 1,
      child: Card(
        child: Stack(
          children: [
            IgnorePointer(
              ignoring: isBusy,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isCurrentUser)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF3D7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Jij',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF5C7A2F),
                              ),
                            ),
                          ),
                        const Spacer(),
                        PopupMenuButton<_AccountCardAction>(
                          enabled: !isBusy,
                          tooltip: 'Account acties',
                          icon: const Icon(Icons.more_vert_rounded),
                          color: Colors.white,
                          onSelected: (action) {
                            if (action == _AccountCardAction.edit) {
                              onEdit?.call(account);
                              return;
                            }

                            onDelete?.call(account);
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: _AccountCardAction.edit,
                              enabled: onEdit != null,
                              child: const _AccountActionMenuItem(
                                icon: Icons.edit_outlined,
                                label: 'Bewerken',
                              ),
                            ),
                            PopupMenuItem(
                              value: _AccountCardAction.delete,
                              enabled: onDelete != null,
                              child: const _AccountActionMenuItem(
                                icon: Icons.delete_outline_rounded,
                                label: 'Verwijderen',
                                isDestructive: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Center(
                      child: CircleAvatar(
                        radius: 38,
                        backgroundColor: const Color(0xFFE3E5DE),
                        foregroundColor: const Color(0xFF80857B),
                        child: const Icon(Icons.person_rounded, size: 42),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            account.displayName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2B3424),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            account.email,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6A7266),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (account.isAdmin)
                                const _InfoChip(
                                  icon: Icons.admin_panel_settings_outlined,
                                  label: 'Admin',
                                ),
                              ...account.departments.map(
                                (department) => _InfoChip(
                                  icon: Icons.apartment_rounded,
                                  label: department.name,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    const Text(
                      'Toegang',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2B3424),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _AccessToggleRow(
                      label: 'Basis (Eigen OVA-acties)',
                      value: account.isAdmin || account.access.basis,
                      isInherited: account.isAdmin && !account.access.basis,
                      onChanged: account.isAdmin
                          ? null
                          : (value) {
                              onAccessChanged(
                                account,
                                account.isAdmin,
                                account.access.copyWith(basis: value),
                              );
                            },
                    ),
                    _AccessToggleRow(
                      label: 'WHS-Tours',
                      value: account.isAdmin || account.access.whsTours,
                      isInherited: account.isAdmin && !account.access.whsTours,
                      onChanged: account.isAdmin
                          ? null
                          : (value) {
                              onAccessChanged(
                                account,
                                account.isAdmin,
                                account.access.copyWith(whsTours: value),
                              );
                            },
                    ),
                    _AccessToggleRow(
                      label: 'OVA',
                      value: account.isAdmin || account.access.ova,
                      isInherited: account.isAdmin && !account.access.ova,
                      onChanged: account.isAdmin
                          ? null
                          : (value) {
                              onAccessChanged(
                                account,
                                account.isAdmin,
                                account.access.copyWith(ova: value),
                              );
                            },
                    ),
                    _AccessToggleRow(
                      label: 'JAP & GPP',
                      value: account.isAdmin || account.access.japGpp,
                      isInherited: account.isAdmin && !account.access.japGpp,
                      onChanged: account.isAdmin
                          ? null
                          : (value) {
                              onAccessChanged(
                                account,
                                account.isAdmin,
                                account.access.copyWith(japGpp: value),
                              );
                            },
                    ),
                    _AccessToggleRow(
                      label: 'Onderhoud & Keuringen',
                      value:
                          account.isAdmin ||
                          account.access.maintenanceInspections,
                      isInherited:
                          account.isAdmin &&
                          !account.access.maintenanceInspections,
                      onChanged: account.isAdmin
                          ? null
                          : (value) {
                              onAccessChanged(
                                account,
                                account.isAdmin,
                                account.access.copyWith(
                                  maintenanceInspections: value,
                                ),
                              );
                            },
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    _AccessToggleRow(
                      label: 'Admin',
                      value: account.isAdmin,
                      onChanged: (value) {
                        onAccessChanged(account, value, account.access);
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (isBusy)
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0x99FFFFFF),
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _AccountCardAction { edit, delete }

class _AccountActionMenuItem extends StatelessWidget {
  const _AccountActionMenuItem({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red.shade700 : const Color(0xFF475145);

    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _AccessToggleRow extends StatelessWidget {
  const _AccessToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.isInherited = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isInherited;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF5A6255),
                    ),
                  ),
                ),
                if (isInherited) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Inbegrepen via admin',
                    child: Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 15,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch.adaptive(
            value: value,
            activeThumbColor: const Color(0xFF6DBE45),
            activeTrackColor: const Color(0xFFBFE3A6),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _EmptySectionState extends StatelessWidget {
  const _EmptySectionState({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF2DE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_alt_outlined,
                color: Color(0xFF6C9D2C),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A3323),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(color: Color(0xFF64705C)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4EC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF5C7A2F)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475145),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionField extends StatelessWidget {
  const _SelectionField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.trailing,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: trailing,
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 24,
            minHeight: 24,
          ),
        ),
        child: Text(
          value,
          style: TextStyle(
            color:
                value == 'Selecteer afdelingen' ||
                    value == 'Afdelingen laden...'
                ? const Color(0xFF667085)
                : const Color(0xFF101828),
          ),
        ),
      ),
    );
  }
}

class _EditAccountDialog extends StatefulWidget {
  const _EditAccountDialog({required this.account});

  final User account;

  @override
  State<_EditAccountDialog> createState() => _EditAccountDialogState();
}

class _EditAccountDialogState extends State<_EditAccountDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final TextEditingController _passwordController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account.name ?? '');
    _emailController = TextEditingController(text: widget.account.email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Account bewerken'),
      contentPadding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 420, maxWidth: 560),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.account.displayName,
                  style: const TextStyle(color: Color(0xFF667085), height: 1.4),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Gebruikersnaam *',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Gebruikersnaam is verplicht';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail *',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) {
                      return 'E-mail is verplicht';
                    }
                    if (!email.contains('@')) {
                      return 'Geef een geldig e-mailadres in';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nieuw wachtwoord',
                    helperText: 'Laat leeg om het wachtwoord niet te wijzigen',
                    helperMaxLines: 2,
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  validator: (value) {
                    final password = value?.trim() ?? '';
                    if (password.isNotEmpty && password.length < 6) {
                      return 'Minstens 6 tekens';
                    }

                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Annuleren'),
        ),
        ElevatedButton.icon(
          onPressed: _submitting ? null : _confirmAndSave,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded),
          label: const Text('Opslaan'),
        ),
      ],
    );
  }

  Future<void> _confirmAndSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final hasPasswordChange = _passwordController.text.trim().isNotEmpty;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Wijzigingen bevestigen?'),
          content: Text(
            hasPasswordChange
                ? 'Ben je zeker dat je de gebruikersnaam, e-mail en het wachtwoord van ${widget.account.displayName} wilt wijzigen?'
                : 'Ben je zeker dat je de gebruikersnaam en e-mail van ${widget.account.displayName} wilt wijzigen?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Ja, aanpassen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await context.read<AccountManagementService>().updateAccountDetails(
        account: widget.account,
        email: _emailController.text,
        name: _nameController.text,
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }
}

class _CreateAccountDialog extends StatefulWidget {
  const _CreateAccountDialog();

  @override
  State<_CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends State<_CreateAccountDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  List<Department> _availableDepartments = const [];
  Set<int> _selectedDepartmentIds = <int>{};
  bool _isAdmin = false;
  AccountAccess _access = const AccountAccess();
  bool _loadingDepartments = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    setState(() => _loadingDepartments = true);

    try {
      final token = await context.read<AuthService>().getValidAccessToken();
      final departments = await DepartmentApiService.getDepartments(token);
      if (!mounted) {
        return;
      }

      setState(() {
        _availableDepartments = departments;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingDepartments = false;
        });
      }
    }
  }

  Future<void> _selectDepartments() async {
    if (_loadingDepartments || _availableDepartments.isEmpty) {
      return;
    }

    final result = await showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) {
        final selected = Set<int>.from(_selectedDepartmentIds);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Afdelingen selecteren'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _availableDepartments.map((department) {
                      final isSelected = selected.contains(department.id);

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              selected.add(department.id);
                            } else {
                              selected.remove(department.id);
                            }
                          });
                        },
                        title: Text(department.name),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuleren'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(selected),
                  child: const Text('Opslaan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDepartmentIds = result;
    });
  }

  String _selectedDepartmentsLabel() {
    if (_loadingDepartments) {
      return 'Afdelingen laden...';
    }

    final selectedDepartments = _availableDepartments
        .where((department) => _selectedDepartmentIds.contains(department.id))
        .map((department) => department.name)
        .toList();

    if (selectedDepartments.isEmpty) {
      return 'Selecteer afdelingen';
    }

    return selectedDepartments.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nieuwe gebruiker registreren'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vul de onderstaande gegevens in om een nieuwe gebruiker toe te voegen.',
                  style: TextStyle(color: Color(0xFF667085), height: 1.4),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'Voornaam *',
                          hintText: 'Milton',
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Voornaam is verplicht';
                          }

                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Achternaam *',
                          hintText: 'Boon',
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Achternaam is verplicht';
                          }

                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail *',
                    hintText: 'voornaam.naam@vlotter.com',
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) {
                      return 'E-mail is verplicht';
                    }
                    if (!email.contains('@')) {
                      return 'Geef een geldig e-mailadres in';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Tijdelijk wachtwoord *',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().length < 6) {
                      return 'Minstens 6 tekens';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _SelectionField(
                  label: 'Afdelingen *',
                  value: _selectedDepartmentsLabel(),
                  onTap: _loadingDepartments ? null : _selectDepartments,
                  trailing: _loadingDepartments
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.keyboard_arrow_down_rounded),
                ),
                if (!_loadingDepartments && _availableDepartments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Nog geen afdelingen beschikbaar om te koppelen.',
                      style: TextStyle(color: Color(0xFF667085)),
                    ),
                  ),
                const SizedBox(height: 14),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 8),
                _DialogToggle(
                  label: 'Admin',
                  value: _isAdmin,
                  onChanged: (value) {
                    setState(() {
                      _isAdmin = value;
                    });
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'Toegang (Permissions)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C3525),
                  ),
                ),
                const SizedBox(height: 8),
                _DialogToggle(
                  label: 'Basis (Eigen OVA-acties)',
                  value: _isAdmin || _access.basis,
                  isInherited: _isAdmin && !_access.basis,
                  onChanged: _isAdmin
                      ? null
                      : (value) {
                          setState(() {
                            _access = _access.copyWith(basis: value);
                          });
                        },
                ),
                _DialogToggle(
                  label: 'WHS-Tours',
                  value: _isAdmin || _access.whsTours,
                  isInherited: _isAdmin && !_access.whsTours,
                  onChanged: _isAdmin
                      ? null
                      : (value) {
                          setState(() {
                            _access = _access.copyWith(whsTours: value);
                          });
                        },
                ),
                _DialogToggle(
                  label: 'OVA',
                  value: _isAdmin || _access.ova,
                  isInherited: _isAdmin && !_access.ova,
                  onChanged: _isAdmin
                      ? null
                      : (value) {
                          setState(() {
                            _access = _access.copyWith(ova: value);
                          });
                        },
                ),
                _DialogToggle(
                  label: 'JAP & GPP',
                  value: _isAdmin || _access.japGpp,
                  isInherited: _isAdmin && !_access.japGpp,
                  onChanged: _isAdmin
                      ? null
                      : (value) {
                          setState(() {
                            _access = _access.copyWith(japGpp: value);
                          });
                        },
                ),
                _DialogToggle(
                  label: 'Onderhoud & Keuringen',
                  value: _isAdmin || _access.maintenanceInspections,
                  isInherited: _isAdmin && !_access.maintenanceInspections,
                  onChanged: _isAdmin
                      ? null
                      : (value) {
                          setState(() {
                            _access = _access.copyWith(
                              maintenanceInspections: value,
                            );
                          });
                        },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Annuleren'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _handleCreate,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Aanmaken'),
        ),
      ],
    );
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDepartmentIds.isEmpty) {
      setState(() {
        _error = 'Selecteer minstens één afdeling';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final fullName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
              .trim();

      await context.read<AccountManagementService>().createAccount(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: fullName,
        departmentIds: _selectedDepartmentIds.toList()..sort(),
        isAdmin: _isAdmin,
        access: _access,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }
}

class _DialogToggle extends StatelessWidget {
  const _DialogToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.isInherited = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isInherited;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      title: Row(
        children: [
          Flexible(child: Text(label, style: const TextStyle(fontSize: 14.5))),
          if (isInherited) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Inbegrepen via admin',
              child: Icon(
                Icons.admin_panel_settings_outlined,
                size: 16,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ],
      ),
      contentPadding: EdgeInsets.zero,
      activeThumbColor: const Color(0xFF6DBE45),
      activeTrackColor: const Color(0xFFBFE3A6),
    );
  }
}
