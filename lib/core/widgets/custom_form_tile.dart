import 'package:flutter/material.dart';

/// A utility class that provides reusable styled widgets for consistent form tiles
/// across the app.
///
/// This class contains static methods to create commonly used form elements with
/// consistent theming (light/dark mode support), including containers, titles,
/// subtitles, and value texts. All widgets follow the app's design system with
/// proper shadows, border radius, and color schemes.
class CustomFormTile {
  /// Returns a styled container for form tiles with consistent margin, background,
  /// border radius, and shadow based on the current theme.
  ///
  /// [child] is the content to be wrapped inside the styled container.
  /// [isDark] determines whether to use dark mode colors and shadows.
  static Widget tileStyle({
    required Widget child,
    required bool isDark,
    double bottomMargin = 24,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        margin: EdgeInsets.only(bottom: bottomMargin),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  /// Returns a title text widget for regular form tiles.
  ///
  /// The text uses a medium weight and appropriate gray color for the current theme.
  ///
  /// [title] is the text to display.
  /// [isDark] determines the text color for light/dark mode.
  static Widget tileTitleText({required String title, required bool isDark}) {
    return Expanded(
      child: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Returns a bold title text widget specifically designed for boolean/switch tiles.
  ///
  /// Uses a slightly bolder font weight (`w600`) compared to regular titles.
  ///
  /// [title] is the text to display.
  /// [isDark] determines the text color for light/dark mode.
  static Widget tileBoolTitleText({
    required String title,
    required bool isDark,
  }) {
    return Expanded(
      child: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Returns a subtitle text widget for boolean/switch tiles.
  ///
  /// Uses a lighter font weight and softer gray color, suitable for descriptive text.
  ///
  /// [title] is the text to display.
  /// [isDark] determines the text color for light/dark mode.
  static Widget tileBoolSubTitleText({
    required String title,
    required bool isDark,
  }) {
    return Text(
      title,
      style: TextStyle(
        color: isDark ? Colors.grey[300] : Colors.grey[500],
        fontWeight: FontWeight.normal,
      ),
    );
  }

  /// Returns a right-aligned value text for form tiles (e.g., selected values, dates, etc.).
  ///
  /// The text is expanded to take available space and aligned to the end.
  ///
  /// [value] is the text to display.
  /// [isDark] determines the text color for light/dark mode.
  static Widget tileValueText({required String value, required bool isDark}) {
    return Expanded(
      child: Text(
        value,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.normal,
          fontSize: 14,
        ),
        textAlign: TextAlign.end,
      ),
    );
  }

  /// Returns a time/value text widget without Expanded wrapper.
  ///
  /// Useful when you need to place the value text manually (e.g., inside a Row with
  /// specific layout requirements).
  ///
  /// [value] is the text to display.
  /// [isDark] determines the text color for light/dark mode.
  static Widget tileTimeValueText({
    required String value,
    required bool isDark,
  }) {
    return Text(
      value,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontWeight: FontWeight.normal,
        fontSize: 14,
      ),
      textAlign: TextAlign.end,
    );
  }
}
