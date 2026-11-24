import 'package:url_launcher/url_launcher.dart';
import '../../domain/repositories/url_launcher_repo.dart';

/// Repository implementation for handling external URL launching.
///
/// Uses `url_launcher` package to open links in external applications
/// or safely check before launching.
///
/// Responsibilities:
/// - Open URLs in external browser/app
/// - Safely check if a URL can be launched
class UrlLauncherRepoImpl implements UrlLauncherRepo {
  /// Launches a URL directly in an external application.
  ///
  /// Throws an exception if the URL cannot be launched.
  @override
  Future<void> launchExternal(String url) async {
    final Uri uri = Uri.parse(url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  /// Safely attempts to launch a URL after checking availability.
  ///
  /// Returns:
  /// - `true` if the URL was successfully launched
  /// - `false` if the URL cannot be handled
  @override
  Future<bool> launchSmart(String url) async {
    final Uri uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    return false;
  }
}
