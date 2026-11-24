import 'package:flutter/material.dart';

/// The line under a form-card heading, running edge to edge across the card
/// (as in Mobo Events / Billing) instead of stopping at the card's padding.
///
/// Place it inside a card whose content is padded by [inset] on each side.
class CardHeadingDivider extends StatelessWidget {
  final bool isDark;

  /// The card's horizontal padding, which the line reaches across.
  final double inset;

  const CardHeadingDivider({super.key, required this.isDark, this.inset = 18});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: 1,
        child: OverflowBox(
          minWidth: constraints.maxWidth + inset * 2,
          maxWidth: constraints.maxWidth + inset * 2,
          child: Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.grey[700] : Colors.grey[200],
          ),
        ),
      ),
    );
  }
}
