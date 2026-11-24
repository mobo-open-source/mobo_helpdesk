import 'package:flutter/material.dart';

import '../../../../core/navigation/app_route_observer.dart';
import '../../../../core/session/models/session_model.dart';
import '../../../account/presentation/pages/configuration_page.dart';
import '../pages/url_database_screen.dart';

/// Sends the user back to the screen the login attempt started from, closing
/// the blocking dialog ("Access Denied" / "Module Missing") and every login
/// screen above it.
///
/// - In the "add account" flow the user came from the [ConfigurationPage]
///   (profile / switch account), so that page is revealed again with the
///   previous account still active - never the dashboard.
/// - In the normal login flow there is no session to go back to, so the user
///   returns to the server [UrlDatabaseScreen] instead. If that route is gone
///   from the stack a new one is pushed, prefilled with [initialUrl] /
///   [initialDatabase] so the entered server details are not lost.
void backFromFailedLogin(
  BuildContext context, {
  required bool isAddAccount,
  SessionModel? currentSession,
  String? initialUrl,
  String? initialDatabase,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);

  if (isAddAccount &&
      appRouteObserver.containsRoute(ConfigurationPage.routeName)) {
    if (_popTo(navigator, ConfigurationPage.routeName)) return;
  }

  if (appRouteObserver.containsRoute(UrlDatabaseScreen.routeName) &&
      _popTo(navigator, UrlDatabaseScreen.routeName)) {
    return;
  }

  navigator.pushAndRemoveUntil(
    MaterialPageRoute(
      settings: const RouteSettings(name: UrlDatabaseScreen.routeName),
      builder: (_) => UrlDatabaseScreen(
        isAddAccount: isAddAccount,
        currentSession: currentSession,
        initialUrl: initialUrl,
        initialDatabase: initialDatabase,
        title: isAddAccount ? "Add Account" : null,
        subtitle: isAddAccount ? "Enter your server details to continue" : null,
      ),
    ),
    (route) => false,
  );
}

/// Pops routes until the one named [routeName] is on top.
///
/// Returns whether that route was reached; the stack is left at its first route
/// when it was not found.
bool _popTo(NavigatorState navigator, String routeName) {
  bool found = false;
  navigator.popUntil((route) {
    if (route.settings.name == routeName) found = true;
    return found || route.isFirst;
  });
  return found;
}
