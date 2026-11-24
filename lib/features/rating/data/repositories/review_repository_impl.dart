import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/repositories/review_repository.dart';

/// Implementation of [ReviewRepository] that manages in-app review logic,
/// usage tracking, and fallback feedback mechanisms.
///
/// This class uses:
/// - [SharedPreferences] to persist user engagement data
/// - [InAppReview] to trigger native store review dialogs
/// - Mail/URL launcher for fallback feedback collection
///
/// It tracks app usage patterns (opens, events, first launch time)
/// and determines when to prompt the user for a review.
class ReviewRepositoryImpl implements ReviewRepository {
  final SharedPreferences prefs;
  final InAppReview review;

  ReviewRepositoryImpl({required this.prefs, required this.review});

  static const _open = 'review_open';
  static const _event = 'review_event';
  static const _first = 'review_first';
  static const _next = 'review_next';
  static const _never = 'review_never';

  /// Tracks when the app is opened by the user.
  ///
  /// Stores the first open timestamp (if not already set) and increments
  /// the total number of app opens. This data is later used to decide
  /// when to prompt for a review.
  @override
  Future<void> trackAppOpen() async {
    if (!prefs.containsKey(_first)) {
      await prefs.setInt(_first, DateTime.now().millisecondsSinceEpoch);
    }

    await prefs.setInt(_open, (prefs.getInt(_open) ?? 0) + 1);
  }

  /// Tracks a meaningful user event inside the app.
  ///
  /// Used as an engagement metric to determine if the user is active
  /// enough to be prompted for a review.
  @override
  Future<void> trackEvent() async {
    await prefs.setInt(_event, (prefs.getInt(_event) ?? 0) + 1);
  }

  /// Determines whether the app should show the review prompt.
  ///
  /// Conditions include:
  /// - User has not opted out permanently
  /// - Any cooldown period has expired
  /// - In-app review is available on the device
  /// - Either:
  ///   - App opened >= 5 times OR
  ///   - Event count >= 5 OR
  ///   - 5+ days since first launch
  ///
  /// Returns `true` if the review prompt should be shown.
  @override
  Future<bool> shouldShowReview() async {
    if (prefs.getBool(_never) ?? false) return false;

    final next = prefs.getInt(_next);
    if (next != null &&
        DateTime.now().isBefore(DateTime.fromMillisecondsSinceEpoch(next))) {
      return false;
    }

    if (!await review.isAvailable()) return false;

    final open = prefs.getInt(_open) ?? 0;
    final event = prefs.getInt(_event) ?? 0;

    if (open >= 5 || event >= 5) return true;

    final first = prefs.getInt(_first);
    if (first != null) {
      final days = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(first))
          .inDays;

      if (days >= 5) return true;
    }

    return false;
  }

  /// Requests an in-app review from the user.
  ///
  /// If in-app review is unavailable or fails, it falls back to
  /// opening the store listing.
  @override
  Future<void> requestReview() async {
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await openStoreListing();
      }
    } catch (_) {
      await openStoreListing();
    }
  }

  /// Opens the app store listing for manual review submission.
  @override
  Future<void> openStoreListing() async {
    await review.openStoreListing();
  }

  /// Postpones the review prompt for a given duration.
  ///
  /// This sets a cooldown timestamp after which the review prompt
  /// may be shown again.
  @override
  Future<void> postpone(Duration duration) async {
    final next = DateTime.now().add(duration);
    await prefs.setInt(_next, next.millisecondsSinceEpoch);
  }

  /// Permanently disables review prompts for the user.
  @override
  Future<void> neverAskAgain() async {
    await prefs.setBool(_never, true);
  }

  /// Sends feedback via email using a mailto intent.
  ///
  /// Opens the default email client with prefilled:
  /// - Subject containing rating
  /// - Body containing user comment
  @override
  Future<void> sendFeedback(double rating, String comment) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'cybroplay@gmail.com',
      query: 'subject=Feedback (${rating.toInt()})&body=$comment',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
