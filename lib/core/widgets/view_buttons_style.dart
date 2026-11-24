import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../app/themes/app_colors.dart';

/// A helper class for styled action buttons.
///
/// Provides reusable button styles for common actions like
/// update and add/view, with consistent design and theme-aware
/// (light/dark) styling.
class ViewButtonsStyle {
  static Widget _buildButton(
    bool isDark,
    VoidCallback? onPressed,
    String title,
    dynamic icon,
  ) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      elevation: 0,
      shadowColor: Colors.transparent,
      disabledBackgroundColor: isDark ? Colors.grey[700]! : Colors.grey[400]!,
    );
    final label = Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
    );
    if (icon == null) {
      return ElevatedButton(onPressed: onPressed, style: style, child: label);
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: style,
      icon: HugeIcon(icon: icon, color: Colors.white, size: 20),
      label: label,
    );
  }

  static Widget createUpdateButtonStyle({
    required BuildContext context,
    required VoidCallback? onPressed,
    required String title,
    dynamic icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: double.infinity,
      child: _buildButton(isDark, onPressed, title, icon),
    );
  }

  static Widget addViewButtonStyle({
    required BuildContext context,
    required VoidCallback onPressed,
    required String title,
    required dynamic icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          // side: BorderSide(
          //   color: Colors.black
          // )
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: icon,
              size: 20,
              color: isDark ? Colors.white : Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
