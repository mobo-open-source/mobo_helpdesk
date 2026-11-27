import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../app/themes/app_colors.dart';

/// A white notice with one "OK" button, for something the user has to read
/// before going on (an outcome that is neither a plain success nor a plain
/// failure).
///
/// Same look as the login screens' notices: the alert icon beside the heading,
/// the explanation below it and a single full-width action. Light and dark
/// surfaces follow the active theme, and the text takes the app's font from it.
///
/// Three parts, all but [message] optional:
/// - [message]: what happened, in a sentence or two;
/// - [detail]: what the server said, set apart in a soft box and selectable so
///   it can be copied to whoever looks after the server;
/// - [hint]: what the user can do about it.
class NoticeDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? detail;
  final String? hint;
  final String buttonText;

  const NoticeDialog({
    super.key,
    required this.title,
    required this.message,
    this.detail,
    this.hint,
    this.buttonText = 'OK',
  });

  /// Shows the notice and completes when the user has dismissed it.
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    String? detail,
    String? hint,
    String buttonText = 'OK',
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NoticeDialog(
        title: title,
        message: message,
        detail: detail,
        hint: hint,
        buttonText: buttonText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E1E1E) : AppColors.white;
    final textPrimary = isDark ? AppColors.white : AppColors.textPrimary;
    final textSecondary = isDark ? Colors.white70 : AppColors.textSecondary;
    final boxFill = isDark ? Colors.white10 : const Color(0xFFF6F7F9);
    final boxBorder = isDark ? Colors.white12 : const Color(0xFFE6E8EC);

    return AlertDialog(
      backgroundColor: surface,
      surfaceTintColor: surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedAlertCircle,
            color: AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(fontSize: 15, height: 1.5, color: textPrimary),
            ),
            if (detail != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: boxFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: boxBorder),
                ),
                child: SelectableText(
                  detail!,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: textSecondary,
                  ),
                ),
              ),
            ],
            if (hint != null) ...[
              const SizedBox(height: 14),
              Text(
                hint!,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              buttonText,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
