import 'package:flutter/material.dart';

import '../../app/themes/app_colors.dart';

/// A custom, animated checkbox widget with hover support and consistent theming.
///
/// This widget provides a modern, branded checkbox that matches the app's design system.
/// It features smooth animations, hover effects, and automatic light/dark mode adaptation.
///
/// Unlike the default [Checkbox], this component offers:
/// * Custom size and border radius
/// * Hover state animation
/// * Better visual integration with the app's primary color
/// * Disabled state support
class MoboCheckbox extends StatefulWidget {
  final bool value;

  final ValueChanged<bool>? onChanged;

  final double size;

  final double radius;

  const MoboCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 22,
    this.radius = 6,
  });

  @override
  State<MoboCheckbox> createState() => _MoboCheckboxState();
}

class _MoboCheckboxState extends State<MoboCheckbox> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary;

    final isDisabled = widget.onChanged == null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: isDisabled ? null : () => widget.onChanged!(!widget.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),

            border: Border.all(color: primary, width: 2),

            color: widget.value
                ? primary
                : (_hovering
                      ? primary.withValues(alpha: 0.10)
                      : Colors.transparent),
          ),

          child: widget.value
              ? Icon(Icons.check_rounded, size: 14, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
