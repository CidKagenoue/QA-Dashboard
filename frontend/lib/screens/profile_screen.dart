import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

import '../models/department.dart';
import '../services/department_api_service.dart';
import '../services/auth_service.dart';
import '../widgets/design/design_system.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Uint8List? _avatarImageBytes;
  String? _avatarImageBase64;

  Future<void> _pickAvatarImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _avatarImageBytes = result.files.single.bytes;
        _avatarImageBase64 = base64Encode(_avatarImageBytes!);
      });
    }
  }

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();

  List<Department> _allDepartments = [];
  Set<int> _selectedDepartmentIds = {};
  bool _departmentsLoading = false;

  void _showAddDepartmentDialog() async {
    final availableDepartments = _allDepartments
        .where((d) => !_selectedDepartmentIds.contains(d.id))
        .toList();
    if (availableDepartments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alle afdelingen zijn al toegevoegd.')),
      );
      return;
    }
    Department? selected;
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Afdeling toevoegen'),
          content: SizedBox(
            width: 320,
            child: DropdownButtonFormField<Department>(
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Kies een afdeling',
              ),
              items: availableDepartments
                  .map(
                    (dept) =>
                        DropdownMenuItem(value: dept, child: Text(dept.name)),
                  )
                  .toList(),
              onChanged: (val) => selected = val,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuleren'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selected != null) {
                  setState(() {
                    _selectedDepartmentIds.add(selected!.id);
                  });
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Toevoegen'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user != null) {
      final effectiveName = user.name ?? '';
      _firstNameController.text = effectiveName;
      _emailController.text = user.email;
      final split = effectiveName.split(' ');
      if (split.length >= 2) {
        _firstNameController.text = split.first;
        _lastNameController.text = split.sublist(1).join(' ');
      }
      _selectedDepartmentIds = user.departments.map((d) => d.id).toSet();
      if (user.profileImage != null && user.profileImage!.isNotEmpty) {
        try {
          _avatarImageBase64 = user.profileImage;
          _avatarImageBytes = base64Decode(user.profileImage!);
        } catch (_) {}
      }
    }
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (!(auth.user?.isAdmin ?? false)) return;
    setState(() => _departmentsLoading = true);
    try {
      final token = await auth.getValidAccessToken();
      final departments = await DepartmentApiService.getDepartments(token);
      setState(() {
        _allDepartments = departments;
      });
    } catch (e) {
      debugPrint('Failed to load departments: $e');
    } finally {
      setState(() => _departmentsLoading = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.user;
    final isAdmin = user?.isAdmin ?? false;
    final initial =
        (user?.name?.isNotEmpty == true) ? user!.name![0].toUpperCase() : '?';

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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppBreadcrumb(
                    segments: ['Instellingen', 'Profiel']),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mijn profiel',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary,
                              letterSpacing: -0.4,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isAdmin
                                ? 'Beheer je gegevens, afdelingstoewijzing en wachtwoord.'
                                : 'Beheer je gegevens en wachtwoord.',
                            style: const TextStyle(
                              fontSize: 14.5,
                              color: kTextSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _ProfileHeader(
                  avatarBytes: _avatarImageBytes,
                  initial: initial,
                  displayName:
                      _composedDisplayName().isEmpty ? '—' : _composedDisplayName(),
                  email: _emailController.text.isEmpty
                      ? user?.email ?? ''
                      : _emailController.text,
                  role: isAdmin ? 'Administrator' : 'Gebruiker',
                  onPickAvatar: _pickAvatarImage,
                ),
                const SizedBox(height: 22),
                AppSectionPanel(
                  title: 'Persoonlijke gegevens',
                  icon: Icons.person_outline_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 560;
                          if (compact) {
                            return Column(
                              children: [
                                _LabeledTextField(
                                  label: 'Voornaam',
                                  controller: _firstNameController,
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                          ? 'Voornaam is verplicht'
                                          : null,
                                ),
                                const SizedBox(height: 16),
                                _LabeledTextField(
                                  label: 'Achternaam',
                                  controller: _lastNameController,
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: _LabeledTextField(
                                  label: 'Voornaam',
                                  controller: _firstNameController,
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                          ? 'Voornaam is verplicht'
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _LabeledTextField(
                                  label: 'Achternaam',
                                  controller: _lastNameController,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _LabeledTextField(
                        label: 'E-mailadres',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.mail_outline_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'E-mail is verplicht';
                          }
                          if (!value.contains('@')) {
                            return 'Voer een geldig e-mailadres in';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppSectionPanel(
                  title: 'Beveiliging',
                  icon: Icons.lock_outline_rounded,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Wachtwoord',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: kTextPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Wijzig je wachtwoord regelmatig voor een veilig account.',
                              style: TextStyle(
                                fontSize: 13,
                                color: kTextTertiary,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: _openPasswordChangeSheet,
                        icon: const Icon(Icons.password_rounded, size: 18),
                        label: const Text('Wachtwoord wijzigen'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppSectionPanel(
                  title: 'Afdelingen',
                  icon: Icons.apartment_rounded,
                  child: _buildDepartmentsContent(user, isAdmin),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _saveProfile,
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Wijzigingen opslaan'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Uitloggen'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kDanger,
                        side: const BorderSide(color: kDangerBorder),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _composedDisplayName() {
    final fn = _firstNameController.text.trim();
    final ln = _lastNameController.text.trim();
    return [fn, ln].where((s) => s.isNotEmpty).join(' ');
  }

  Widget _buildDepartmentsContent(dynamic user, bool isAdmin) {
    if (isAdmin && _departmentsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: CircularProgressIndicator(),
      );
    }
    if (isAdmin) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedDepartmentIds.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nog geen afdelingen toegewezen.',
                style: TextStyle(fontSize: 13.5, color: kTextTertiary),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allDepartments
                  .where((d) => _selectedDepartmentIds.contains(d.id))
                  .map((dept) => _DepartmentChip(
                        label: dept.name,
                        onRemove: () {
                          setState(() {
                            _selectedDepartmentIds.remove(dept.id);
                          });
                        },
                      ))
                  .toList(),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _showAddDepartmentDialog,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Afdeling toevoegen'),
          ),
        ],
      );
    }
    final depts = (user?.departments as List?) ?? const [];
    if (depts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Geen afdelingen toegewezen. Vraag een beheerder om toegang.',
          style: TextStyle(fontSize: 13.5, color: kTextTertiary),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: depts
          .map<Widget>((d) => _DepartmentChip(label: d.name))
          .toList(),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final eMail = _emailController.text.trim();
    final fullName =
        [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final isAdmin = auth.user?.isAdmin ?? false;
      await auth.updateProfile(
        name: fullName,
        email: eMail,
        departmentIds:
            isAdmin ? _selectedDepartmentIds.toList() : null,
        profileImage: _avatarImageBase64,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profiel succesvol opgeslagen'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opslaan mislukt: $e'),
            backgroundColor: kDanger,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    await Provider.of<AuthService>(context, listen: false).logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _openPasswordChangeSheet() {
    final currentCtl = TextEditingController();
    final newCtl = TextEditingController();
    final confirmCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    bool showCurrent = false;
    bool showNew = false;
    bool showConfirm = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 440,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(kRadiusXl),
                border: Border.all(color: kBorder),
                boxShadow: kShadowCard,
              ),
              child: StatefulBuilder(
                builder: (ctx, setState) {
                  return Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: kBrandGreenSoft,
                                borderRadius:
                                    BorderRadius.circular(kRadiusSm),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.lock_outline_rounded,
                                  size: 18, color: kBrandGreenDeep),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Wachtwoord wijzigen',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: kTextPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _PasswordField(
                          controller: currentCtl,
                          label: 'Huidig wachtwoord',
                          visible: showCurrent,
                          toggle: () =>
                              setState(() => showCurrent = !showCurrent),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Voer je huidige wachtwoord in';
                            }
                            if (v.length < 8) return 'Minimaal 8 tekens';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _PasswordField(
                          controller: newCtl,
                          label: 'Nieuw wachtwoord',
                          visible: showNew,
                          toggle: () => setState(() => showNew = !showNew),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Voer een nieuw wachtwoord in';
                            }
                            if (v.length < 8) return 'Minimaal 8 tekens';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _PasswordField(
                          controller: confirmCtl,
                          label: 'Bevestig wachtwoord',
                          visible: showConfirm,
                          toggle: () =>
                              setState(() => showConfirm = !showConfirm),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Bevestig je wachtwoord';
                            }
                            if (v != newCtl.text) {
                              return 'Wachtwoorden komen niet overeen';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Consumer<AuthService>(
                          builder: (_, auth, _) => SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: auth.isLoading
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }

                                      try {
                                        await context
                                            .read<AuthService>()
                                            .changePassword(
                                              currentPassword: currentCtl.text,
                                              newPassword: newCtl.text,
                                              confirmNewPassword:
                                                  confirmCtl.text,
                                            );

                                        if (!mounted) return;
                                        Navigator.of(context).pop();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Wachtwoord succesvol gewijzigd'),
                                          ),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(e.toString()),
                                            backgroundColor: kDanger,
                                          ),
                                        );
                                      }
                                    },
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text('Wachtwoord opslaan'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.avatarBytes,
    required this.initial,
    required this.displayName,
    required this.email,
    required this.role,
    required this.onPickAvatar,
  });

  final Uint8List? avatarBytes;
  final String initial;
  final String displayName;
  final String email;
  final String role;
  final VoidCallback onPickAvatar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurfaceMuted,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kBrandGreenSoft,
                  border: Border.all(color: kSurface, width: 3),
                  boxShadow: kShadowSoft,
                ),
                child: avatarBytes != null
                    ? ClipOval(
                        child: Image.memory(
                          avatarBytes!,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: kBrandGreenDeep,
                          ),
                        ),
                      ),
              ),
              Positioned(
                bottom: -4,
                right: -4,
                child: Material(
                  color: kSurface,
                  shape: const CircleBorder(
                      side: BorderSide(color: kBorder)),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onPickAvatar,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.edit_outlined,
                          size: 16, color: kBrandGreenDeep),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary,
                          height: 1.15,
                        ),
                      ),
                    ),
                    AppStatusPill(
                        label: role.toUpperCase(),
                        tone: AppStatusTone.brand),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.mail_outline_rounded,
                        size: 16, color: kTextTertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: kTextTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;

  const _LabeledTextField({
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: kTextSecondary,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 14.5,
            color: kTextPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, color: kTextTertiary, size: 20),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.visible,
    required this.toggle,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool visible;
  final VoidCallback toggle;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      style: const TextStyle(
        fontSize: 14.5,
        color: kTextPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            const Icon(Icons.lock_outline_rounded, color: kTextTertiary),
        suffixIcon: IconButton(
          icon: Icon(
            visible
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            color: kTextTertiary,
            size: 20,
          ),
          onPressed: toggle,
        ),
      ),
      validator: validator,
    );
  }
}

class _DepartmentChip extends StatelessWidget {
  const _DepartmentChip({required this.label, this.onRemove});

  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: EdgeInsets.only(left: 12, right: onRemove == null ? 12 : 4),
      decoration: BoxDecoration(
        color: kBrandGreenSubtle,
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: kBrandGreenSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.apartment_rounded,
              size: 14, color: kBrandGreenDeep),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: kBrandGreenDeep,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.all(5),
                child: Icon(Icons.close_rounded,
                    size: 14, color: kBrandGreenDeep),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
