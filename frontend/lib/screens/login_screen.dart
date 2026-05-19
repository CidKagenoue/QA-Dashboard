import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/vlotter_logo.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';

const Color _brandGreen = Color(0xFF7DBB3F);
const Color _brandGreenDark = Color(0xFF6FAC35);
const Color _loginBackground = Color(0xFFF6FAF3);
const Color _fieldBorder = Color(0xFFD8E0D2);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final notificationService = Provider.of<NotificationService>(
      context,
      listen: false,
    );

    try {
      await authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      notificationService.bindAuth(authService);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Inloggen mislukt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF273421),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF9AA494)),
      prefixIcon: Icon(icon, color: const Color(0xFF7B8773), size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: border(_fieldBorder),
      enabledBorder: border(_fieldBorder),
      focusedBorder: border(_brandGreen, 1.4),
      errorBorder: border(const Color(0xFFD32F2F)),
      focusedErrorBorder: border(const Color(0xFFD32F2F), 1.4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _loginBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const VlotterLogo(height: 54),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(36, 34, 36, 28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 30,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Welkom terug',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF243022),
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Log in om verder te gaan naar het QA Dashboard',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64705E),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildFieldLabel('Gebruikersnaam'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            decoration: _inputDecoration(
                              hintText: 'admin',
                              icon: Icons.person_outline_rounded,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Voer je gebruikersnaam in';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildFieldLabel('Wachtwoord'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _handleLogin(),
                            decoration: _inputDecoration(
                              hintText: '********',
                              icon: Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                  color: const Color(0xFF7B8773),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Voer je wachtwoord in';
                              }
                              if (value.length < 6) {
                                return 'Wachtwoord moet minstens 6 tekens zijn';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 30),
                          Consumer<AuthService>(
                            builder: (context, authService, child) {
                              return SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: authService.isLoading
                                      ? null
                                      : _handleLogin,
                                  style:
                                      ElevatedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        elevation: 0,
                                      ).copyWith(
                                        overlayColor: WidgetStateProperty.all(
                                          const Color(0x14FFFFFF),
                                        ),
                                        backgroundColor:
                                            WidgetStateProperty.resolveWith((
                                              states,
                                            ) {
                                              if (states.contains(
                                                WidgetState.disabled,
                                              )) {
                                                return const Color(0x8C7DBB3F);
                                              }
                                              if (states.contains(
                                                WidgetState.hovered,
                                              )) {
                                                return _brandGreenDark;
                                              }
                                              return _brandGreen;
                                            }),
                                      ),
                                  child: authService.isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Inloggen',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: _brandGreen,
                              ),
                              child: const Text(
                                'Wachtwoord vergeten?',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
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
    );
  }
}
