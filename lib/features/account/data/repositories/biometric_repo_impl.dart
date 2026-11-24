import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/biometric_repo.dart';

/// Implementation of [BiometricRepo] using device biometric APIs
/// and local storage (SharedPreferences).
///
/// Responsible for:
/// - Authenticating user using biometrics (fingerprint/face ID)
/// - Enabling/disabling biometric preference
/// - Checking device biometric support and availability
class BiometricRepoImpl implements BiometricRepo {
  final LocalAuthentication auth;

  BiometricRepoImpl(this.auth);

  /// Prompts biometric authentication and enables it if successful.
  ///
  /// Stores biometric enabled state in local storage.
  /// Returns `true` if authentication succeeds.
  @override
  Future<bool> authenticateBiometric() async {
    final prefs = await SharedPreferences.getInstance();

    final authenticated = await auth.authenticate(
      localizedReason: 'Enable biometric authentication',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );

    if (authenticated) {
      await prefs.setBool('biometricEnabled', true);
    }

    return authenticated;
  }

  /// Disables biometric authentication in local storage.
  @override
  Future<void> disableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometricEnabled', false);
  }

  /// Checks whether biometric authentication is enabled by the user.
  @override
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometricEnabled') ?? false;
  }

  /// Checks whether the device supports biometric authentication
  /// and has at least one biometric method enrolled.
  @override
  Future<bool> isBiometricSupported() async {
    final isSupported = await auth.isDeviceSupported();
    final availableBiometrics = await auth.getAvailableBiometrics();

    return isSupported && availableBiometrics.isNotEmpty;
  }

  /// Checks if the device supports only weak biometrics
  /// (e.g., face unlock without strong hardware security).
  @override
  Future<bool> isBiometricWeek() async {
    try {
      final availableBiometrics = await auth.getAvailableBiometrics();
      final isWeakOnly =
          availableBiometrics.contains(BiometricType.weak) &&
          !availableBiometrics.contains(BiometricType.strong);
      return isWeakOnly;
    } catch (_) {
      return false;
    }
  }
}
