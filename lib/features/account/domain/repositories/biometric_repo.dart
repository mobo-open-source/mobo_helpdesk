/// Repository contract for biometric authentication features.
///
/// Defines operations related to device biometrics such as
/// fingerprint or face recognition, including enabling,
/// disabling, and checking device support.
abstract class BiometricRepo {
  Future<bool> authenticateBiometric();

  Future<void> disableBiometric();

  Future<bool> isBiometricEnabled();

  Future<bool> isBiometricSupported();

  Future<bool> isBiometricWeek();
}
