import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/session/models/session_model.dart';
import '../utils/login_navigator.dart';

/// A dialog displayed when a user attempts to log in but does not have the
/// required "Helpdesk Administrator" group.
///
/// Same layout as the "Module Missing" and "Portal Account" notices: an alert
/// icon beside the heading, the explanation below it and a single full-width
/// action. Light and dark surfaces follow the active theme.
///
/// When [returnToConfiguration] is true (login / add-account flows), dismissing
/// the dialog returns to the configuration screen the user came from via
/// [backFromFailedLogin] instead of only closing the dialog.
class AccessDeniedDialog extends StatelessWidget {
  final bool returnToConfiguration;
  final bool isAddAccount;
  final SessionModel? currentSession;

  /// Server URL / database being configured, used to prefill the configuration
  /// screen when it has to be recreated.
  final String? initialUrl;
  final String? initialDatabase;

  const AccessDeniedDialog({
    super.key,
    this.returnToConfiguration = false,
    this.isAddAccount = false,
    this.currentSession,
    this.initialUrl,
    this.initialDatabase,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E1E1E) : AppColors.white;
    final textPrimary = isDark ? AppColors.white : AppColors.textPrimary;
    final textSecondary = isDark ? Colors.white70 : AppColors.textSecondary;

    return AlertDialog(
      backgroundColor: surface,
      surfaceTintColor: surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedAlertCircle,
            color: AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Access Denied',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        'Your account does not have Helpdesk Module Access. Please contact '
        'your system administrator to update your Odoo access rights.',
        style: GoogleFonts.manrope(
          fontSize: 15,
          height: 1.5,
          color: textSecondary,
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () {
              if (returnToConfiguration) {
                backFromFailedLogin(
                  context,
                  isAddAccount: isAddAccount,
                  currentSession: currentSession,
                  initialUrl: initialUrl,
                  initialDatabase: initialDatabase,
                );
              } else {
                Navigator.of(context).pop();
              }
            },
            child: Text(
              'OK',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
