import 'package:flutter/material.dart';

/// Simple placeholder widget for empty states with icon, title, and description.
///
/// Designed to provide a friendly and consistent "no data" experience across the app.
/// It is typically used inside `Center`, `Column`, or `ListView` when content is empty.
///
/// **Example Usage:**
///
/// ```dart
/// PlaceholderCard(
///   icon: Icons.inbox_outlined,
///   title: "No tickets yet",
///   description: "When you create tickets, they will appear here.",
///   isDark: Theme.of(context).brightness == Brightness.dark,
/// )
/// ```
class PlaceholderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isDark;
  final double iconSize;

  const PlaceholderCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.isDark = false,
    this.iconSize = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(
            icon,
            size: iconSize,
            color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
            ),
          ),
        ],
      ),
    );
  }
}
