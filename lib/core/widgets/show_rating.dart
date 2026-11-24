import 'package:flutter/material.dart';

import '../../di/injection_container.dart';
import '../../features/rating/domain/usecases/review_usecase.dart';
import '../../features/rating/presentation/rating_dialog.dart';

/// Checks whether to show the rating dialog and handles user actions.
///
/// If eligible, waits briefly and displays the rating dialog.
/// Based on user feedback:
/// - Positive review → triggers in-app store review.
/// - Negative review → sends feedback and postpones next prompt.
/// - Ask later → postpones the dialog.
/// - Never ask again → disables future prompts.
void checkRating(BuildContext context) async {
  final shouldShow = await sl<ShouldShowReview>()();

  if (!shouldShow) return;
  if (!context.mounted) return;

  await Future.delayed(const Duration(seconds: 2));

  if (!context.mounted) return;

  await RatingDialog.show(
    context,

    onGoodReview: (rating, comment) async {
      if (Navigator.canPop(context)) Navigator.pop(context);

      await sl<RequestReview>()();
    },

    onBadReview: (rating, comment) async {
      if (Navigator.canPop(context)) Navigator.pop(context);

      await sl<SendFeedback>()(rating, comment);
      await sl<PostponeReview>()(const Duration(days: 3));
    },

    onNeverAskAgain: () async {
      await sl<NeverAskAgain>()();
    },

    onAskLater: () async {
      await sl<PostponeReview>()(const Duration(days: 3));
    },
  );
}
