import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helpers that keep the biometric app lock from locking people out.
///
/// The lock asks for a biometric only. If the phone can no longer provide one
/// (the fingerprint or face was removed, the screen lock was turned off, or
/// the device never had any), the prompt can never succeed, and without these
/// helpers the user would be stuck. In that case the lock is switched off and
/// the app opens normally. Phones that still have a biometric behave as before.
class BiometricLock {
  BiometricLock._();

  /// True when the device can show a biometric prompt that is able to succeed.
  ///
  /// If the check itself fails unexpectedly, this returns true so that the
  /// real prompt decides; the lock is not dropped on a transient error.
  static Future<bool> isUsable(LocalAuthentication auth) async {
    try {
      if (!await auth.isDeviceSupported()) return false;
      final enrolled = await auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return true;
    }
  }

  /// True for the platform errors that mean "this device cannot authenticate".
  static bool isUnavailableError(Object error) {
    if (error is! PlatformException) return false;
    const codes = {'notavailable', 'notenrolled', 'passcodenotset'};
    return codes.contains(error.code.toLowerCase());
  }

  /// Turns the lock off so the user is not asked again.
  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometricEnabled', false);
  }
}
