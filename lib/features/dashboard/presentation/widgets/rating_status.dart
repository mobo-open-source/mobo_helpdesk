import 'package:flutter/material.dart';

/// Represents the visual status of a customer rating.
///
/// Contains a human-readable [label] and a corresponding [color]
/// used for badges and UI indicators in the rating list.
class RatingStatus {
  final String label;
  final Color color;

  RatingStatus(this.label, this.color);
}

/// Converts a raw rating text into a [RatingStatus] object with appropriate
/// label and color for UI display.
///
/// This function is used throughout [RatingListPage] to determine the
/// visual appearance of rating badges.
///
/// Supported rating values:
/// - `'top'` → Green "Satisfied"
/// - `'ok'`  → Orange "Okay"
/// - `'ko'`  → Red "Dissatisfied"
/// - `'none'` or any other value → Grey "No Rating Yet"
///
/// Parameters:
///   - [ratingText]: The raw rating string received from the backend.
///                   Can be null.
///
/// Returns:
///   A [RatingStatus] containing the display label and color.
RatingStatus ratingStatusColor(String? ratingText) {
  switch (ratingText) {
    case 'top':
      return RatingStatus('Satisfied', Colors.green);

    case 'ok':
      return RatingStatus('Okay', Colors.orange);

    case 'ko':
      return RatingStatus('Dissatisfied', Colors.red);

    case 'none':
    default:
      return RatingStatus('No Rating Yet', Colors.grey);
  }
}
