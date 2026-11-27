import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/navigation/navigation_keys.dart';
import '../../../../core/session/database_expiry.dart';
import '../../../../core/usecases/reset_session_usecase.dart';
import '../../../../core/widgets/snackbar.dart';
import '../../../../di/injection_container.dart';
import '../../../login/presentation/pages/url_database_screen.dart';
import '../../../onboarding/presentation/pages/get_started_screen.dart';
import '../../../main/presentation/pages/main_layout_page.dart';
import '../../domain/usecases/check_login_usecase.dart';
import '../../../../core/storage/session_token_store.dart';
import '../../../../core/security/biometric_lock.dart';

/// Splash screen responsible for:
/// - Checking biometric authentication (if enabled)
/// - Verifying login session state
/// - Navigating user to the correct screen (Login or Main app)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// Shortest time the splash stays up, so it does not just flash.
  static const Duration _minSplash = Duration(milliseconds: 800);

  bool biometricEnabled = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// Initializes splash workflow:
  /// 1. Loads biometric preference
  /// 2. Performs biometric authentication if enabled
  /// 3. Checks login session
  /// 4. Navigates to appropriate screen
  Future<void> _init() async {
    await _loadBiometricPreference();

    if (biometricEnabled) {
      final authenticated = await _authenticateBiometrics();
      if (!authenticated) {
        if (Platform.isAndroid) {
          SystemNavigator.pop();
        } else if (Platform.isIOS) {
          exit(0);
        }
        return;
      }
    }
    await _checkLoginAndNavigate();
  }

  /// Loads biometric preference from local storage.
  /// Defaults to `false` if not set.
  Future<void> _loadBiometricPreference() async {
    final prefs = await SharedPreferences.getInstance();
    biometricEnabled = prefs.getBool('biometricEnabled') ?? false;
  }

  /// Performs biometric authentication using device biometrics.
  ///
  /// Returns:
  /// - `true` if authentication succeeds
  /// - `false` if authentication fails or is unavailable
  Future<bool> _authenticateBiometrics() async {
    try {
      // No usable biometric on this phone: the prompt could never succeed and
      // the app would close on every launch. Drop the lock and open normally.
      if (!await BiometricLock.isUsable(_localAuth)) {
        await BiometricLock.disable();
        return true;
      }

      final biometrics = await _localAuth.getAvailableBiometrics();
      final type = biometrics.contains(BiometricType.face)
          ? 'Face ID'
          : biometrics.contains(BiometricType.fingerprint)
          ? 'Touch ID'
          : 'biometric';

      final ok = await _localAuth.authenticate(
        localizedReason: 'Authenticate with $type to log in',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!ok && mounted) {
        CustomSnackBar.showError(
          context,
          'Biometric authentication failed. App will close.',
        );
      }
      return ok;
    } catch (e) {
      if (BiometricLock.isUnavailableError(e)) {
        await BiometricLock.disable();
        return true;
      }
      if (!mounted) return false;
      CustomSnackBar.showError(
        context,
        'Something went wrong with biometric auth. App will close.',
      );
      return false;
    }
  }

  /// Checks whether user is logged in and navigates accordingly:
  /// - Logged in → MainLayout screen
  /// - Not logged in → Login/URL setup screen
  Future<void> _checkLoginAndNavigate() async {
    // The checks below run while the splash is on screen; only what is left of
    // a short minimum is waited for afterwards, so a quick check is not held
    // back by a fixed delay.
    final splashTimer = Stopwatch()..start();

    var isLoggedIn = await sl<CheckLoginUseCase>().call();
    var expired = false;

    // A stored session outlives the subscription, so the database is checked
    // on every launch and the user is signed out once it has expired.
    if (isLoggedIn) {
      final prefs = await SharedPreferences.getInstance();
      expired = await DatabaseExpiry.isExpired(
        serverUrl: prefs.getString('url') ?? '',
        sessionId: await SessionTokenStore.getActive() ?? '',
      );
      if (expired) {
        await ResetSessionUseCase().execute();
        isLoggedIn = false;
      }
    }

    final remaining = _minSplash - splashTimer.elapsed;
    if (remaining > Duration.zero) await Future.delayed(remaining);

    if (!mounted) return;

    if (isLoggedIn) {
      Navigator.pushReplacement(
        context,
        // The root blocs already loaded themselves when the app started;
        // reloading them here would fetch everything a second time.
        MaterialPageRoute(builder: (_) => const MainLayout(skipReload: true)),
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenGetStarted = prefs.getBool(hasSeenGetStartedKey) ?? false;
      if (!mounted) return;

      // Uses the global navigator: this splash's own context is gone by the
      // time the get started page's button is tapped.
      void openLogin() => navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(
          settings: const RouteSettings(name: UrlDatabaseScreen.routeName),
          builder: (_) => const UrlDatabaseScreen(),
        ),
      );

      if (hasSeenGetStarted) {
        openLogin();
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GetStartedScreen(onFinished: openLogin),
          ),
        );
      }
      if (expired) {
        CustomSnackBar.showError(context, DatabaseExpiredException.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
