import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// A reusable tappable settings tile used inside settings sections.
///
/// This widget displays:
/// - An icon (supports both [IconData] and HugeIcons)
/// - A title describing the setting action
/// - A subtitle providing additional context
/// - A tap callback for navigation or action handling
///
/// Common use cases:
/// - Opening help pages
/// - Navigating to external links
/// - Triggering settings actions (e.g., clear cache, logout)
///
/// The tile automatically adapts to light and dark themes for consistent UI.
class SettingSectionTapTile extends StatelessWidget {
  final dynamic icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const SettingSectionTapTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: icon is IconData
          ? Icon(icon, color: isDark ? Colors.grey.shade400 : Colors.black)
          : HugeIcon(
              icon: icon,
              color: isDark ? Colors.grey.shade400 : Colors.black,
            ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 15,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontWeight: FontWeight.normal,
          color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
        ),
      ),
      onTap: onTap,
    );
  }
}
