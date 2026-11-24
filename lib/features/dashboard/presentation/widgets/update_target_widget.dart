import 'package:flutter/material.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/widgets/dialog_button_style.dart';

/// Opens a dialog to edit performance targets (Closed Tickets, SLA Success Rate, or Average Rating)
/// when "Daily Target" mode is selected in the dashboard.
///
/// This dialog allows the user to modify their daily goals and triggers the
/// [UpdateTargetEvent] via the provided [onSave] callback.
///
/// Parameters:
///   - [context]: The build context used to show the dialog and determine theme.
///   - [title]: The name of the target being edited (e.g., "Closed Tickets", "SLA Success Rate").
///   - [description]: Helper text explaining what the target represents.
///   - [isRate]: If `true`, the input field accepts decimal numbers and shows a "%" suffix.
///               Used for SLA Success Rate and Average Rating.
///   - [initialValue]: The current value to pre-fill in the text field.
///   - [onSave]: Callback invoked when the user taps "Save". Receives the trimmed input value.
///
/// Behavior:
///   - Automatically adapts to light/dark theme.
///   - Uses numeric keyboard (with decimal support when [isRate] is true).
///   - Shows a percent icon for rate-based targets.
///   - Validates that the input is not empty before saving.
///   - Uses custom styled buttons via [DialogButtonStyle].
void openEditDialog({
  required BuildContext context,
  required String title,
  required String description,
  required bool isRate,
  required String initialValue,
  required Function(String value) onSave,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final controller = TextEditingController(text: initialValue);

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: isDark ? Colors.grey[800] : Colors.white,
        title: Text(
          "Edit $title",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 15),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFF8F9FA),
                border: Border.all(color: Colors.transparent, width: 1),
              ),
              child: TextFormField(
                controller: controller,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                keyboardType: isRate
                    ? TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.number,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  hintText: controller.text.isEmpty ? 'Enter Value' : null,
                  hintStyle: TextStyle(
                    fontFamily: TextStyle(
                      fontWeight: FontWeight.w600,
                    ).fontFamily,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                    fontStyle: FontStyle.italic,
                    fontSize: 14,
                    height: 1.0,
                  ),
                  suffixIcon: isRate
                      ? Icon(
                          Icons.percent,
                          size: 20,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xff7F7F7F),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white : AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: DialogButtonStyle.negativeButton(
                  context: context,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  title: 'Cancel',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DialogButtonStyle.successButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isEmpty) return;

                    onSave(value);
                    Navigator.pop(context);
                  },
                  title: "Save",
                  context: context,
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
