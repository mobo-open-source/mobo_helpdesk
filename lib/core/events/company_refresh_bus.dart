import 'dart:async';

/// A simple event bus used to notify listeners when company data should be refreshed.
///
/// This is a singleton-like static bus that broadcasts a refresh event across the app.
/// It is typically used after switching companies, updating company settings,
/// or any action that requires other parts of the app (e.g., dashboard, menus, tickets)
/// to reload company-specific data.
///
/// Usage:
/// ```dart
/// // Notify all listeners to refresh company-related data
/// CompanyRefreshBus.notify();
///
/// // Listen for refresh events
/// CompanyRefreshBus.stream.listen((_) {
///   // Refresh your data here (e.g., reload BLoC, refetch API, etc.)
/// });
/// ```
class CompanyRefreshBus {
  static final _controller = StreamController<void>.broadcast();

  static Stream<void> get stream => _controller.stream;

  static void notify() {
    _controller.add(null);
  }
}