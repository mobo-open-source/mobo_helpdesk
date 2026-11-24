import 'package:flutter/material.dart';
import 'package:mobo_helpdesk/app/themes/app_theme.dart';
import 'package:provider/provider.dart';

import '../core/navigation/app_route_observer.dart';
import '../core/navigation/navigation_keys.dart';
import '../core/services/theme_service.dart';
import '../features/auth/presentation/pages/splash_screen.dart';

/// The root widget of the Mobo Helpdesk application.
///
/// This widget serves as the top-level entry point for the entire Flutter app.
/// It configures the [MaterialApp] with theming, navigation, and global keys,
/// and starts the app with the [SplashScreen].
///
/// Key features:
/// - Uses [Provider] to listen to [ThemeServiceProvider] for dynamic theme switching.
/// - Supports both light and dark themes via [themeMode], [theme], and [darkTheme].
/// - Sets up global navigation and scaffold messenger keys for app-wide access
///   (e.g., showing snackbars or navigating without context).
/// - Disables the debug banner for a cleaner production look.
///
/// The app's theme is managed centrally through [ThemeServiceProvider].
/// Any changes to theme mode will automatically rebuild this widget due to
/// `Provider.of<ThemeServiceProvider>(context)`.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeServiceProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      navigatorObservers: [appRouteObserver],
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'Mobo Helpdesk',
      themeMode: themeProvider.themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
