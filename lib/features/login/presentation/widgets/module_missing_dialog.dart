import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/session/models/session_model.dart';
import '../utils/login_navigator.dart';

/// A dialog displayed when the required "Helpdesk" module is not installed
/// on the selected server/database.
///
/// This dialog informs the user that the current Odoo instance is missing
/// the required module needed for application functionality.
///
/// Features:
/// - Displays a warning icon and descriptive message
/// - Uses a consistent styled AlertDialog UI
/// - Provides a single action button to navigate back to the login flow
/// - Supports both normal login and "add account" flows
/// - Restores session context when navigating back (if available)
///
/// Behavior:
/// - On confirmation, returns to the configuration screen the user came from
///   via [backFromFailedLogin], keeping the URL/database already entered
/// - Falls back to a fresh configuration screen when that route is gone
///
/// Parameters:
/// - [isAddAccount]: Indicates whether the dialog is shown during add-account flow
/// - [currentSession]: Optional session data used to restore previous state
///
/// Example:
/// ```dart
/// ModuleMissingDialog(
///   isAddAccount: false,
class ModuleMissingDialog extends StatelessWidget {
  final bool isAddAccount;
  final SessionModel? currentSession;

  /// Server URL / database being configured, used to prefill the configuration
  /// screen when it has to be recreated.
  final String? initialUrl;
  final String? initialDatabase;

  const ModuleMissingDialog({
    super.key,
    required this.isAddAccount,
    this.currentSession,
    this.initialUrl,
    this.initialDatabase,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      title: Row(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedAlertCircle,
            color: AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            'Module Missing',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.black,
            ),
          ),
        ],
      ),
      content: Text(
        'The required "Helpdesk" module is not installed. Please contact your administrator to enable it.',
        style: GoogleFonts.manrope(
          fontSize: 15,
          color: Colors.black87,
          height: 1.5,
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
            ),
            onPressed: () {
              backFromFailedLogin(
                context,
                isAddAccount: isAddAccount,
                currentSession: currentSession,
                initialUrl: initialUrl,
                initialDatabase: initialDatabase,
              );
            },
            child: Text(
              'Back to Login',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
