import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shared building blocks for loading skeletons, so every placeholder in the
/// app shimmers with the same colours, shapes and timing.
///
/// A skeleton is shaped like the content it stands in for, so nothing moves
/// when the data arrives. Two tones keep it calm instead of busy:
///
/// * [SkeletonTone.slab] is the card itself: one soft block that shimmers as a
///   whole, instead of a static card with small bars moving inside it.
/// * [SkeletonTone.ink] is the lines and chips drawn on a card, a shade deeper
///   than the slab so the card keeps some structure.
///
/// Both sweep with the same period, so a card and its lines move together.
enum SkeletonTone { slab, ink }

/// One sweep takes this long. The package default (3s) reads as sluggish.
const Duration _skeletonPeriod = Duration(milliseconds: 1500);

/// Shimmers [child] in the colours of [tone] for the current theme.
///
/// What [child] draws only acts as a mask (the shimmer paints through its
/// opaque pixels), so build it from white shapes such as [SkeletonBar] and
/// [SkeletonCircle].
class SkeletonShimmer extends StatelessWidget {
  final Widget child;
  final SkeletonTone tone;

  const SkeletonShimmer({
    super.key,
    required this.child,
    this.tone = SkeletonTone.ink,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (base, highlight) = switch ((tone, isDark)) {
      (SkeletonTone.slab, false) => (const Color(0xFFEEF0F4), const Color(0xFFF8F9FB)),
      (SkeletonTone.ink, false) => (const Color(0xFFE1E4EA), const Color(0xFFEFF1F5)),
      (SkeletonTone.slab, true) => (const Color(0xFF2B2E35), const Color(0xFF383C45)),
      (SkeletonTone.ink, true) => (const Color(0xFF3A3E47), const Color(0xFF474C57)),
    };

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      period: _skeletonPeriod,
      child: child,
    );
  }
}

/// A rounded bar standing in for a line of text or a chip.
///
/// Give it a fixed [width], a [widthFactor] of the space it is placed in, or
/// neither to fill that space. Only meaningful inside a [SkeletonShimmer].
class SkeletonBar extends StatelessWidget {
  final double? width;
  final double? widthFactor;
  final double height;
  final double radius;

  const SkeletonBar({
    super.key,
    this.width,
    this.widthFactor,
    this.height = 14,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );

    if (widthFactor == null) return bar;

    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: bar,
    );
  }
}

/// A circle standing in for an avatar or a status dot.
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
    );
  }
}

/// A whole card as one shimmering block, with [child] (lines, chips, circles)
/// drawn on it in the deeper ink tone.
///
/// Pass the real card's [margin], [padding] and [radius] so the skeleton
/// occupies exactly the space the card will. With no [child] and no [height]
/// it has no size of its own, so give it one of the two.
class SkeletonCard extends StatelessWidget {
  final Widget? child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final double? height;

  const SkeletonCard({
    super.key,
    this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.radius = 12,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            const Positioned.fill(
              child: SkeletonShimmer(
                tone: SkeletonTone.slab,
                child: ColoredBox(color: Colors.white),
              ),
            ),
            if (child != null)
              Padding(
                padding: padding,
                child: SkeletonShimmer(child: child!),
              ),
          ],
        ),
      ),
    );
  }
}

/// Loading placeholder for the Kanban board.
///
/// Mirrors the board's real geometry (292-wide stage columns with a header and
/// ticket cards of the same margin, padding and radius) so the board takes the
/// place of the skeleton without a jump. Not scrollable: it is only a stand-in.
class KanbanViewShimmer extends StatelessWidget {
  const KanbanViewShimmer({super.key});

  /// Cards per column. Uneven on purpose, so the board does not look stamped
  /// out of one mould.
  static const _cardsPerColumn = [3, 2, 3];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // The outer scroll view hands its child unbounded height, so a short
    // screen clips the columns instead of overflowing.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < _cardsPerColumn.length; column++)
                _KanbanColumnSkeleton(
                  isDark: isDark,
                  cards: _cardsPerColumn[column],
                  seed: column,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KanbanColumnSkeleton extends StatelessWidget {
  final bool isDark;
  final int cards;
  final int seed;

  const _KanbanColumnSkeleton({
    required this.isDark,
    required this.cards,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3, left: 4),
      child: Container(
        width: 292,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: SkeletonShimmer(child: SkeletonBar(width: 120, height: 16)),
            ),
            const SizedBox(height: 4),
            for (var card = 0; card < cards; card++)
              _KanbanCardSkeleton(variant: seed + card),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _KanbanCardSkeleton extends StatelessWidget {
  final int variant;

  const _KanbanCardSkeleton({required this.variant});

  static const _titleWidths = [0.7, 0.55, 0.82];

  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: SkeletonBar(
              widthFactor: _titleWidths[variant % _titleWidths.length],
              height: 15,
            ),
          ),
          const SizedBox(height: 8),
          const SkeletonBar(widthFactor: 0.45, height: 12),
          if (variant.isEven) ...[
            const SizedBox(height: 7),
            const SkeletonBar(widthFactor: 0.32, height: 12),
          ],
          const SizedBox(height: 14),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SkeletonCircle(size: 24),
                  SizedBox(width: 10),
                  SkeletonCircle(size: 12),
                ],
              ),
              Row(
                children: [
                  SkeletonCircle(size: 20),
                  SizedBox(width: 10),
                  SkeletonBar(width: 56, height: 14),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
