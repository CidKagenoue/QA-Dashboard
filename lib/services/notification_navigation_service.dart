import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qa_dashboard/screens/account_management_screen.dart';
import '../models/app_notification.dart';
import '../services/auth_service.dart';
import '../screens/home_screen.dart';
import '../screens/ova_ticket_wizard_screen.dart';
import '../screens/maintenance_inspections_screen.dart';

class NotificationNavigationService {
  /// Navigeert naar het juiste scherm op basis van de melding.
  /// 
  /// Retourneert true als navigatie plaatsvond, false als geen actie kon worden ondernomen.
  static Future<bool> openContext(
    BuildContext context,
    AppNotification notification,
  ) async {
    try {
      // OVA-tickets: navigeer naar OVA ticket wizard
      if (notification.type.startsWith('OVA_') && notification.metadata != null) {
        final ticketId = notification.metadata?['ticketId'];
        if (ticketId != null) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => OvaTicketWizardScreen(
                ticketId: ticketId,
              ),
            ),
          );
          return true;
        }
      }

      // Opvolgacties (OVA_DEADLINE): navigeer naar OVA-acties
      if (notification.type.contains('DEADLINE') && 
          notification.metadata != null &&
          notification.metadata!.containsKey('ticketId')) {
        final ticketId = notification.metadata?['ticketId'];
        if (ticketId != null) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => OvaTicketWizardScreen(
                ticketId: ticketId,
              ),
            ),
          );
          return true;
        }
      }

      // Onderhoud/Keuring (MAINTENANCE_DUE, MAINTENANCE_NEW): navigeer naar maintenance
      if (notification.type.startsWith('MAINTENANCE_')) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const MaintenanceInspectionsScreen(),
          ),
        );
        return true;
      }

      // JAP/GPP: navigeer naar JAP detail scherm
      if ((notification.type.startsWith('JAP_') || notification.type.startsWith('GPP_')) &&
          notification.metadata != null) {
        final entryId = _readEntryId(notification.metadata);
        if (entryId == null) {
          return false;
        }

        final authService = context.read<AuthService>();
        if (!authService.isAuthenticated) {
          return false;
        }

        final navigator = Navigator.of(context);
        await authService.getValidAccessToken();

        await navigator.push(
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              initialSectionKey: 'japGpp',
              initialJapGppModule: notification.type.startsWith('GPP_') ? 'GPP' : 'JAP',
              initialJapGppEntryId: entryId,
            ),
          ),
        );
        return true;
      }

      // Account-meldingen: navigeer naar account management
      if (notification.type.startsWith('ACCOUNT_')) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const AccountManagementScreen(),
          ),
        );
        return true;
      }

      // Password-meldingen: navigeer naar profiel
      if (notification.source == 'reset-password' || 
          notification.source == 'change-password') {
        // Optioneel: navigeer naar profiel voor wachtwoord wijzigen
        return false; // Voor nu: geen navigatie, alleen dialoog tonen
      }

      return false;
    } catch (e) {
      debugPrint('Error during notification navigation: $e');
      return false;
    }
  }

  static int? _readEntryId(Map<String, dynamic>? metadata) {
    final rawId = metadata?['entryId'] ?? metadata?['japGppId'] ?? metadata?['id'];
    if (rawId is num) {
      return rawId.toInt();
    }
    if (rawId is String) {
      return int.tryParse(rawId);
    }
    return null;
  }
}


