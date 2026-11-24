import 'package:flutter/material.dart';

import '../../../../core/widgets/skeleton.dart';

/// A shimmer loading effect widget specifically designed for the Dashboard page.
///
/// This widget displays a realistic skeleton layout that mimics the actual
/// dashboard structure while data is being loaded from the [DashboardBloc].
///
/// It includes placeholders for:
/// - Main dashboard tile (My Tickets section)
/// - Performance metrics header with dropdown
/// - Three performance containers (Closed Tickets, SLA Success Rate, Average Rating)
/// - Team support cards with internal rows and mini performance cards
///
/// The shimmer effect adapts automatically to light and dark themes.
class DashboardShimmerPage extends StatelessWidget {
  final bool isDark;

  const DashboardShimmerPage({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            shimmerContainer(height: 220),

            const SizedBox(height: 25),

            shimmerTitleRow(),

            const SizedBox(height: 18),

            shimmerPerformanceList(),

            const SizedBox(height: 20),

            shimmerTeamCards(),
          ],
        ),
      ),
    );
  }

  Widget shimmerContainer({
    required double height,
    double width = double.infinity,
    double radius = 12,
  }) {
    return SkeletonShimmer(
      tone: SkeletonTone.slab,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  Widget shimmerTitleRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        shimmerContainer(height: 20, width: 140),

        shimmerContainer(height: 35, width: 140, radius: 10),
      ],
    );
  }

  Widget shimmerPerformanceList() {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: shimmerContainer(height: 70),
        ),
      ),
    );
  }

  Widget shimmerTeamCards() {
    return Column(
      children: List.generate(
        2,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: shimmerTeamCard(),
        ),
      ),
    );
  }

  Widget shimmerTeamCard() {
    // One soft block for the card, the rows and mini cards on it in the
    // deeper ink tone, so the card keeps its structure.
    return SkeletonCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              shimmerBox(width: 120, height: 18),
              shimmerBox(width: 60, height: 18),
            ],
          ),

          const SizedBox(height: 15),

          shimmerRow(),
          const SizedBox(height: 10),
          shimmerRow(),
          const SizedBox(height: 10),
          shimmerRow(),

          const SizedBox(height: 15),

          Row(
            children: List.generate(
              4,
              (index) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: shimmerBox(height: 50),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget shimmerRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        shimmerBox(width: 120, height: 14),
        shimmerBox(width: 60, height: 14),
      ],
    );
  }

  Widget shimmerBox({double width = double.infinity, double height = 14}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
