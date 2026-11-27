import 'package:flutter/material.dart';

/// Global navigation and messaging keys for the entire application.
///
/// These keys are used to access `Navigator` and `ScaffoldMessenger`
/// from anywhere in the app without requiring a `BuildContext`.
///
/// This is particularly useful for:
/// - Showing SnackBars, Dialogs, or BottomSheets from services, BLoCs, or repositories.
/// - Performing navigation (push, pop, etc.) outside of widgets (e.g., after login, logout, or API callbacks).
///
/// These keys are initialized in [MyApp] via `navigatorKey` and `scaffoldMessengerKey`.
///
/// Example usage:
/// ```dart
/// // Show a snackbar from anywhere
/// scaffoldMessengerKey.currentState?.showSnackBar(
///   const SnackBar(content: Text('Operation completed')),
/// );
///
/// // Navigate without context
/// navigatorKey.currentState?.pushNamed('/some-route');
/// ```
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
