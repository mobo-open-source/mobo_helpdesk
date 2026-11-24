import 'package:flutter/material.dart';

/// A star rating widget.
///
/// Displays a row of tappable stars to represent a rating.
/// Users can tap a star to update the rating via [onRatingChanged].
///
/// Supports customization of max stars and colors for filled
/// and unfilled states.
class StarRating extends StatelessWidget {
  final int rating;
  final int maxRating;
  final Function(int) onRatingChanged;
  final Color filledColor;
  final Color unfilledColor;

  const StarRating({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.maxRating = 3,
    this.filledColor = Colors.amber,
    this.unfilledColor = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxRating, (index) {
        return GestureDetector(
          onTap: () {
            if (rating == index + 1) {
              onRatingChanged(index);
            } else {
              onRatingChanged(index + 1);
            }
          },
          child: Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: index < rating ? filledColor : unfilledColor,
            size: 30,
          ),
        );
      }),
    );
  }
}
