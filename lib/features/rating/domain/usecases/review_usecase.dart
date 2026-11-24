import '../repositories/review_repository.dart';

/// Use case for tracking app launches for review eligibility.
///
/// Delegates to [ReviewRepository.trackAppOpen].
class TrackAppOpen {
  final ReviewRepository repo;

  TrackAppOpen(this.repo);

  /// Records an app open event.
  Future<void> call() => repo.trackAppOpen();
}

/// Use case for tracking user engagement events.
///
/// These events help determine review prompt timing.
class TrackEvent {
  final ReviewRepository repo;

  TrackEvent(this.repo);

  Future<void> call() => repo.trackEvent();
}

/// Use case that determines whether a review prompt should be shown.
///
/// Uses engagement metrics and timing rules defined in the repository.
class ShouldShowReview {
  final ReviewRepository repo;

  ShouldShowReview(this.repo);

  /// Returns `true` if conditions are met to show a review prompt.
  Future<bool> call() => repo.shouldShowReview();
}

/// Use case to trigger an in-app review or fallback store listing.
class RequestReview {
  final ReviewRepository repo;

  RequestReview(this.repo);

  Future<void> call() => repo.requestReview();
}

/// Use case to postpone the review prompt for a specific duration.
///
/// Prevents the review dialog from appearing until cooldown expires.
class PostponeReview {
  final ReviewRepository repo;

  PostponeReview(this.repo);

  Future<void> call(Duration d) => repo.postpone(d);
}

/// Use case to permanently disable review prompts.
///
/// Typically used when the user explicitly opts out.
class NeverAskAgain {
  final ReviewRepository repo;

  NeverAskAgain(this.repo);

  Future<void> call() => repo.neverAskAgain();
}

/// Use case for sending user feedback externally.
///
/// Usually implemented via email or external feedback form.
class SendFeedback {
  final ReviewRepository repo;

  SendFeedback(this.repo);

  Future<void> call(double rating, String comment) =>
      repo.sendFeedback(rating, comment);
}
