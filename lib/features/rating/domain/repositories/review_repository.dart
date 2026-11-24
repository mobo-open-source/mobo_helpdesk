/// Abstract contract for handling in-app review flow and user feedback.
///
/// This repository defines the core operations required to:
/// - Track user engagement (app opens and events)
/// - Decide when to prompt for a review
/// - Trigger in-app review or fallback to store listing
/// - Manage review prompt scheduling (postpone / never ask again)
/// - Send user feedback via external channels (e.g., email)
///
/// Implementations may use platform-specific APIs such as
/// [InAppReview], persistent storage, or external URL launchers.
abstract class ReviewRepository {
  Future<void> trackAppOpen();

  Future<void> trackEvent();

  Future<bool> shouldShowReview();

  Future<void> requestReview();

  Future<void> openStoreListing();

  Future<void> postpone(Duration duration);

  Future<void> neverAskAgain();

  Future<void> sendFeedback(double rating, String comment);
}
