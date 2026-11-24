import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_helpdesk/app/themes/app_colors.dart';

import '../../../../core/storage/storage_service.dart';
import '../../../../core/usecases/reset_session_usecase.dart';
import '../../../../core/widgets/dialog_button_style.dart';
import '../../../../core/widgets/restart_widget.dart';
import '../../../../core/widgets/snackbar.dart';
import '../../../../di/injection_container.dart' as di;
import '../../../login/presentation/pages/url_database_screen.dart';

/// A confirmation dialog that handles user logout from the application.
///
/// This dialog:
/// - Confirms whether the user really wants to log out
/// - Shows a loading state while logout is being processed
/// - Clears stored session and dependency injection state
/// - Restarts the app and navigates back to the login/server selection screen
///
/// It ensures a clean logout by:
/// - Resetting stored session data
/// - Reinitializing dependency injection container
/// - Forcing full app restart to clear runtime state
class LogoutDialog extends StatefulWidget {
  final StorageService storageService;

  const LogoutDialog({super.key, required this.storageService});

  @override
  LogoutDialogState createState() => LogoutDialogState();
}

class LogoutDialogState extends State<LogoutDialog> {
  bool isLogoutLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? Colors.grey[800] : Colors.white,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Confirm Logout",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 15),
          Text(
            'Are you sure you want to log out? Your session will be ended.',
            style: TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 15,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
      actions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: DialogButtonStyle.negativeButton(
                context: context,
                onPressed: () {
                  Navigator.pop(context);
                },
                title: 'Cancel',
              ),
            ),
            const SizedBox(width: 8),

            Expanded(
              child: DialogButtonStyle.successButton(
                context: context,
                onPressed: () async {
                  await _performLogout(context);
                },
                title: 'Log Out',
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Executes the full logout flow.
  ///
  /// Steps:
  /// 1. Shows a loading dialog while processing
  /// 2. Waits briefly to allow UI feedback
  /// 3. Clears session using [ResetSessionUseCase]
  /// 4. Resets and re-initializes dependency injection
  /// 5. Restarts the application statefully
  /// 6. Redirects user to [UrlDatabaseScreen]
  /// 7. Displays success message
  ///
  /// Ensures that all cached authentication and runtime state is cleared
  /// so the user starts fresh after logout.
  Future<void> _performLogout(BuildContext context) async {
    setState(() => isLogoutLoading = true);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Capture a stable navigator before popping, since this dialog's own
    // context becomes unmounted once the confirmation dialog is closed.
    final navigator = Navigator.of(context, rootNavigator: true);

    // Close the confirmation dialog so only the loading dialog is shown.
    navigator.pop();

    showDialog(
      context: navigator.context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LoadingAnimationWidget.fourRotatingDots(
                  color: AppColors.primary,
                  size: 50,
                ),
                const SizedBox(height: 20),
                Text(
                  "Logging out...",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Please wait while we process your request.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );

    await Future.delayed(const Duration(seconds: 2));

    await ResetSessionUseCase().execute();

    await di.sl.reset();
    await di.init();

    final navContext = navigator.context;
    if (navContext.mounted) {
      navigator.pop();
      RestartWidget.restartApp(navContext);
      navigator.pushReplacement(
        MaterialPageRoute(
          settings: const RouteSettings(name: UrlDatabaseScreen.routeName),
          builder: (_) => const UrlDatabaseScreen(),
        ),
      );
      CustomSnackBar.showSuccess(navContext, 'Logged out successfully');
    }
  }
}
