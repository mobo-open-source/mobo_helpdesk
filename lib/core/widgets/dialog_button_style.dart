import 'package:flutter/material.dart';

import '../../app/themes/app_colors.dart';

/// A utility class that provides consistent button styles for dialog boxes.
///
/// This class contains static methods to create three types of dialog buttons:
/// - **Success button** (primary action - filled)
/// - **Cancel button** (secondary action - outlined)
/// - **Negative button** (destructive action - subtle outlined)
///
/// All buttons automatically adapt to light and dark themes and follow the app's
/// design system with consistent border radius, typography, and colors.
class DialogButtonStyle {
  /// Space between a button's edge and its label, so a long label never
  /// touches the border.
  static const double horizontalPadding = 16;

  /// Every dialog button is at least this tall, so a pair always lines up.
  static const double minHeight = 48;

  /// Creates a prominent success/primary button suitable for affirmative actions
  /// such as "Save", "Confirm", "Yes", "Submit", etc.
  ///
  /// In light mode: Uses [AppColors.primary] background with white text.
  /// In dark mode: Uses white background with black text (high contrast).
  static Widget successButton({
    required BuildContext context,
    required VoidCallback? onPressed,
    required String title,
    bool destructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = onPressed != null;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(0, minHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 12,
        ),
        backgroundColor: isEnabled
            ? AppColors.primary
            : (isDark ? Colors.grey[600] : Colors.grey[300]),
        foregroundColor: isEnabled
            ? Colors.white
            : (isDark ? Colors.grey[400] : Colors.grey[500]),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  /// Creates a subtle negative/destructive button (e.g., "Delete", "Remove", "No").
  ///
  /// Uses a neutral gray border and text to indicate lower priority or caution
  /// without being as aggressive as a full red button.
  static Widget negativeButton({
    required BuildContext context,
    required VoidCallback onPressed,
    required String title,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, minHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 12,
        ),
        foregroundColor: AppColors.primary,
        backgroundColor: isDark ? Colors.grey[800] : Colors.white,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
    );
  }
}
