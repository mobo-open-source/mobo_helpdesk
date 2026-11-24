import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/session/models/session_model.dart';
import '../utils/login_navigator.dart';

/// A dialog displayed when the signed-in account is a portal (customer) user.
///
/// Portal users are outside users with limited access; they are never part of a
/// helpdesk group, so they cannot use this app at all. This is shown instead of
/// the generic "Access Denied" dialog, which suggests the problem can be solved
/// by granting rights.
///
/// Behaviour matches [ModuleMissingDialog]: the single action returns the user
/// to the screen the login started from via [backFromFailedLogin] - the
/// Configuration page in the "add account" flow, the server configuration
/// screen otherwise.
///
/// Parameters:
/// - [isAddAccount]: whether the dialog is shown during the add-account flow
/// - [currentSession]: session to keep when returning to the previous screen
/// - [initialUrl] / [initialDatabase]: server details used to prefill the
///   configuration screen if it has to be recreated
class PortalUserDialog extends StatelessWidget {
  final bool isAddAccount;
  final SessionModel? currentSession;
  final String? initialUrl;
  final String? initialDatabase;

  const PortalUserDialog({
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
            icon: HugeIcons.strokeRoundedUserBlock01,
            color: AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Portal Account',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        'Your account is a portal user and does not have access to this '
        'application. Please contact your administrator to update your Odoo '
        'access rights.',
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
