import 'package:flutter/material.dart';

import 'skeleton.dart';

/// Shimmer loading placeholder for form detail or edit views.
///
/// Each section card of the form is drawn as one soft shimmering block, with a
/// title, a divider and label/value rows as deeper lines on it, at the real
/// form card's margin and radius so the form replaces it without a jump.
///
/// Automatically adapts shimmer colors for both light and dark themes.
class FormViewShimmer extends StatelessWidget {
  const FormViewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: List.generate(
        4,
        (_) => SkeletonCard(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(18),
          radius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBar(width: 200, height: 20),
              const SizedBox(height: 14),
              const SkeletonBar(height: 1.5, radius: 1),
              const SizedBox(height: 18),
              ...List.generate(
                5,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBar(width: 120, height: 14),
                      SkeletonBar(width: 100, height: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A plain rounded block for the shimmer sections that sit inside a form's own
/// card (the card stays; only its contents shimmer).
Widget shimmerBox({double width = double.infinity, double height = 45}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.grey,
      borderRadius: BorderRadius.circular(8),
    ),
  );
}
