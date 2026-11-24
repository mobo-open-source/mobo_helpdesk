import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import '../utils/decimal_input_format.dart';
import 'mobo/mobo_form_field.dart';
import 'mobo/mobo_theme.dart';

/// A labelled text field that is a plain value in view mode and an input in
/// edit mode.
///
/// [validator] returns the message to show under the field (with a red
/// outline), or null when the value is fine; it is re-run on every keystroke.
/// [keyboardType] and [inputFormatters] override the defaults picked from
/// [fieldName].
class EditControllerField extends StatelessWidget {
  final dynamic icon;
  final String fieldName;
  final TextEditingController controller;
  final bool isFieldEdit;
  final bool isAddress;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final bool isDescription;
  final bool idNotNameShow;
  final bool isRequired;
  final String? Function(String)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const EditControllerField({
    super.key,
    this.icon,
    required this.fieldName,
    required this.controller,
    this.isFieldEdit = false,
    this.isAddress = false,
    this.onTap,
    this.onChanged,
    this.isDescription = false,
    this.idNotNameShow = false,
    this.isRequired = false,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayValue = controller.text.isEmpty ? 'Not set' : controller.text;

    Widget buildLabel() {
      if (!isRequired) {
        return Text(
          fieldName,
          style: TextStyle(
            fontFamily: GoogleFonts.manrope(
              fontWeight: FontWeight.w400,
            ).fontFamily,
            color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
          ),
        );
      }
      return RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: fieldName,
              style: TextStyle(
                fontFamily: GoogleFonts.manrope(
                  fontWeight: FontWeight.w400,
                ).fontFamily,
                color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
              ),
            ),
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    Widget buildIcon({bool forEditMode = false}) {
      if (icon == null) return const SizedBox.shrink();
      final color = isDark ? Colors.white70 : Colors.black;
      if (icon is IconData) {
        return Icon(icon as IconData, size: 20, color: color);
      }
      return HugeIcon(icon: icon, size: 20, color: color);
    }

    if (isFieldEdit) {
      return Focus(
        child: Builder(
          builder: (ctx) {
            final hasFocus = Focus.of(ctx).hasFocus;
            return ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final error = validator?.call(value.text);
                final hasError = error != null;
                // The same look as the select fields (MoboSingleSelectField),
                // so a text field and a dropdown stacked on one card line up:
                // same fill, 48px minimum height, 12px inset, 15px text and
                // the same 2px ring for focus and error.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!idNotNameShow)
                      MoboFieldLabel(fieldName, isRequired: isRequired),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppTheme.inputFill(isDark),
                        border: Border.all(
                          color: hasError
                              ? StatusColors.red
                              : hasFocus
                              ? AppTheme.primaryColor
                              : Colors.transparent,
                          width: hasError || hasFocus ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          buildIcon(forEditMode: true),
                          if (icon != null) const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              inputFormatters:
                                  inputFormatters ??
                                  (fieldName == 'Within'
                                      ? [DecimalInputFormatter()]
                                      : fieldName.toLowerCase() ==
                                            'days of inactivity'
                                      ? [FilteringTextInputFormatter.digitsOnly]
                                      : null),
                              keyboardType:
                                  keyboardType ??
                                  (fieldName == 'Within'
                                      ? const TextInputType.numberWithOptions(
                                          decimal: true,
                                        )
                                      : fieldName.toLowerCase() ==
                                            'days of inactivity'
                                      ? TextInputType.number
                                      : (isAddress || isDescription)
                                      ? TextInputType.multiline
                                      : TextInputType.text),
                              controller: controller,
                              readOnly: isAddress,
                              onTap: isAddress ? onTap : null,
                              onChanged: onChanged,
                              maxLines: (isAddress || isDescription) ? null : 1,
                              minLines: isDescription
                                  ? 5
                                  : (isAddress ? 3 : 1),
                              style: AppTheme.fieldValueStyle(isDark),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                filled: false,
                                hintText: controller.text.isEmpty
                                    ? 'Enter $fieldName'
                                    : null,
                                hintStyle: AppTheme.fieldHintStyle(isDark),
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              cursorColor: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          error,
                          style: const TextStyle(
                            color: StatusColors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      );
    } else {
      return GestureDetector(
        onTap: isAddress ? onTap : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildLabel(),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xffF8FAFB),
                border: Border.all(color: Colors.transparent, width: 1),
              ),
              child: Row(
                children: [
                  buildIcon(),
                  if (icon != null) const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      displayValue,
                      style: TextStyle(
                        fontFamily: GoogleFonts.manrope(
                          fontWeight: FontWeight.w600,
                        ).fontFamily,
                        color: displayValue == 'Not set'
                            ? (isDark ? Colors.grey[500]! : Colors.grey[500]!)
                            : (isDark
                                  ? Colors.white70
                                  : const Color(0xff000000)),
                        fontStyle: displayValue == 'Not set'
                            ? FontStyle.italic
                            : FontStyle.normal,
                        fontSize: 14,
                        height: 1.2,
                        letterSpacing: 0.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
}
