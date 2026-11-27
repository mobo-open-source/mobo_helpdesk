import 'package:flutter/material.dart';

import '../../app/themes/app_colors.dart';

/// A custom animated toggle switch matching the Mobo design system.
///
/// - ON: filled with the mobo primary color and a white thumb (right).
/// - OFF: transparent/surface track with a mobo-color border and a
///   mobo-color thumb (left).
///
/// Adapts to light/dark themes for the OFF-state track color.
class MoboToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const MoboToggle({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = AppColors.primary;

    return Semantics(
      button: true,
      toggled: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: 56,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: value
                ? primaryColor
                : (isDark ? Colors.grey[900] : Colors.white),
            border: value ? null : Border.all(color: primaryColor, width: 1.5),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? Colors.white : primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
