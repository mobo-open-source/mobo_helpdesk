/// Repository contract for handling URL launching operations.
///
/// Defines methods to open external links safely using the device's
/// default browser or appropriate external applications.
abstract class UrlLauncherRepo {
  Future<void> launchExternal(String url);

  Future<bool> launchSmart(String url);
}
