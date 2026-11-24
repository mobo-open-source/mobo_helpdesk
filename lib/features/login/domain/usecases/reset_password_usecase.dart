import '../repositories/login_repo.dart';

/// Use case responsible for handling password reset requests.
///
/// This class interacts with the [LoginRepo] to trigger
/// a password reset process for a user.
class ResetPasswordUseCase {
  final LoginRepo repository;

  ResetPasswordUseCase(this.repository);

  /// Sends a password reset request.
  ///
  /// Requires:
  /// - [serverUrl]: The server endpoint
  /// - [database]: The database name
  /// - [email]: The user's registered email address
  ///
  /// Returns a response map containing:
  /// - `success`: boolean status
  /// - `message`: additional information or error message
  Future<Map<String, dynamic>> call({
    required String serverUrl,
    required String database,
    required String email,
  }) async {
    return await repository.requestPasswordReset(
      serverUrl: serverUrl,
      database: database,
      email: email,
    );
  }
}
