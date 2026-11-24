import '../repositories/url_launcher_repo.dart';

/// Use case for handling URL launching operations.
///
/// Acts as an intermediary between the presentation layer and
/// [UrlLauncherRepo], providing simple methods to open external links
/// safely or directly.
///
/// Responsibilities:
/// - Launch URLs in external applications
/// - Safely check and launch URLs when supported
class UrlLauncherUseCase {
  final UrlLauncherRepo repo;

  UrlLauncherUseCase(this.repo);

  Future<void> launch(String url) {
    return repo.launchExternal(url);
  }

  Future<bool> launchSmart(String url) {
    return repo.launchSmart(url);
  }
}
