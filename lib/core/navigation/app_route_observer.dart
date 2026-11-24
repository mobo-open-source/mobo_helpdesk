import 'package:flutter/material.dart';

/// Tracks the names of the routes currently on the navigation stack.
///
/// Flutter offers no way to inspect the stack without popping it, so this
/// observer keeps a lightweight record of the pushed route names. It is used to
/// check whether a screen is still reachable *before* popping back to it
/// (see `backFromFailedLogin`).
///
/// Registered on [MyApp] through `MaterialApp.navigatorObservers`.
class AppRouteObserver extends NavigatorObserver {
  final List<String?> _routeNames = [];

  /// Whether a route pushed with `RouteSettings(name: name)` is still in the stack.
  bool containsRoute(String name) => _routeNames.contains(name);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routeNames.add(route.settings.name);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routeNames.remove(route.settings.name);
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routeNames.remove(route.settings.name);
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _routeNames.remove(oldRoute.settings.name);
    if (newRoute != null) _routeNames.add(newRoute.settings.name);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

final AppRouteObserver appRouteObserver = AppRouteObserver();
