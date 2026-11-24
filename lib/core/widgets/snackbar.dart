import 'package:flutter/material.dart';

import '../../app/themes/app_colors.dart';
import '../navigation/navigation_keys.dart';

enum SnackBarType { info, success, warning, error }

/// A utility class to show styled snack bars.
///
/// Supports different types like info, success, warning, and error.
/// Displays a custom floating SnackBar with icon, title, and message,
/// adapting colors based on theme (light/dark).
///
/// Provides helper methods like [showSuccess], [showError],
/// [showInfo], and [showWarning] for quick usage.
class CustomSnackBar {
  static void show({
    required BuildContext context,
    required String title,
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    try {
      if (!context.mounted) {
        return;
      }
      Theme.of(context);
    } catch (e) {
      return;
    }

    void tryShow() {
      try {
        final ScaffoldMessengerState? messenger =
            scaffoldMessengerKey.currentState;
        if (messenger == null || !messenger.mounted) {
          return;
        }

        BuildContext? themeCtx;
        try {
          themeCtx = navigatorKey.currentContext;
          if (themeCtx != null && themeCtx.mounted) {
            Theme.of(themeCtx);
          } else {
            themeCtx = null;
          }
        } catch (e) {
          themeCtx = null;
        }

        _showWithMessenger(messenger, themeCtx, title, message, type, duration);
      } catch (_) {}
    }

    tryShow();
  }

  static void _showWithMessenger(
    ScaffoldMessengerState messenger,
    BuildContext? themeContext,
    String title,
    String message,
    SnackBarType type,
    Duration duration,
  ) {
    try {
      if (!messenger.mounted) {
        return;
      }

      bool isDark = false;
      if (themeContext != null && themeContext.mounted) {
        try {
          isDark = Theme.of(themeContext).brightness == Brightness.dark;
        } catch (e) {
          isDark = false;
        }
      }
      final colors = _getColorsForType(type, isDark);

      if (!messenger.mounted) {
        return;
      }

      try {
        messenger.hideCurrentSnackBar();
      } catch (_) {}

      try {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colors.iconBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(colors.icon, size: 16, color: colors.iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[300] : Colors.grey[100],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: colors.backgroundColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: duration,
            elevation: 8,
          ),
        );
      } catch (_) {}
    } catch (_) {}
  }

  static _SnackBarColors _getColorsForType(SnackBarType type, bool isDark) {
    switch (type) {
      case SnackBarType.info:
        return _SnackBarColors(
          icon: Icons.info_outline,
          iconColor: Colors.blue[300]!,
          iconBackgroundColor: Colors.blue.withValues(alpha: 0.2),
          backgroundColor: isDark
              ? AppColors.infoBackgroundDark
              : AppColors.infoBackgroundLight,
        );
      case SnackBarType.success:
        return _SnackBarColors(
          icon: Icons.check_circle_outline,
          iconColor: Colors.green[300]!,
          iconBackgroundColor: Colors.green.withValues(alpha: 0.2),
          backgroundColor: isDark
              ? AppColors.successBackgroundDark
              : AppColors.successBackgroundLight,
        );
      case SnackBarType.warning:
        return _SnackBarColors(
          icon: Icons.warning_outlined,
          iconColor: Colors.orange[300]!,
          iconBackgroundColor: Colors.orange.withValues(alpha: 0.2),
          backgroundColor: isDark
              ? AppColors.warningBackgroundDark
              : AppColors.warningBackgroundLight,
        );
      case SnackBarType.error:
        return _SnackBarColors(
          icon: Icons.error_outline,
          iconColor: Colors.red[300]!,
          iconBackgroundColor: Colors.red.withValues(alpha: 0.2),
          backgroundColor: isDark
              ? AppColors.errorBackgroundDark
              : AppColors.errorBackgroundLight,
        );
    }
  }

  static void showSuccess(BuildContext context, String message) {
    show(
      context: context,
      title: 'Success',
      message: message,
      type: SnackBarType.success,
    );
  }

  static void showError(BuildContext context, String message) {
    show(
      context: context,
      title: 'Error',
      message: message,
      type: SnackBarType.error,
    );
  }

  static void showInfo(BuildContext context, String message) {
    show(
      context: context,
      title: 'Info',
      message: message,
      type: SnackBarType.info,
    );
  }

  static void showWarning(BuildContext context, String message) {
    show(
      context: context,
      title: 'Warning',
      message: message,
      type: SnackBarType.warning,
    );
  }
}

class _SnackBarColors {
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final Color backgroundColor;

  _SnackBarColors({
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.backgroundColor,
  });
}
