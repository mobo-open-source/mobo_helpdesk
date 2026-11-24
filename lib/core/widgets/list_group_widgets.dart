import 'package:flutter/material.dart';
import 'package:mobo_helpdesk/core/widgets/priority_stars_widget.dart';

/// A collapsible group widget used to organize list items into expandable sections.
///
/// This widget displays a header with a group name (or priority stars) and description,
/// and allows the user to expand/collapse the content below it. It is commonly used
/// in filtered or grouped lists (e.g., tickets grouped by status, priority, assignee, etc.).
///
/// Features:
/// * Consistent card-style design with shadow and border
/// * Automatic dark mode support
/// * Special handling for priority groups using [PriorityStarsWidget]
/// * Smooth expand/collapse behavior
class ListGroupWidgets extends StatelessWidget {
  final String groupName;
  final String description;
  final VoidCallback onTap;
  final Widget child;
  final bool expanded;
  final String? groupBy;
  final bool isActivity;
  final Color? groupColor;

  const ListGroupWidgets({
    super.key,
    required this.groupName,
    required this.description,
    required this.onTap,
    required this.child,
    required this.expanded,
    this.groupBy,
    this.isActivity = false,
    this.groupColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isPriorityGroup = groupBy == 'priority';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          if (!isDark && !isActivity)
            BoxShadow(
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 6),
              color: Colors.black.withValues(alpha: 0.08),
            ),
        ],
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isPriorityGroup)
                          PriorityStarsWidget(priority: groupName)
                        else
                          Text(
                            groupName,
                            style: TextStyle(
                              color:
                                  groupColor ??
                                  (isDark ? Colors.white : Colors.black),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ],
              ),
            ),
          ),

          if (expanded) child,
        ],
      ),
    );
  }
}
