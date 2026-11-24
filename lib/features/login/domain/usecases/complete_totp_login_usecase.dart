import '../repositories/login_repo.dart';

/// Use case that finishes a Two-Factor Authentication (TOTP) login.
///
/// The TOTP screen submits the code and obtains a session the server reports
/// as authenticated; this delegates the rest - the account, module and access
/// checks, and saving the session - to the [LoginRepo].
class CompleteTotpLoginUseCase {
  final LoginRepo repository;

  CompleteTotpLoginUseCase(this.repository);

  /// Completes the login for [sessionId].
  ///
  /// Requires:
  /// - [sessionId]: The verified session issued once the code was accepted
  /// - [serverUrl]: Server endpoint
  /// - [database]: Database name
  /// - [username]: User login name
  /// - [password]: User password
  ///
  /// Returns a response map containing:
  /// - `success`: boolean indicating whether the session was kept
  /// - `message`: error message if it was not
  Future<Map<String, dynamic>> call({
    required String sessionId,
    required String serverUrl,
    required String database,
    required String username,
    required String password,
  }) {
    return repository.completeTotpLogin(
      sessionId: sessionId,
      serverUrl: serverUrl,
      database: database,
      username: username,
      password: password,
    );
  }
}
