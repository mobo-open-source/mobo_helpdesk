import 'package:flutter/material.dart';

import '../../../../core/utils/safe_utils.dart';
import '../../../../core/widgets/custom_form_tile.dart';

/// Builds the UI for the "Create Ticket" form section.
///
/// This widget renders a structured form layout containing multiple
/// input fields required to create a support ticket, including:
/// - Ticket name
/// - Priority
/// - Type
/// - Partner details
/// - Contact information (phone, email CC)
/// - Tags
/// - Description
///
/// The layout is wrapped inside a styled `CustomFormTile` container
/// and adapts its colors based on the current theme mode.
///
/// [isDark] controls the theme styling for text and UI elements.
Widget buildCreateView(bool isDark) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CustomFormTile.tileStyle(
        isDark: isDark,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Ticket',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              buildFormField(title: "Ticket Name", isDark: isDark),
              SizedBox(height: 12),
              buildFormField(title: "Priority", isDark: isDark),
              SizedBox(height: 12),
              buildFormField(title: "Type", isDark: isDark),
              SizedBox(height: 12),
              buildFormField(title: "Partner", isDark: isDark),
              SizedBox(height: 12),
              buildFormField(title: "Phone", isDark: isDark),
              SizedBox(height: 12),
              buildFormField(title: "Email CC", isDark: isDark),
              SizedBox(height: 12),
              buildFormField(title: "Tags", isDark: isDark),
              SizedBox(height: 12),
              buildFormField(title: "Description", isDark: isDark),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget buildFormField({
  required String title,
  String? value,
  bool isDark = false,
  Widget? trailing,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      CustomFormTile.tileTitleText(title: title, isDark: isDark),
      SizedBox(width: 10),
      trailing ??
          CustomFormTile.tileValueText(
            value: safeViewText(value),
            isDark: isDark,
          ),
    ],
  );
}
