import 'package:flutter/material.dart';

import '../../../../core/widgets/skeleton.dart';

/// A shimmer loading placeholder for the Profile screen.
///
/// This widget is displayed while profile data is being fetched.
///
/// It simulates the structure of the profile UI:
/// - A circular avatar block for the profile image
/// - A list of field cards, each a soft shimmering block with a label and a
///   value line on it
///
/// Colors and timing come from the shared skeleton, so it adapts to the light
/// and dark themes and moves like every other loading placeholder in the app.
///
/// Used to improve perceived performance and provide visual feedback
/// while loading user profile data.
class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SkeletonShimmer(
            tone: SkeletonTone.slab,
            child: CircleAvatar(radius: 50, backgroundColor: Colors.white),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 10,
              itemBuilder: (_, _) => const SkeletonCard(
                height: 60,
                radius: 8,
                margin: EdgeInsets.only(bottom: 16),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SkeletonBar(width: 80, height: 10),
                    SizedBox(height: 8),
                    SkeletonBar(widthFactor: 0.5, height: 14),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
