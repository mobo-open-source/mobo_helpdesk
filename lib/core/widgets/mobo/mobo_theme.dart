import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';

// Design tokens the Mobo form kit (select field, text field, buttons) reads,
// kept identical to the reference app's AppTheme so the widgets render the
// same here. Scoped to this folder; the app's own theme is untouched.

class AppTheme {
  static const Color primaryColor = AppColors.primary;
  static const Color white = Color(0xFFFFFFFF);
  static const Color dark = Color(0xFF101010);
  static const Color textPrimary = Color(0xFF101010);
  static const Color textSecondary = Color(0xFF666666);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color fieldFill = Color(0xFFF2F4F6);
  static const Color primaryTint = Color(0xFFFCE7EE);
  static const Color darkPopupSurface = Color(0xFF2C2C2E);
  static final Color inputFillDark = Colors.grey[850]!;

  static Color surface(bool isDark) => isDark ? darkSurface : white;
  static Color inputFill(bool isDark) => isDark ? inputFillDark : fieldFill;
  static Color textPrimaryOn(bool isDark) =>
      isDark ? Colors.white : textPrimary;
  static Color textSecondaryOn(bool isDark) =>
      isDark ? Colors.grey[400]! : textSecondary;

  static TextStyle fieldValueStyle(bool isDark) => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: isDark ? Colors.white : dark,
  );

  static TextStyle fieldHintStyle(bool isDark) => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: isDark ? Colors.white54 : Colors.grey[600],
  );

  static TextStyle fieldLabelStyle(bool isDark) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: isDark ? Colors.white70 : const Color(0xFF7F7F7F),
  );
}

class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
}

class StatusColors {
  static const Color red = Color(0xFFEF4444);
}
