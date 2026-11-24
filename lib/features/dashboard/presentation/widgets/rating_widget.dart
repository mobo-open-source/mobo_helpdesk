import 'package:flutter/material.dart';

import 'custom_dashboard_tile.dart';

/// Creates a compact rating display widget with a star icon and value.
///
/// This widget is used in the team support section of the dashboard to show
/// the average customer rating (e.g., "4.5") next to a star icon.
///
/// The rating value is rendered using [CustomDashboardTile.tileValueText]
/// to maintain consistent styling with the rest of the dashboard.
///
/// Parameters:
///   - [rating]: The rating value as a string (e.g., "4.5", "3.8").
///   - [isDark]: Whether the current theme is dark mode. Passed through to
///               [tileValueText] for proper text color adaptation.
///
/// Returns:
///   A [Row] containing an amber star icon followed by the formatted rating text.
Widget ratingWidget({required String rating, required bool isDark}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
      const SizedBox(width: 4),
      CustomDashboardTile.tileValueText(value: rating, isDark: isDark),
    ],
  );
}
