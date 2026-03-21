import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String? initialToken;

  const ResetPasswordScreen({
    super.key,
    this.email = '',
    this.initialToken,
  });

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
      await ApiService.verifyResetToken(token);
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

      await ApiService.resetPassword(
        token: token,
        password: password,
        confirmPassword: confirmPassword,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wachtwoord succesvol gewijzigd. Log nu in met je nieuwe wachtwoord.'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to login screen
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Green Header
          Container(
            width: double.infinity,
            height: 80,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7CB342), Color(0xFF8BC34A)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text(
                    'vlotter',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        if (_isCheckingToken)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7CB342)),
                            ),
                          ),
                        if (!_isCheckingToken && !_isTokenValid)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFEF9A9A)),
                            ),
                            child: Text(
                              _tokenError ?? 'Deze resetlink is ongeldig of verlopen.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFB71C1C)),
                            ),
                          ),
                        if (!_isCheckingToken && !_isTokenValid)
                          const SizedBox(height: 16),
                        if (!_isCheckingToken && !_isTokenValid)
                          TextButton(
                            onPressed: () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                            ),
                            child: const Text('Terug naar inloggen'),
                          ),
                        if (_isCheckingToken || !_isTokenValid) const SizedBox.shrink(),
                        if (!_isCheckingToken && _isTokenValid) ...[
                        Center(
                          child: Icon(
                            Icons.verified_user,
                            size: 80,
                            color: const Color(0xFF7CB342),
                          ),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'Nieuw Wachtwoord Maken',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (widget.email.isNotEmpty)
                          Text(
                            'Resetcode is verzonden naar:\n${widget.email}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          )
                        else
                          const Text(
                            'Resetlink gevalideerd. Stel hieronder je nieuwe wachtwoord in.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        const SizedBox(height: 40),
                        // New Password field
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Wachtwoord',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              enabled: !_isLoading,
                              obscureText: !_isPasswordVisible,
                              decoration: InputDecoration(
                                hintText: '••••••••••••••••',
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() => _isPasswordVisible = !_isPasswordVisible);
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFF7CB342)),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Voer een nieuw wachtwoord in';
                                }
                                if (value.length < 8) {
                                  return 'Wachtwoord moet minstens 8 tekens zijn';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Confirm Password field
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bevestig Wachtwoord',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _confirmPasswordController,
                              enabled: !_isLoading,
                              obscureText: !_isConfirmPasswordVisible,
                              decoration: InputDecoration(
                                hintText: '••••••••••••••••',
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFF7CB342)),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
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
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: 350,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleResetPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7CB342),
                              disabledBackgroundColor: Colors.grey[400],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Wachtwoord Opnieuw Instellen',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          ),
                          child: const Text(
                            'Terug naar inloggen',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
