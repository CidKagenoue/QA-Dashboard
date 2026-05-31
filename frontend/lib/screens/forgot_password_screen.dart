import 'package:flutter/material.dart';
import '../services/auth_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/vlotter_logo.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isSent = false;
  String? _emailApiError;

  String _formatErrorMessage(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '');
    if (raw.startsWith('Error: ')) {
      return raw.substring(7);
    }
    return raw;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetLink() async {
    setState(() => _emailApiError = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      await AuthApiService.forgotPassword(email);

      setState(() {
        _isLoading = false;
        _isSent = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _emailApiError = _formatErrorMessage(e);
      });
    }
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
                    child: _isSent ? _buildSuccess() : _buildForm(),
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
              child: const Icon(Icons.lock_reset_rounded,
                  size: 32, color: kBrandGreenDeep),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Wachtwoord herstellen',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: kTextPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Voer je e-mailadres in en we sturen je een link om je wachtwoord opnieuw in te stellen.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: kTextTertiary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'E-mailadres',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: kTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            enabled: !_isLoading,
            onChanged: (_) {
              if (_emailApiError != null) {
                setState(() => _emailApiError = null);
              }
            },
            style: const TextStyle(
              fontSize: 14.5,
              color: kTextPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'naam@vlotter.be',
              hintStyle: const TextStyle(color: kTextMuted),
              prefixIcon:
                  const Icon(Icons.mail_outline_rounded, color: kTextTertiary),
              errorText: _emailApiError,
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
                  borderSide:
                      const BorderSide(color: kBrandGreen, width: 1.6)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Voer je e-mailadres in';
              }
              if (!value.contains('@')) {
                return 'Voer een geldig e-mailadres in';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSendResetLink,
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
                      'Stuur resetlink',
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

  Widget _buildSuccess() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: kSuccessBg,
            borderRadius: BorderRadius.circular(kRadiusLg),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.mark_email_read_rounded,
              size: 32, color: kSuccess),
        ),
        const SizedBox(height: 22),
        const Text(
          'Resetlink verzonden',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: kTextPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We hebben een e-mail gestuurd naar ${_emailController.text.trim()}. Controleer je inbox (en eventueel de spam) om verder te gaan.',
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
}
