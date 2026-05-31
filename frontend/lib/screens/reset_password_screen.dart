import 'package:flutter/material.dart';
import '../services/auth_api_service.dart';
import '../theme/app_theme.dart';
import '../utils/password_policy.dart';
import '../widgets/vlotter_logo.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String? initialToken;

  const ResetPasswordScreen({super.key, this.email = '', this.initialToken});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isCheckingToken = true;
  bool _isTokenValid = false;
  String? _tokenError;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  String _formatErrorMessage(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '');
    if (raw.startsWith('Error: ')) {
      return raw.substring(7);
    }
    return raw;
  }

  @override
  void initState() {
    super.initState();
    _verifyTokenFromLink();
  }

  Future<void> _verifyTokenFromLink() async {
    final token = widget.initialToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _isCheckingToken = false;
        _isTokenValid = false;
        _tokenError = 'Ongeldige resetlink. Open de link uit je e-mail.';
      });
      return;
    }

    try {
      await AuthApiService.verifyResetToken(token);
      setState(() {
        _isCheckingToken = false;
        _isTokenValid = true;
      });
    } catch (e) {
      setState(() {
        _isCheckingToken = false;
        _isTokenValid = false;
        _tokenError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final token = widget.initialToken ?? '';
      final password = _passwordController.text;
      final confirmPassword = _confirmPasswordController.text;

      await AuthApiService.resetPassword(
        token: token,
        password: password,
        confirmPassword: confirmPassword,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Wachtwoord succesvol gewijzigd. Log nu in met je nieuwe wachtwoord.',
            ),
            backgroundColor: kSuccess,
          ),
        );

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatErrorMessage(e)),
            backgroundColor: kDanger,
          ),
        );
      }
    }
  }

  InputDecoration _passwordDecoration({
    required bool isVisible,
    required VoidCallback toggleVisibility,
  }) {
    return InputDecoration(
      prefixIcon: const Icon(Icons.lock_outline_rounded, color: kTextTertiary),
      suffixIcon: IconButton(
        icon: Icon(
          isVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          color: kTextTertiary,
          size: 20,
        ),
        onPressed: toggleVisibility,
      ),
      filled: true,
      fillColor: kSurface,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusMd),
          borderSide: const BorderSide(color: kBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusMd),
          borderSide: const BorderSide(color: kBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusMd),
          borderSide: const BorderSide(color: kBrandGreen, width: 1.6)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: kTextSecondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const VlotterLogo(height: 48),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(36, 36, 36, 32),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(kRadius2xl),
                      border: Border.all(color: kBorder),
                      boxShadow: kShadowCard,
                    ),
                    child: _isCheckingToken
                        ? _buildLoading()
                        : !_isTokenValid
                            ? _buildInvalid()
                            : _buildForm(),
                  ),
                  const SizedBox(height: 18),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Terug naar inloggen'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 18),
          Text(
            'Resetlink wordt gevalideerd…',
            style: TextStyle(color: kTextTertiary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildInvalid() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: kDangerBg,
            borderRadius: BorderRadius.circular(kRadiusLg),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.link_off_rounded, size: 32, color: kDanger),
        ),
        const SizedBox(height: 22),
        const Text(
          'Resetlink ongeldig',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: kTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _tokenError ?? 'Deze resetlink is ongeldig of verlopen.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: kTextTertiary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: kBrandGreenSoft,
                borderRadius: BorderRadius.circular(kRadiusLg),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.verified_user_rounded,
                  size: 32, color: kBrandGreenDeep),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Nieuw wachtwoord instellen',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: kTextPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.email.isNotEmpty
                ? 'Stel hieronder een nieuw wachtwoord in voor ${widget.email}.'
                : 'Resetlink gevalideerd. Stel hieronder je nieuwe wachtwoord in.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: kTextTertiary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          _buildFieldLabel('Nieuw wachtwoord'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            enabled: !_isLoading,
            obscureText: !_isPasswordVisible,
            style: const TextStyle(
              fontSize: 14.5,
              color: kTextPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: _passwordDecoration(
              isVisible: _isPasswordVisible,
              toggleVisibility: () =>
                  setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Voer een nieuw wachtwoord in';
              }
              return PasswordPolicy.validate(value);
            },
          ),
          const SizedBox(height: 18),
          _buildFieldLabel('Bevestig wachtwoord'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmPasswordController,
            enabled: !_isLoading,
            obscureText: !_isConfirmPasswordVisible,
            style: const TextStyle(
              fontSize: 14.5,
              color: kTextPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: _passwordDecoration(
              isVisible: _isConfirmPasswordVisible,
              toggleVisibility: () => setState(
                  () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Bevestig je wachtwoord';
              }
              if (value != _passwordController.text) {
                return 'Wachtwoorden komen niet overeen';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleResetPassword,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Wachtwoord wijzigen',
                      style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
