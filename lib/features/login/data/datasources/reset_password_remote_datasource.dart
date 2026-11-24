import '../services/reset_password_service.dart';

/// Abstract remote data source for handling password reset operations with an Odoo server.
///
/// This datasource delegates the actual network call to [ResetPasswordService].
abstract class ResetPasswordRemoteDataSource {
  /// Sends a password reset email to the specified user.
  ///
  /// Parameters:
  ///   - [serverUrl]: Base URL of the Odoo server (e.g., "https://example.com").
  ///   - [database]: Name of the Odoo database.
  ///   - [email]: The email address (login) of the user requesting the password reset.
  ///
  /// Returns:
  ///   A [Map] containing the response from the server (usually includes success status
  ///   or error details).
  ///
  /// This method is typically called from the "Forgot Password" flow in the login screen.
  Future<Map<String, dynamic>> sendResetPasswordEmail({
    required String serverUrl,
    required String database,
    required String email,
  });
}

/// Concrete implementation of [ResetPasswordRemoteDataSource].
///
/// This implementation simply delegates the call to [ResetPasswordService],
/// keeping the data source layer thin and focused on abstraction.
class ResetPasswordRemoteDataSourceImpl
    implements ResetPasswordRemoteDataSource {
  /// Delegates the password reset email request to [ResetPasswordService].
  ///
  /// See [ResetPasswordRemoteDataSource.sendResetPasswordEmail] for full documentation.
  @override
  Future<Map<String, dynamic>> sendResetPasswordEmail({
    required String serverUrl,
    required String database,
    required String email,
  }) async {
    return await ResetPasswordService.sendResetPasswordEmail(
      serverUrl: serverUrl,
      database: database,
      login: email,
    );
  }
}
