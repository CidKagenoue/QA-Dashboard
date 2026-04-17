import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../screens/account_management_page.dart';
import '../screens/ova_ticket_wizard_screen.dart';

class NotificationNavigationService {
  static Future<bool> openContext(
    BuildContext context,
    AppNotification notification,
  ) async {
    if (notification.ticketId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OvaTicketWizardScreen(
            ticketId: notification.ticketId,
          ),
        ),
      );
      return true;
    }

    if (notification.accountId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const AccountManagementPage(),
        ),
      );
      return true;
    }

    return false;
  }
}
