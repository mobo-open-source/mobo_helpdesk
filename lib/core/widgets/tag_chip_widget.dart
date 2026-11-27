import 'package:flutter/material.dart';
import 'package:mobo_helpdesk/app/themes/app_colors.dart';

import '../utils/odoo_colors.dart';

/// Builds a list of tag chips.
///
/// Displays tags as styled chips using provided data.
/// If no tags are available, shows a placeholder ("—").
///
/// Colors are assigned from predefined values or generated
/// dynamically based on the tag name, with styling adapted
/// for light and dark themes.
///
///
Widget buildTagChips(List<Map<String, dynamic>> tags, bool isDark) {
  if (tags.isEmpty) {
    return Text(
      "—",
      style: TextStyle(
        fontWeight: FontWeight.normal,
        fontSize: 14,
        color: isDark ? Colors.white : Colors.black,
      ),
    );
  }
  return Wrap(
    spacing: 6,
    runSpacing: 6,
    children: tags.map((tag) {
      final name = tag['name'] ?? tag['display_name'] ?? '';
      final colorIndex = tag['color'] ?? 0;
      final hasColor = tag.containsKey('color') && tag['color'] != false;

      final color = hasColor
          ? odooColor(colorIndex)
          : getTicketStatusColor(name);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? color.withValues(alpha: 0.6)
              : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : color,
          ),
        ),
      );
    }).toList(),
  );
}

Widget buildChips(List<Map<String, dynamic>> tags, bool isDark) {
  if (tags.isEmpty) {
    return Text(
      "—",
      style: TextStyle(
        fontWeight: FontWeight.normal,
        fontSize: 14,
        color: isDark ? Colors.white : Colors.black,
      ),
    );
  }
  return Wrap(
    spacing: 6,
    runSpacing: 6,
    children: tags.map((tag) {
      final name = tag['name'] ?? tag['display_name'] ?? '';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary, width: 1),
        ),
        child: Text(
          name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.primary,
          ),
        ),
      );
    }).toList(),
  );
}

Widget buildText(List<Map<String, dynamic>> tags, bool isDark) {
  if (tags.isEmpty) {
    return Text(
      "—",
      style: TextStyle(
        fontWeight: FontWeight.normal,
        fontSize: 14,
        color: isDark ? Colors.white : Colors.black,
      ),
    );
  }
  return Wrap(
    spacing: 6,
    runSpacing: 6,
    children: tags.map((tag) {
      final name = tag['name'] ?? tag['display_name'] ?? '';
      return Container(
        padding: const EdgeInsets.only(left: 10),
        child: Text(
          name,
          style: TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          textAlign: TextAlign.end,
        ),
      );
    }).toList(),
  );
}
