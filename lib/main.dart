import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qa_dashboard/screens/account_management_screen.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/reset_password_screen.dart';
import 'services/account_management_service.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QADashboardApp());
}

class QADashboardApp extends StatelessWidget {
  const QADashboardApp({super.key});

  Widget _buildInitialScreen() {
    final uri = Uri.base;

    if (uri.path == '/account-management') {
      return const AccountManagementScreen();
    }

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
        ChangeNotifierProxyProvider<AuthService, AccountManagementService>(
          create: (_) => AccountManagementService(),
          update: (_, authService, accountManagementService) {
            final service =
                accountManagementService ?? AccountManagementService();
            service.bindAuth(authService);
            return service;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Vlotter',
        theme: buildAppTheme(),
        home: _buildInitialScreen(),
        routes: {'/account-management': (_) => const AccountManagementScreen()},
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
        if (authService.isInitializing) {
          return const _LaunchScreen();
        }

        if (authService.isAuthenticated) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
