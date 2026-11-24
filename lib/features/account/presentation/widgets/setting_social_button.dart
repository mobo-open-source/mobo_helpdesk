import 'package:flutter/material.dart';

/// A reusable social media action button used in settings or about sections.
///
/// This widget displays:
/// - A circular icon button with a social media logo (asset image)
/// - A colored underline indicator below the icon
///
/// It is commonly used for linking to external social platforms such as:
/// - Facebook
/// - LinkedIn
/// - Instagram
/// - YouTube
///
/// The widget automatically adapts its background color based on the current theme
/// (light or dark mode) to maintain visual consistency.
class SettingSocialButton extends StatelessWidget {
  final String assetPath;
  final Color underlineColor;
  final VoidCallback onPressed;

  const SettingSocialButton({
    super.key,
    required this.assetPath,
    required this.underlineColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: .2) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Image.asset(
              assetPath,
              width: 24,
              height: 24,
              color: isDark ? Colors.white : null,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 48,
          height: 3,
          decoration: BoxDecoration(
            color: underlineColor,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ],
    );
  }
}
