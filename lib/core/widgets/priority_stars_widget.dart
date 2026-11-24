import 'package:flutter/material.dart';

/// Displays priority as a star rating (1 to 3 stars).
///
/// Used to visually represent the priority level of tickets, tasks, or issues.
///
/// - `priority: "1"` → ★☆☆ (Low)
/// - `priority: "2"` → ★★☆ (Medium)
/// - `priority: "3"` → ★★★ (High)
///
/// Non-numeric values default to 0 stars (☆☆☆).
///
/// **Example Usage:**
///
/// ```dart
/// PriorityStarsWidget(priority: ticket.priority),
///
/// // Inside a ListTile or CustomKanbanTile:
/// PriorityStarsWidget(priority: "2"),
/// ```
class PriorityStarsWidget extends StatelessWidget {
  final String priority;

  const PriorityStarsWidget({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final starCount = int.tryParse(priority) ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Icon(
          index < starCount ? Icons.star : Icons.star_border,
          size: 16,
          color: Colors.amber,
        );
      }),
    );
  }
}
