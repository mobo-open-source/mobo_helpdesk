import '../repositories/biometric_repo.dart';

/// Use case layer for biometric authentication features.
///
/// Acts as an intermediary between presentation layer and [BiometricRepo],
/// exposing biometric-related operations in a simple and consistent way.
///
/// Responsibilities:
/// - Enable biometric authentication
/// - Disable biometric authentication
/// - Check biometric status
/// - Verify device support
class BiometricUseCase {
  final BiometricRepo repo;

  BiometricUseCase(this.repo);

  Future<bool> enable() => repo.authenticateBiometric();

  Future<void> disable() => repo.disableBiometric();

  Future<bool> status() => repo.isBiometricEnabled();

  Future<bool> isSupported() => repo.isBiometricSupported();

  Future<bool> isWeekAuth() => repo.isBiometricWeek();
}
