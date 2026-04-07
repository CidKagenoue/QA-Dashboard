import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

import '../models/department.dart';
import '../services/department_api_service.dart';
import '../services/auth_service.dart';
import 'account_management_page.dart';
import 'departments_screen.dart';
import 'login_screen.dart';
import 'locations_screen.dart';

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
    final availableDepartments = _allDepartments.where((d) => !_selectedDepartmentIds.contains(d.id)).toList();
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
                border: OutlineInputBorder(),
              ),
              items: availableDepartments.map((dept) => DropdownMenuItem(
                value: dept,
                child: Text(dept.name),
              )).toList(),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7CB342),
              ),
            ),
          ],
        );
      },
    );
  }

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
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(curved);

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(position: slide, child: child),
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
      // Profielfoto laden uit backend
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7CB342),
        foregroundColor: Colors.white,
        title: const Text('Vlotter', style: TextStyle(color: Colors.white)),
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
                    const _SidebarItem('Profiel', selected: true),
                    const SizedBox(height: 20),
                    const _SidebarItem('Meldingen'),
                    const SizedBox(height: 20),
                    _SidebarItem(
                      'Accountbeheer',
                      onTap: () {
                        Navigator.of(context).push(
                          _buildSmoothRoute(const AccountManagementPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _SidebarItem(
                      'Afdelingen',
                      onTap: () {
                        Navigator.of(
                          context,
                        ).push(_buildSmoothRoute(const DepartmentsScreen()));
                      },
                    ),
                    const SizedBox(height: 20),
                    _SidebarItem(
                      'Locaties',
                      onTap: () {
                        Navigator.of(context).push(
                          _buildSmoothRoute(const LocationsScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(40, 28, 40, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey.shade200,
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                              child: _avatarImageBytes != null
                                  ? ClipOval(
                                      child: Image.memory(
                                        _avatarImageBytes!,
                                        width: 130,
                                        height: 130,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : (user?.profileImage != null && user!.profileImage!.isNotEmpty
                                      ? ClipOval(
                                          child: Image.memory(
                                            base64Decode(user.profileImage!),
                                            width: 130,
                                            height: 130,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.person,
                                          size: 70,
                                          color: Colors.black54,
                                        )),
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: _pickAvatarImage,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  margin: const EdgeInsets.only(
                                    bottom: 6,
                                    right: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.grey.shade400,
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(3),
                                  child: const Icon(Icons.edit, size: 16, color: Color(0xFF7CB342)),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(width: 48),

                        Expanded(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
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
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: _LabeledTextField(
                                        label: 'Achternaam',
                                        controller: _lastNameController,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _LabeledTextField(
                                        label: 'E‑Mail',
                                        controller: _emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'E-mail is verplicht';
                                          }
                                          if (!value.contains('@')) {
                                            return 'Voer een geldig e-mailadres in';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      flex: 1,
                                      child: _PasswordAdjustButton(
                                        onPressed: _openPasswordChangeSheet,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),

                                const Text(
                                  'Mijn afdelingen',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Builder(
                                  builder: (context) {
                                    if (isAdmin) {
                                      if (_departmentsLoading) {
                                        return const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: CircularProgressIndicator(),
                                        );
                                      }
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            constraints: const BoxConstraints(
                                              minHeight: 150,
                                            ),
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            child: Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: [
                                                ..._allDepartments
                                                    .where((dept) => _selectedDepartmentIds.contains(dept.id))
                                                    .map((dept) => Padding(
                                                          padding: const EdgeInsets.only(right: 6, bottom: 6),
                                                          child: Chip(
                                                            label: SizedBox(
                                                              width: 80,
                                                              child: Text(
                                                                dept.name,
                                                                style: const TextStyle(fontSize: 14),
                                                                overflow: TextOverflow.ellipsis,
                                                                maxLines: 1,
                                                              ),
                                                            ),
                                                            deleteIcon: const Icon(Icons.close, size: 18),
                                                            onDeleted: () {
                                                              setState(() {
                                                                _selectedDepartmentIds.remove(dept.id);
                                                              });
                                                            },
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(20),
                                                              side: BorderSide(color: Colors.grey.shade400),
                                                            ),
                                                            backgroundColor: Colors.white,
                                                          ),
                                                        )),
                                                Padding(
                                                  padding: const EdgeInsets.only(right: 6, bottom: 6),
                                                  child: ActionChip(
                                                    label: const Icon(Icons.add, color: Color(0xFF7CB342)),
                                                    onPressed: _showAddDepartmentDialog,
                                                    backgroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(20),
                                                      side: BorderSide(color: Colors.grey.shade400),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    } else {
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        child: Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: user?.departments.map((d) =>
                                            Padding(
                                              padding: const EdgeInsets.only(right: 6, bottom: 6),
                                              child: Chip(
                                                label: SizedBox(
                                                  width: 80,
                                                  child: Text(
                                                    d.name,
                                                    style: const TextStyle(fontSize: 14),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(20),
                                                  side: BorderSide(color: Colors.grey.shade400),
                                                ),
                                                backgroundColor: Colors.white,
                                              ),
                                            ),
                                          ).toList() ?? [],
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (!_formKey.currentState!.validate()) return;

                              final firstName = _firstNameController.text
                                  .trim();
                              final lastName = _lastNameController.text.trim();
                              final eMail = _emailController.text.trim();
                              final fullName = [
                                firstName,
                                lastName,
                              ].where((s) => s.isNotEmpty).join(' ');

                              try {
                                final auth = Provider.of<AuthService>(context, listen: false);
                                final isAdmin = auth.user?.isAdmin ?? false;
                                await auth.updateProfile(
                                  name: fullName,
                                  email: eMail,
                                  departmentIds: isAdmin ? _selectedDepartmentIds.toList() : null,
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
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.save),
                            label: const Text('Opslaan'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7CB342),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await Provider.of<AuthService>(
                                context,
                                listen: false,
                              ).logout();
                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                  (route) => false,
                                );
                              }
                            },
                            icon: const Icon(Icons.logout, color: Colors.red),
                            label: const Text(
                              'Uitloggen',
                              style: TextStyle(color: Colors.red),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
            width: 420,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  blurRadius: 24,
                  spreadRadius: 4,
                  color: Colors.black.withValues(alpha: .15),
                )
              ],
            ),
            child: StatefulBuilder(
              builder: (ctx, setState) {
                return Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Wachtwoord wijzigen',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // CURRENT PASSWORD
                      TextFormField(
                        controller: currentCtl,
                        obscureText: !showCurrent,
                        decoration: InputDecoration(
                          labelText: 'Huidig wachtwoord',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(showCurrent
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () => setState(
                                () => showCurrent = !showCurrent),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Voer je huidige wachtwoord in';
                          }
                          if (v.length < 8) {
                            return 'Minimaal 8 tekens';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // NEW PASSWORD
                      TextFormField(
                        controller: newCtl,
                        obscureText: !showNew,
                        decoration: InputDecoration(
                          labelText: 'Nieuw wachtwoord',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(showNew
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () =>
                                setState(() => showNew = !showNew),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Voer een nieuw wachtwoord in';
                          }
                          if (v.length < 8) {
                            return 'Minimaal 8 tekens';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // CONFIRM PASSWORD
                      TextFormField(
                        controller: confirmCtl,
                        obscureText: !showConfirm,
                        decoration: InputDecoration(
                          labelText: 'Bevestig wachtwoord',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(showConfirm
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () => setState(
                                () => showConfirm = !showConfirm),
                          ),
                        ),
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

                      const SizedBox(height: 28),

                      Consumer<AuthService>(
                        builder: (_, auth, _) => SizedBox(
                          width: double.infinity,
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
                                            currentPassword:
                                                currentCtl.text,
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
                                              'Wachtwoord succesvol gewijzigd',
                                            ),
                                          ),
                                        );
                                      
                                    } catch (e) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(e.toString()),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7CB342),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: auth.isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text('Opslaan'),
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

class _LabeledTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const _LabeledTextField({
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF7CB342), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _PasswordAdjustButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _PasswordAdjustButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.lock_open, color: Colors.black87, size: 18),
        label: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Wachtwoord Aanpassen',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.edit, color: Colors.grey.shade700, size: 18),
          ],
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade300,
          foregroundColor: Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}




