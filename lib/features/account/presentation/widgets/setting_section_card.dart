import 'package:flutter/material.dart';

/// A reusable container card used to group related settings items.
///
/// This widget is commonly used in settings screens to visually separate
/// different configuration sections such as:
/// - Appearance
/// - Security
/// - Language & Region
/// - Data & Storage
/// - Help & Support
///
/// Features:
/// - Displays a section title at the top
/// - Wraps child widgets inside a styled card container
/// - Automatically adapts to light and dark themes
/// - Applies consistent spacing, elevation, and rounded corners
///
/// This helps maintain a structured and visually organized settings UI.
class SettingsSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const SettingsSectionCard({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}
