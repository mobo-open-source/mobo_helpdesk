import 'package:flutter/material.dart';

/// "N groups" label with an Expand All / Collapse All toggle, shown above a
/// grouped list.
class GroupSummaryBar extends StatelessWidget {
  final int groupCount;
  final bool allExpanded;
  final ValueChanged<bool> onToggleAll;

  const GroupSummaryBar({
    super.key,
    required this.groupCount,
    required this.allExpanded,
    required this.onToggleAll,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white70 : Colors.black87;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$groupCount group${groupCount != 1 ? 's' : ''}',
            style: TextStyle(fontSize: 14, color: color.withValues(alpha: 0.7)),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onToggleAll(!allExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    allExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    allExpanded ? 'Collapse All' : 'Expand All',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
