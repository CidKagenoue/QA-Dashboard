import 'package:flutter/material.dart';

import 'account_management_screen.dart';

class AccountManagementPage extends StatelessWidget {
  const AccountManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accountbeheer')),
      body: const AccountManagementScreen(),
    );
  }
}
