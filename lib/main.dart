import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reset_password_screen.dart';

void main() {
  runApp(const QADashboardApp());
}

class QADashboardApp extends StatelessWidget {
  const QADashboardApp({super.key});

  Widget _buildInitialScreen() {
    final uri = Uri.base;

    if (uri.path == '/reset-password') {
      return ResetPasswordScreen(
        email: '',
        initialToken: uri.queryParameters['token'],
      );
    }

    return const AuthWrapper();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthService(),
      child: MaterialApp(
        title: 'QA Dashboard',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: _buildInitialScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        if (authService.isAuthenticated) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}