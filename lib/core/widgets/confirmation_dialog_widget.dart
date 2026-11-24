import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'dialog_button_style.dart';

/// A reusable confirmation dialog widget with a modern, consistent design.
///
/// This dialog displays a title, subtitle, and two action buttons (Negative and Positive).
/// It is designed to be used for critical actions like delete, logout, discard changes, etc.
///
/// Features:
/// - Consistent theming for both light and dark modes
/// - Prominent alert icon at the top
/// - Centered subtitle with proper text alignment
/// - Uses [DialogButtonStyle] for consistent button styling across the app
/// - Returns `true` when positive button is pressed, `false` when negative button is pressed
///
/// Example usage:
/// ```dart
/// final confirmed = await ConfirmationDialogWidget.show(
///   context: context,
///   title: 'Delete Account',
///   subTitle: 'Are you sure you want to delete your account? This action cannot be undone.',
///   negativeButtonText: 'Cancel',
///   positiveButtonText: 'Delete',
/// );
///
/// if (confirmed == true) {
///   // Proceed with deletion
/// }
/// ```
class ConfirmationDialogWidget extends StatelessWidget {
  final String title;
  final String subTitle;
  final String negativeButtonText;
  final String positiveButtonText;

  const ConfirmationDialogWidget({
    super.key,
    required this.title,
    required this.subTitle,
    required this.negativeButtonText,
    required this.positiveButtonText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      // A little more room than Dialog's default 40, so the buttons get more
      // of a narrow screen; the cap below keeps it from sprawling on a tablet.
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The message scrolls when the screen is short (landscape, large
              // text); the buttons below stay in reach either way.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.orangeAccent
                              : Colors.orangeAccent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedAlert02,
                          color: isDark ? Colors.white : Colors.orangeAccent,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        subTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[300]! : Colors.grey[700]!,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Gap between the two buttons, whether they sit side by side or stacked.
  static const double _buttonGap = 12;

  /// Cancel beside the action when both labels fit in half the width; stacked
  /// full width (action on top) when they do not. Squeezing a long label into
  /// half a narrow dialog left it touching the button's edges, or wrapped onto
  /// two lines and made the pair uneven. Short labels keep the single row.
  Widget _buildButtons(BuildContext context) {
    final negative = DialogButtonStyle.negativeButton(
      context: context,
      onPressed: () => Navigator.pop(context, false),
      title: negativeButtonText,
    );
    final positive = DialogButtonStyle.successButton(
      context: context,
      onPressed: () => Navigator.pop(context, true),
      title: positiveButtonText,
      destructive: positiveButtonText.toLowerCase().startsWith('delete'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (_labelsFitSideBySide(context, constraints.maxWidth)) {
          return Row(
            children: [
              Expanded(child: negative),
              const SizedBox(width: _buttonGap),
              Expanded(child: positive),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            positive,
            const SizedBox(height: _buttonGap),
            negative,
          ],
        );
      },
    );
  }

  /// Whether both labels fit on one line in a half-width button, measured the
  /// way the buttons draw them (bold 16, the user's text scale).
  bool _labelsFitSideBySide(BuildContext context, double maxWidth) {
    final style = (Theme.of(context).textTheme.labelLarge ?? const TextStyle())
        .copyWith(fontSize: 16, fontWeight: FontWeight.bold);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);

    double labelWidth(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    // A few pixels of slack: the measure uses the theme's font, the button its
    // own, and being a hair generous costs only a stacked layout.
    const slack = 6.0;
    final halfWidth = (maxWidth - _buttonGap) / 2;
    final padding = DialogButtonStyle.horizontalPadding * 2 + slack;

    return labelWidth(negativeButtonText) + padding <= halfWidth &&
        labelWidth(positiveButtonText) + padding <= halfWidth;
  }

  /// Shows the confirmation dialog and returns a boolean result.
  ///
  /// Returns:
  /// - `true` if the user taps the positive button
  /// - `false` if the user taps the negative button
  /// - `null` if the dialog is dismissed otherwise (though `barrierDismissible` is set to `false`)
  ///
  /// This is the recommended static method to display the dialog.
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String subTitle,
    required String negativeButtonText,
    required String positiveButtonText,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConfirmationDialogWidget(
        title: title,
        subTitle: subTitle,
        negativeButtonText: negativeButtonText,
        positiveButtonText: positiveButtonText,
      ),
    );
  }
}
