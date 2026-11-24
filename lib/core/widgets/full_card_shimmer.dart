import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A single full-width shimmering block, ported from the Mobo Events app so the
/// loading effect looks the same in both apps.
class FullCardShimmer extends StatelessWidget {
  final double height;
  final double radius;

  const FullCardShimmer({super.key, this.height = 120, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      period: const Duration(milliseconds: 1200),
      child: Container(
        height: height,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// The loading state of the ticket and team detail pages: the same stack of
/// [FullCardShimmer] blocks the Events app shows while an event loads.
class DetailCardsShimmer extends StatelessWidget {
  const DetailCardsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: const [
        FullCardShimmer(height: 100),
        SizedBox(height: 10),
        FullCardShimmer(height: 300),
        SizedBox(height: 10),
        FullCardShimmer(height: 400),
      ],
    );
  }
}
