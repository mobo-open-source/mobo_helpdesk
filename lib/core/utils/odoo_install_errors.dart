/// Plain wording for the errors Odoo raises around installing apps.
///
/// Saving a helpdesk team with an option such as Timesheets switched on makes
/// Odoo install the matching app in the middle of the request, and while that
/// runs - or right after, while the server reloads - other module operations are
/// refused with messages written for administrators. Those say what to do in
/// terms of the Odoo back end, not the app.
class OdooInstallErrors {
  const OdooInstallErrors._();

  /// What to show instead of [message], or `null` when [message] is not one of
  /// these errors and should be shown as Odoo wrote it.
  static String? friendly(String message) {
    final text = message.toLowerCase();

    // "The method _button_immediate_install cannot be called on init or non
    // loaded registries. Please use button_install instead."
    if (text.contains('init or non loaded registries')) {
      return 'The server is still starting up or reloading after an '
          'installation. Wait a minute, then try again.';
    }

    // "Odoo is currently processing another module operation."
    if (text.contains('processing another module operation')) {
      return 'Another installation is already running on the server. Wait for '
          'it to finish, then try again.';
    }

    // "Odoo is currently processing a scheduled action. Module operations are
    // not possible at this time"
    if (text.contains('processing a scheduled action')) {
      return 'The server is busy with a scheduled task. Try again in a moment.';
    }

    // "[Errno 2] No such file or directory: '/.../mail/static/src/img/odoobot.png'"
    // An app's data names a file the server does not have, typically because
    // the Odoo core and its enterprise add-ons are not the same version.
    final missing = RegExp(
      r"No such file or directory: '([^']+)'",
    ).firstMatch(message);
    if (missing != null) {
      final file = missing.group(1)!.split('/').last;
      return 'The server could not finish the installation: a file it needs '
          'is missing ($file). Ask your Odoo administrator to check that the '
          'server\'s Odoo and its add-ons are the same version.';
    }

    return null;
  }

  /// [message], reworded when it is one of the errors above.
  static String reword(String message) => friendly(message) ?? message;
}

/// The connection to the server dropped while a save was in flight.
///
/// Unlike an error Odoo answered with, this says nothing about what the server
/// did: a save that installs apps goes on running after the app stopped
/// listening, and the team may well be there when it is done.
class OdooConnectionLost implements Exception {
  final String message;

  const OdooConnectionLost(this.message);

  @override
  String toString() => message;
}
