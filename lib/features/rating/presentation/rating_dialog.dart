import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

/// A customizable rating dialog that allows users to rate the app
/// and optionally provide feedback.
///
/// If the user gives a rating of 4 stars or higher, the [onGoodReview]
/// callback is triggered. Typically, this is used to request an
/// in-app store review.
///
/// If the user gives a rating lower than 4 stars, the [onBadReview]
/// callback is triggered. This is generally used to collect feedback
/// via email and postpone future review prompts.
///
/// The dialog includes:
/// - A star rating bar (1–5 stars)
/// - An optional comment field (visible for ratings below 4)
/// - A Submit button
/// - "Skip for Now" (postpone) and "Never Ask Again" actions
///
/// Use [RatingDialog.show] to display the dialog.

class RatingDialog extends StatefulWidget {
  final Function(double, String) onGoodReview;
  final Function(double, String) onBadReview;
  final VoidCallback onNeverAskAgain;
  final VoidCallback onAskLater;

  const RatingDialog({
    super.key,
    required this.onGoodReview,
    required this.onBadReview,
    required this.onNeverAskAgain,
    required this.onAskLater,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(double, String) onGoodReview,
    required Function(double, String) onBadReview,
    required VoidCallback onNeverAskAgain,
    required VoidCallback onAskLater,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => RatingDialog(
        onGoodReview: onGoodReview,
        onBadReview: onBadReview,
        onNeverAskAgain: onNeverAskAgain,
        onAskLater: onAskLater,
      ),
    );
  }

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  double _rating = 5.0;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    final compact = size.height < 500;

    const dark = Color(0xFF101010);
    const star = Color(0xFFFFC107);
    final secondary = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    /// The action button inverts in dark mode - a near-black fill would
    /// disappear against the dark card.
    final actionBackground = isDark ? Colors.white : dark;
    final actionForeground = isDark ? dark : Colors.white;

    return Dialog(
      elevation: 0,
      shadowColor: Colors.transparent,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: 28,
        vertical: compact ? 12 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isLandscape ? 440 : double.infinity,
        ),
        child: SingleChildScrollView(
          padding: compact
              ? const EdgeInsets.fromLTRB(24, 20, 24, 8)
              : const EdgeInsets.fromLTRB(24, 32, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "How's your experience ?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : dark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your feedback helps us improve\nand serve you better.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                  color: secondary,
                ),
              ),
              SizedBox(height: compact ? 14 : 24),

              /// Filled stars are solid gold; the remainder are gold outlines.
              RatingBar(
                initialRating: _rating,
                minRating: 1,
                itemCount: 5,
                itemSize: 42,
                allowHalfRating: false,
                glow: false,
                itemPadding: const EdgeInsets.symmetric(horizontal: 2),
                ratingWidget: RatingWidget(
                  full: const Icon(Icons.star_rounded, color: star),
                  half: const Icon(Icons.star_half_rounded, color: star),
                  empty: const Icon(Icons.star_border_rounded, color: star),
                ),
                onRatingUpdate: (rating) => setState(() => _rating = rating),
              ),

              /// Feedback field, only for ratings below 4.
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: Visibility(
                  visible: _rating < 4,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: TextField(
                      controller: _commentController,
                      maxLines: 3,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : dark,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Any comments or feedback? (Optional)',
                        hintStyle: TextStyle(color: secondary),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF2F4F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 16 : 28),

              SizedBox(
                width: double.infinity,
                height: compact ? 48 : 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (_rating >= 4) {
                      widget.onGoodReview(_rating, _commentController.text);
                    } else {
                      widget.onBadReview(_rating, _commentController.text);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    backgroundColor: actionBackground,
                    foregroundColor: actionForeground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Submit',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 4),

              TextButton(
                onPressed: () {
                  widget.onAskLater();
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(foregroundColor: secondary),
                child: Text(
                  'Skip for Now',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: secondary,
                    color: secondary,
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
